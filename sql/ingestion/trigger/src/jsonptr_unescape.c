#include <string.h>
#include <stdio.h>
#include "jsonpointer.h"

/* This file contains a minimal implementation of jsonpointers for Bagger's
 * usage.  The implementation here is specifically for parsing pre-stored
 * JSON Pointers.  Longer-term it may be good to create an actual data type
 * for these, but for now, we will just focus on reading them.
 */

/*
 * char * jsonptr_unescape(const char *)
 * returns a pointer to a palloc'd string but is unescaped for Json Pointer
 * use.  I.e. by turning ~1 into / and then ~0 into ~
 *
 * For more efficiency, we just return the escaped string pointer if it did not
 * need to be escaped
 */


char *
jsonptr_unescape(char *escaped, char *buff) {
    /* probably underbroad but good enough and safe */
    if (NULL == strchr(escaped, '~')){
        strncpy(buff, escaped, strlen(escaped) + 1);
        return buff;
    }
    else {
        size_t maxlen;
        int len;
        char *pos;
        char *bpos;
        char c;
        char chr;
        *buff = '\0';
        maxlen = strlen(escaped);
        len = 0;
        pos = escaped; // generates warning

        // null byte ends check
        while ((*pos != '\0') && (len <= maxlen)) {
            bpos = buff + len;
            c = *pos;
            if (c == '~'){ /* escaping logic */
                if (*(pos +1) == '0') {
                    chr = '~';
                    ++pos;
                }
                else if (*(pos + 1) == '1') {
                    chr = '/';
                    ++pos;
                }
            }
            chr = c;
            *bpos = chr;
            ++bpos;
            *bpos = '\0';
            ++len;
            ++pos;
        }
        return buff;
    }
    return NULL;
}
