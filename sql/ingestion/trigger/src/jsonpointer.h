#ifndef JSONPOINTER_H 
#define JSONPOINTER_H
typedef struct jptr_listentry jptr_listentry;
typedef struct jptr_listentry {
    char *path_elem;
    jptr_listentry *next;
} jptr_listentry;
typedef struct jsonptr jsonptr;
typedef struct jsonptr {
    jptr_listentry *path_head;
    jsonptr *next;
} jsonptr;

extern char* jsonptr_unescape(char *, char *);
extern jsonptr* jsonptr_parse(const char *);
#endif
