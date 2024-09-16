#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "jsonpointer.h"

int counter = 0;
char *ok_fmt = "ok %i # %s\n";
char *bad_fmt = "not ok %i # expected %s got %s\n";

void is(char *test, char *exp) {
    ++counter;
    if (strcmp(test, exp))
        printf(bad_fmt, counter, exp, test);
    else
        printf(ok_fmt, counter, test);
}

int main() {
    // not worrying about memory here.  Yes there is a leak.  It's just a
    // little for a test.
    char *buff = (char *) malloc(20);
    char *test1 = "Testing";
    char *res1 = "Testing";
    int testcount = 6;
    is(jsonptr_unescape("Testing", buff), "Testing");
    is(jsonptr_unescape("test~1~1", buff), "test//");
    is(jsonptr_unescape("test~0~0", buff), "test~~");
    is(jsonptr_unescape("test~01", buff), "test~1");
    is(jsonptr_unescape("test~0~1", buff), "test~/");
    is(jsonptr_unescape("test~0test", buff), "test~test");
    printf("1..%i\n", testcount);
}
