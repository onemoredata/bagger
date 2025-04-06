#define _POSIX_C_SOURCE 202405L
#include <errno.h>
#include <stddef.h>
#include <jsonptr.h>
#include "bagger.h"
#include "jsonpointer.h"

/*
 * Given a buffer with a JSON Pointer string, returns the parsed Jsonpointer linked list.
 * All items are palloced to the current memory context. 
 * This is due to the fact that the functions may be used at some point other than
 * initializing cached structures.
 *
 * This function may modify the buffer pointed to by ptr.
 */

Jsonpointer *
jsonpointer_parse(size_t size, char *ptr)
{
	Jsonptr jsonptr;
	Jsonptr_ref ref;
	Jsonpointer jphead, *jp;

	jsonptr = jsonptr_init(size-1, ptr);
	switch(jsonptr_err(jsonptr))
	{
	case 0:
		break;
	case EFAULT:
		ereport(ERROR,
			errcode(ERRCODE_INVALID_PARAMETER_VALUE),
			errmsg("Invalid buffer passed"));
	case EINVAL:
		ereport(ERROR,
			errcode(ERRCODE_DATA_EXCEPTION),
			errmsg("Rootless JSON pointers are not allowed"),
			errdetail("The first character is '%c' not '/'", ptr[0]));
	}

	jp = &jphead; /* the first element is a dummy to simplify allocation */

	/* we are not modifying the jsonptr so we do not need to check for errors */
	while(!jsonptr_end(ref=jsonptr_next(&jsonptr)))
	{
		ssize_t len;
		char *str;

		/* palloc throws, no need to check for allocation failure here */
		if((len=jsonptr_tostr(&str, palloc, ref, NULL)) < 1)
			ereport(ERROR,
				errcode(ERRCODE_INVALID_ESCAPE_SEQUENCE),
				errmsg("Embedded nulls are not allowed"),
				errdetail("Null byte found at position %zd", -len));

		jp->next = palloc0(sizeof *jp);
		jp = jp->next;
		jp->ref = str;
	}

	return jphead.next;
}

/*
 * Checks to see if the current Jsonpointer ref field is numeric (i.e. can be
 * used as an array index)
 *
 * Returns 1 if true, 0 if false
 *
 * These are intended to be short strings so the full length is checked.
 *
 */

int
Jsonpointer_isdigit(Jsonpointer *ptr)
{
    for (; ptr->ref; ptr->ref++)
    {
        if (!isdigit(ptr->ref))
            return 0;
    }
    return 1;
}

