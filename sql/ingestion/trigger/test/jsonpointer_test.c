#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "jsonpointer.h"

void 
expected(const char *fmt, char *got, char *expected) {
    printf(fmt, got, expected);
}

int main() {
    // not worrying about memory here.  Yes there is a leak.  It's just a
    // little for a test.
    char *buff;
    char *ok_fmt = "ok %i # %s\n";
    char *bad_fmt = "not ok %i # expected %s got %s\n";
    char *test1 = "Testing";
    char *res1 = "Testing";
    buff = (char *) malloc(20);
    printf("1..6\n");
    if (strcmp(jsonptr_unescape(test1, buff), res1)) {
         printf(bad_fmt, 1, res1, jsonptr_unescape(test1, buff));
    } else {
         printf(ok_fmt, 1, "Testing");
    }
    char *test2 = "test~1~1";
    char *res2 = "test//";
    if (strcmp(jsonptr_unescape(test2, buff), res2)) {
         printf(bad_fmt, 2, res2, jsonptr_unescape(test2, buff));
    } else {
         printf(ok_fmt, 2, "test//");
    }
    char *test3 = "test~0~0";
    char *res3 = "test~~";
    if (strcmp(jsonptr_unescape(test3, buff), res3)) {
         printf(bad_fmt, 3, res3, jsonptr_unescape(test3, buff));
    } else {
         printf(ok_fmt, 3, "test~~");
    }
    char *test4 = "test~01";
    char *res4 = "test~1";
    if (strcmp(jsonptr_unescape(test4, buff), res4)) {
         printf(bad_fmt, 4, res4, jsonptr_unescape(test4, buff));
    } else {
         printf(ok_fmt, 4, "test~1");
    }
    char *test5 = "test~0~1";
    char *res5 = "test~/";
    if (strcmp(jsonptr_unescape(test5, buff), res5)) {
         printf(bad_fmt, 5, res5, jsonptr_unescape(test5, buff));
    } else {
         printf(ok_fmt, 5, "test~/");
    }
    char *test6 = "test~0test";
    char *res6 = "test~test";
    if (strcmp(jsonptr_unescape(test6, buff), res6)) {
         printf(bad_fmt, 6, res6, jsonptr_unescape(test6, buff));
    } else {
         printf(ok_fmt, 6, "test~test");
    }
}
