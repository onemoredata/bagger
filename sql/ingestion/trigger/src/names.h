#ifndef NAMES_H
#define NAMES_H

#include <utils/jsonb.h>

typedef struct Namenode Namenode;
typedef struct Namenode {
    char* label;
    int ord;
} Namenode;

typedef struct Name_slist_entry Name_slist_entry;
typedef struct Name_slist_entry {
    Namenode *node;
    Name_slist_entry *next;
} Name_slist_entry;

void initialize_dimensions( void );

char** extract_names(Datum json_doc);

char* append_names(char **strings_from_json);

char* partition_name(Datum jsonvalue);


#endif
