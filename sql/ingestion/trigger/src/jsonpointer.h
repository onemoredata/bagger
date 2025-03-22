#ifndef JSONPOINTER_H 
#define JSONPOINTER_H

typedef struct Jsonpointer Jsonpointer;
typedef struct Jsonpointer {
    char *ref;
    Jsonpointer *next;
} Jsonpointer;

extern Jsonpointer *jsonpointer_parse(size_t, char *);

typedef struct jptr_listentry jptr_listentry;
typedef struct jptr_listentry {
    Jsonpointer *entry;
    int ord;
    jptr_listentry *next;
} jptr_listentry;

#endif
