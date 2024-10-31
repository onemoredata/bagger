#ifndef JSONPOINTER_H 
#define JSONPOINTER_H

typedef struct Jsonpointer Jsonpointer;
typedef struct Jsonpointer {
    char *ref;
    Jsonpointer *next;
} Jsonpointer;

Jsonpointer *jsonpointer_parse(size_t, char *);

#endif
