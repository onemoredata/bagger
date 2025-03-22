#include "bagger.h"
#include "jsonpointer.h"
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
    char *label;
    int ord;
} namenode;

typedef struct name_slist_entry name_slist_entry;
typedef struct name_slist_entry {
    namenode *node;
    next *name_slist_entry
} name_slist_entry;

char** extract_names(Datum json_doc);

char* append_names(char** strings_from_json);

jptr_listentry* dimension_ptr_head = NULL;

void initialize( void );
// char* name_from_json(Datum json_doc);

jsonptr paths;
/* initialize loads the paths we will need to follow and parses them.
 * Each path becomes an array of strings and this allows us to loop through
 * them.
 */
void
initialize_dimensions()
{
   jptr_listentry *curr;

   paths.path_head = NULL;
   int ret;
   int r;
   /* This perhaps could be a warning but better safe than sorry */
   if (NULL != dimension_ptr_head)
       elog(ERROR, "Dimension list already initialized");
   if ((ret = SPI_connect()) < 0)
        elog(ERROR, "SPI_connect returned %d", ret);
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
   SPITupleTable *tuptable = SPI_tuptable;
   TupleDesc tupdesc = tuptable->tupdesc;
   if (tuptable->numvals == 0)
       elog(ERROR, "0 Dimensions Returned")

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
 *
name_slist_entry*
dimensions_from_doc(Datum *jsondoc) 
{
    `
}
*/

static inline void
append_to_name(char *name, const char *value)
{
    /* 1 for the null terminator and one for the separator, so 2 */ 
    if (strlen(name) + strlen(value) == NAMEDATALEN - 2)
    {
        /* throw error */
        // ereport(...)
    }
    strcpy(name, "_");
    strcpy(name, value);
}
