#include <string.h>
#include "jsonpointer.h"
#include "bagger.h"

/*
 * jsonptr_parse.c -- JSON Pointer Parsing for Bagger
 *
 * This file provides the base implementation of the JSON Pointer parser for
 * the trigger's initialization phase.  Unlike the escaping logic, this uses
 * PostgreSQL's memory management architecture.
 */

/* jsonptr *jsonptr_parse(char *jsonpointer_in)
 *
 * returns the parsed jsonptr structure.  All items are palloced to the current
 * memory context.  This is due to the fact that the functions may be
 * used at some point other than initializing cached structures.
 *
 * This function is not guaranteed not to modify its argument.  Copy the string
 * first if this matters to you.
 */
jsonptr *
jsonptr_parse(char *jsonpointer_in)
{
    char **save;
    jsonptr *out;
    char *tok;
    char delim[2] = "/";
    jptr_listentry *last_entry;

    save = NULL;
    tok = strtok_r(jsonpointer_in, (char *) &delim, save);
    if (tok)
    {
        // this happens when the delimiter is not the first character
        ereport(ERROR,
                errcode(ERRCODE_DATA_EXCEPTION), 
                errmsg("Rootless JSON pointers are not allowed"),
                errhint("strtok returned %s on first invocation", tok)
               );
    }
    out = (jsonptr *) palloc0(sizeof(jsonptr));
    last_entry = NULL;
    while ((tok = strtok_r(NULL, (char *) &delim, save)))
    {
        char *ptr_buff;
        jptr_listentry *jptr_entry;

        jptr_entry = (jptr_listentry *) palloc0(sizeof(jptr_listentry));

        ptr_buff = (char *) palloc(strlen(tok + 1));
        jptr_entry->path_elem = jsonptr_unescape(tok, ptr_buff);
        if (last_entry)
        {
            last_entry->next = jptr_entry;
        }
        else
        {
            out->path_head = jptr_entry;
        }

        last_entry = jptr_entry;
    }
    return out;
}

