#include "bagger.h"
#include "jsonpointer.h"
#include <utils/jsonb.h>
#include <string.h>

/* Bagger name munger module
 *
 * Copyright (C) 2024 One More Data
 *
 * This module generates table names looking at json paths stored in our
 * config.
 *
 * The name structure is bp_[partition fields]_YYYY_MM_DD_HH
 */


/* The overall approach we take is to retrieve and store the jsonpointers
 * in alphabetical order (which in c locale corresponds to the same collation
 * order as our search order.
 *
 * We then store this with the ordinal, and sort the labels by ordinal before
 * generating the table name.  We can generally assume that there are fewer
 * dimensions than JSON keys so this should be a performance win.
 */

typedef struct namenode namenode;
typedef struct namenode {
    char* label;
    int ord;
} namenode;

typedef struct name_slist_entry name_slist_entry;
typedef struct name_slist_entry {
    namenode* node;
    name_slist_entry* next;
} name_slist_entry;

char** extract_names(Datum json_doc);

char* append_names(char** strings_from_json);
name_slist_entry* find_next_in_doc(Jsonb* jsondoc, JsonbIterator* iter, Jsonpointer* jptr);

char* partition_name(name_slist_entry* head);



jptr_listentry* dimension_ptr_head = NULL;

void initialize_dimensions( void );

name_slist_entry* dimensions_from_doc(Jsonb *jsondoc);

static inline void sort_name_slist(name_slist_entry* head);

// char* name_from_json(Datum json_doc);

jptr_listentry *paths;
/* initialize loads the paths we will need to follow and parses them.
 * Each path becomes an array of strings and this allows us to loop through
 * them.
 */
void
initialize_dimensions()
{
   jptr_listentry *curr;
   int ret;
   int r;
   SPITupleTable *tuptable = SPI_tuptable;
   TupleDesc tupdesc;

   /* This perhaps could be a warning but better safe than sorry */
   if (NULL != dimension_ptr_head)
       elog(ERROR, "Dimension list already initialized");
   if ((ret = SPI_connect()) < 0)
        elog(ERROR, "SPI_connect returned %d", ret);
   
   paths = NULL;

   /* still need to bring the date/time in for partitioning */
   if (SPI_OK_SELECT != (ret = SPI_execute("SELECT fieldname, row_number() "
                                          "     over(order by ordinality asc) "
                                          "     as ordinality "
                                          "FROM storage.dimension "
                                          "ORDER BY fieldname ASC", true, 0)))
       elog(ERROR, "SPI_execute returned %d", ret);
   if (NULL == SPI_tuptable)
       elog(ERROR, "Dimensions query returned no results!");

   dimension_ptr_head = (jptr_listentry*) palloc0(sizeof(jptr_listentry));
   curr = dimension_ptr_head;
   tupdesc = tuptable->tupdesc;
   if (tuptable->numvals == 0)
       elog(ERROR, "0 Dimensions Returned");

   for (r = 0; r < tuptable->numvals; r++)
   {
       /* yes we are leaving some spare allocations around but this is not
        * intended to be very many or have much of an effect.
        *
        * Prioritizing readability over memory efficiency especially for a
        * small amount of memory.
        */
       HeapTuple tuple = tuptable->vals[r];
       char *jptr = SPI_getvalue(tuple, tupdesc, 1);
       int ord = atoi(SPI_getvalue(tuple,tupdesc,2));
       curr->entry = jsonpointer_parse(strlen(jptr), jptr);
       curr->ord = ord;

       if (r + 1 < tuptable->numvals)
       {
           curr->next = (jptr_listentry*) palloc0(sizeof(jptr_listentry));
           curr = curr->next;
       }
       else
       {
           /* just making this explicit */
           curr->next = NULL;
       }


   }
}

/* Takes a jsonb document and returns the dimensions from the jsonb document
 * based on the jsonpointers for the dimensions.
 *
 * Returns the head entry in the single linked list of name entries
 */
name_slist_entry*
dimensions_from_doc(Jsonb *jsondoc)
{
    name_slist_entry* head;
    name_slist_entry* curr;
    name_slist_entry* next;

    jptr_listentry* jsonptr;

    head = (name_slist_entry*) palloc0(sizeof(name_slist_entry));
    curr = head;
    for (jsonptr = dimension_ptr_head; NULL != jsonptr; jsonptr = jsonptr->next)
    {
        next = find_next_in_doc(jsondoc, JsonbIteratorInit (&jsondoc->root), jsonptr->entry);
        curr->next = next;
        next->node->ord = jsonptr->ord;
        jsonptr = jsonptr->next;
        if (NULL != jsonptr->next)
        {
            curr->next = (name_slist_entry*) palloc0(sizeof(name_slist_entry));
            curr = curr->next;
        }
    }
    return head;
}

/* Most of the work is done here.
 *
 * Takes in a jsonb document, an iterator, and the jsonptr to find.
 * Calls recursively on deeper sub-documents when we need to search pieces
 * within the document.
 *
 * This function modifies the JsonbIterator and so repeated calls must be in
 * JSONB key order (alphabetical, C locale collation).
 *
 */

char *empty_str = "";

name_slist_entry*
find_next_in_doc(Jsonb* jsondoc, JsonbIterator* iter, Jsonpointer* jptr)
{
    JsonbValue val;
    JsonbIteratorToken typ;

    if (NULL == jsondoc)
    {
        name_slist_entry* ret = palloc0(sizeof(name_slist_entry));
        elog(WARNING, "JSONPointer did not reach deep enough.");
        ret->node->label = empty_str;
    }

    while ((typ = JsonbIteratorNext(&iter, &val, false)))
    {
        if (typ == WJB_BEGIN_ARRAY)
        {
            int itcount;
            int index;
            /* ok we have an array.  We had better make sure our next search
             * is numeric
             */
            if (0 == JsonpointerIsDigit(jptr))
                elog(ERROR, "Trying to get non-int index of a JSON array");

            index = atoi(jptr->ref);
            for (itcount = 0; itcount <= index; ++itcount)
            {
                typ = JsonbIteratorNext(&iter, &val, false);
            }
            if (typ == WJB_VALUE)
            {
                if ((val.type == jbvArray) || (val.type == jbvObject))
                {
                    Jsonb* doc = JsonbValueToJsonb(&val);
                    return find_next_in_doc(doc, JsonbIteratorInit(&doc->root), jptr->next);
                }
                if (val.type == jbvString)
                {
                    name_slist_entry* ret = palloc0(sizeof(name_slist_entry));
                    ret->node->label = val.val.string.val;
                }

            }
            else
            {
                name_slist_entry* ret = palloc0(sizeof(name_slist_entry));
                ret->node->label = empty_str;
                elog(WARNING, "Could not find index in document");
                return ret;
            }
        }
        else
        {
            /* Here we assume it is an object.  We may want to eventually
             * test for it explicitly though.
             */
            while ((typ = JsonbIteratorNext(&iter, &val, false)))
            {
               if (typ == WJB_KEY)
               {
                  if (val.type == jbvString)
                      if (strcmp(val.val.string.val, jptr->ref) == 0)
                      {
                          typ = JsonbIteratorNext(&iter, &val, false);
                          if (typ != WJB_VALUE)
                              elog(WARNING, "Malformed JSON object, no value");
                          if (val.type == jbvString)
                          {
                              name_slist_entry* ret = palloc0(sizeof(name_slist_entry));
                              ret->node->label = val.val.string.val;
                          }
                          else if ((val.type == jbvArray) || (val.type == jbvObject))
                          {
                              Jsonb* doc = JsonbValueToJsonb(&val);
                              return find_next_in_doc(doc, JsonbIteratorInit(&doc->root), jptr->next);
                          }
                      }
               }
            }
        }
    }
    return NULL;
}

static inline void
append_to_name(char *name, const char *value)
{
    /* 1 for the null terminator and one for the separator, so 2 */
    if (strlen(name) + strlen(value) == NAMEDATALEN - 2)
        elog(ERROR, "NAMEDATALEN exceeded for partition name");

    strcpy(name, "_");
    strcpy(name, value);
}

static inline void 
sort_name_slist(name_slist_entry* head)
{
    int ord = 1;
    int found;
    name_slist_entry* curr;
    name_slist_entry* search;
    namenode* temp;
    

    /* we will just do a bubble sort and swap name nodes */
    for (curr = head; curr != NULL; curr = curr->next)
    {
        if (curr->node->ord == ord)
        {
            continue;
        } 
        else
        {
            for (found = 0, search = curr; search != NULL || found; search = search->next)
            {
                if (search->node->ord == ord)
                {
                    temp = search->node;
                    search->node = curr->node;
                    curr->node = temp;

                    found = 1;
                }
            }
        }
    }
}

char *
partition_name(name_slist_entry* head)
{
    char* name = (char*) palloc0(NAMEDATALEN + 1);
    name_slist_entry* curr = head;

    strcpy(name, "data");
    sort_name_slist(head);


    while (NULL != curr)
    {
        append_to_name(name, curr->node->label);
        curr = curr->next;
    }
    return name;
    
}
