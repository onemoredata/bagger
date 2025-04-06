#ifndef JSONPOINTER_H 
#define JSONPOINTER_H

typedef struct Jsonpointer Jsonpointer;
typedef struct Jsonpointer {
    char *ref;
    Jsonpointer *next;
} Jsonpointer;

Jsonpointer *jsonpointer_parse(size_t, char *);
int Jsonpointer_isdigit(Jsonpointer* ptr);

typedef struct Partition_dimension Partition_dimension;
typedef struct Partition_dimension {
    Jsonpointer *entry;
    int ord;
    Partition_dimension *next;
} Partition_dimension;

#endif
