#include <utils/memutils.h>
#include <utils/elog.h>
#include <server/nodes/memnode.h>
#include "bagger.h"

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
    if (NULL != node.prev) { \
        curr_node.prev.next = curr_node.next;\
    } \
    if (NULL != node.next) { \
        curr_node.next.prev = curr_node.prev.next; \
    }
#define PrependNode(node) \
    node.next = plancache->dlist_node; \
    node.next.prev = node;

#define MAXTABLELEN NAMEDATALEN * 2 + 1 

/* Type oid for jsonb */
#define #JSON_TYPE 3802

/* a little over here but keeping things generally aligned */
#define INSERT_SIZE 32 + MAXTABLELEN

MemoryContext TrigCacheCtx;
MemoryContext TrigStateCtx;
int TrigInitialized = 0;
const char *insertfmt = "INSERT INTO %s VALUES ($1)";

/* private type for this file */
typedef plancache_t dlist_head;
    
plancache_t plancache;
typedef struct lru_cache_plan {
    char table[MAXTABLELEN],
    SPIPlanPtr *plan,
    reloid Oid,
    lru_cache_plan next,
    lru_cache_plan prev,
    time_t last_exec
}lru_cache_plan;

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
    TrigStateCtx = AllocSetContextCreate(TopLevelContext, "TrigStateCtx",
                          1024 * 1024, 1024 * 1024, 1024 * 1024);
    TrigCacheCtx = AllocSetContextCreate(TopLevelContext, "TrigCacheCtx",
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
    plancache->node = NULL;
    MemoryContextReset(TrigCacheCtx);
}

/*
 * SPIPlanPtr *get_cached_plan(char *tablename)
 *
 * Takes a tablename and returns a plan for inserting the row into it.  The
 * idea is to abstract the whole cache handling from the rest of the trigger.
 *
 * Returns NULL if the table does not exist.
 */

SPIPlanPtr *
get_cached_plan(char *tablename) {
    lru_cache_plan cur_node = plancache->dlist_node;
    /* I can see the argument to move this into a macro, but only used once
     */
    for (lru_cache_plan cur_node = plancache->dlist_node;
            NULL != cur_node; 
            currnode = currnode.next
    ){
        if (0 == strncmp(tablename, cur_node.table, MAXTABLELEN)){
            SPIPlanPtr plan = cur_node.plan;
            curr_node.last_exec = time(0);
            DisconnectNode(curr_node);

            // This does do subtransactions but does not use XIDs
            // This avoids writing to tables which have been dropped.
            //
            BeginInternalSubTransaction(NULL);
            PG_TRY();
            {
                open_table(currnode.reloid, AccessShareLock);
                ReleaseCurrentSubTransaction();
            }
            PG_CATCH();
            { 
                //roll back subtransaction and return null
                DisconnectNode(curr_node);
                pfree(curr_node);
                RollbackAndReleaseCurrentSubTransaction();
                FlushErrorState();
                return NULL;
            }
            PG_END_TRY();
            PrependNode(currnode);

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
SPIPlanPtr *
create_cached_plan(char *tablename, TriggerData *tgdata) {
    int ret;
    SPITupleTable *qresult;
    lru_cache_plan entry = MemoryContextAllocZero(TrigCacheCtx, sizeof(lru_cache_entry));
    TupleDesc trigtup = tgdata->tg_relation->rd_att; 
    entry.plan = NULL;

    memncpy(entry.table_name, tablename, MAXTABLELEN);

    /* we are only doing this when we create a cached plan so probably ok. */

    ret = SPI_exec("SELECT $1::regclass::oid", tablename);
    if (ret > 0 && SPI_tupletable != NULL) {
        SPITupleTable *tuptable = SPI_tuptable;
        entry.reloid = SPI_getvalue(tuptable->[0], tuptable->tupdesc, 0);
    } else {
        return NULL;
    }

    stmt_buff = MemoryContextAllocZero(INSERT_SIZE);
    stmt_buff = snprintf(stmt_buff, sizeof(stmt_buff), insertfmt, tablename);
    entry.plan = SPI_prepare(stmt_buff, 1, JSON_TYPE);
    PrependNode(entry);
    SPI_keepplan(entry.plan);
    return entry.plan;
}
