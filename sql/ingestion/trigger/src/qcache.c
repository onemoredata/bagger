#include "bagger.h"
#include <utils/memutils.h>
#include <utils/elog.h>
#include <nodes/memnodes.h>
#include <access/relation.h>
#include <catalog/namespace.h>
#include <utils/varlena.h>

/********************************************************************
 *  This file handles the memory context globals and the plan cache
 *
 *  The general logic to putting these together is that clearing
 *  the plan cache and resetting the memory context need to be done
 *  together and hte state memory context is not major enough to justify its 
 *  own file.
 *
 *  Error handling here is done with under the principle that where there is
 *  smoke there is fire.  If something looks wrong, we abort.
 *
 *  The state context is small and expected to hold only 1kb of data at most.
 *  The cache context may grow as needed.
 *
 *  Here we have decided to use a double linked list in order to have a fully
 *  functioning LRU cache, but the rest of the code doesn't need to be aware
 *  of the implementation.  The trigger only has to ask for a cached plan and
 *  it will get an SPIPlanPtr back which it can then operate.  The caching is
 *  thus entirely opaque to the trigger.
 *
 *  Future work exploration might be whether a secondary hashmap might be faster
 *  for plan retrieval.  However given that most tables will be repeatedly used
 *  the double linked list may be the access path that works best.
 *
 *  For the query cache, the expectation is that the most frequently used tables
 *  will stay at the head of the cache.  For very wide partitioning sets and
 *  few time partitions this might need to be changed for a hashmap.
 */

#define DisconnectNode(node) \
    if (NULL != node->prev) { \
        node->prev->next = node->next;\
    } \
    if (NULL != node->next) { \
        node->next->prev = node->prev->next; \
    }
#define PrependNode(node) \
    node->next = plancache.head; \
    node->next->prev = node;

#define MAXTABLELEN NAMEDATALEN * 2 + 1 

/* Type oid for jsonb */
#define JSON_TYPE 3802

/* a little over here but keeping things generally aligned */
#define INSERT_SIZE 32 + MAXTABLELEN

MemoryContext TrigCacheCtx;
MemoryContext TrigStateCtx;
int TrigInitialized = 0;
const char *insertfmt = "INSERT INTO %s VALUES ($1)";

/* private type for this file */
    
struct lru_cache_plan
{
    char table[MAXTABLELEN];
    SPIPlanPtr plan;
    Oid reloid;
    struct lru_cache_plan *next;
    struct lru_cache_plan *prev;
    time_t last_exec;
};
typedef struct lru_cache_plan lru_cache_plan;

typedef struct dlist_h plancache_t;
struct dlist_h
{
    lru_cache_plan *head;
};

plancache_t plancache;
/* prototypes */
void initialize_ctx(void);
void clear_cache(void);
SPIPlanPtr get_cached_plan(char *);
SPIPlanPtr create_cached_plan(char *);

/* void initialize_ctx() 
 * Initializes the memory contexts we need to use and key state for the query
 * cache.  It does notinitialize other state data as that will be done after.
 *
 * This must be the first stage of the initialization.
 */
void
initialize_ctx() {
    if (TrigInitialized) {
        ereport(FATAL,
                errcode(ERRCODE_OBJECT_NOT_IN_PREREQUISITE_STATE),
                errmsg("Failed to initialize Memory Contexts:  Already Initialized"));
    }
    TrigStateCtx = AllocSetContextCreate(TopMemoryContext, "TrigStateCtx",
                          1024 * 1024, 1024 * 1024, 1024 * 1024);
    TrigCacheCtx = AllocSetContextCreate(TopMemoryContext, "TrigCacheCtx",
                          1024 * 1024, 1024 * 1024, 1024 * 1024 * 1024);
    TrigInitialized = 1;
}

/*
 * void clear_plan_cache()
 *
 * Purges all cached plans.
 */
void
clear_plan_cache() {
    plancache.head = NULL;
    MemoryContextReset(TrigCacheCtx);
}

/*
 * SPIPlanPtr get_cached_plan(char *tablename)
 *
 * Takes a tablename and returns a plan for inserting the row into it.  The
 * idea is to abstract the whole cache handling from the rest of the trigger.
 *
 * Returns NULL if the table does not exist.
 */

SPIPlanPtr 
get_cached_plan(char *tablename) {
    /* I can see the argument to move this into a macro, but only used once
     */
    for (lru_cache_plan *cur_node = plancache.head;
            NULL != cur_node; 
            cur_node = cur_node->next
    ){
        if (0 == strncmp(tablename, cur_node->table, MAXTABLELEN)){
            SPIPlanPtr plan = cur_node->plan;
            cur_node->last_exec = time(0);
            DisconnectNode(cur_node);

            // This does do subtransactions but does not use XIDs
            // This avoids writing to tables which have been dropped.
            //
            BeginInternalSubTransaction(NULL);
            PG_TRY();
            {
                relation_open(cur_node->reloid, AccessShareLock);
                ReleaseCurrentSubTransaction();
            }
            PG_CATCH();
            { 
                //roll back subtransaction and return null
                DisconnectNode(cur_node);
                pfree(cur_node);
                RollbackAndReleaseCurrentSubTransaction();
                FlushErrorState();
                return NULL;
            }
            PG_END_TRY();
            RollbackAndReleaseCurrentSubTransaction();
            PrependNode(cur_node);

            return plan;
        }
    }
    return create_cached_plan(tablename);
}

/*
 *  SPIPlanPtr *create_cached_plan(char *tablename)
 *
 *  Takes in a tablename, creates a cached plan, and returns it.
 *
 *  Returns NULL if table does not exist.
 */

/* not sure if this should be static or inline or not.  
 * Considering testability first and keeping it separate. */
SPIPlanPtr 
create_cached_plan(char *tablename) {
    RangeVar *rv;
    Oid jsontype;
    Oid relid;
    char *stmt_buff;
    TriggerData *tgdata = (TriggerData *) fcinfo->context;

    lru_cache_plan *entry = MemoryContextAllocZero(TrigCacheCtx, sizeof(lru_cache_plan));
    entry->plan = NULL;

    memcpy(entry->table, tablename, MAXTABLELEN);

    /* we are only doing this when we create a cached plan so probably ok. */
    rv = makeRangeVarFromNameList(textToQualifiedNameList(cstring_to_text(entry->table)));
    relid = RangeVarGetRelid(rv, NoLock, false);

    if (InvalidOid == relid)
        return NULL;
    jsontype = SPI_gettypeid(tgdata->tg_relation->rd_att, 1);
    stmt_buff = MemoryContextAllocZero(TrigCacheCtx, INSERT_SIZE);
    snprintf(stmt_buff, sizeof(stmt_buff), insertfmt, tablename);
    entry->plan = SPI_prepare(stmt_buff, 1, &jsontype);
    PrependNode(entry);
    SPI_keepplan(entry->plan);
    return entry->plan;
}
