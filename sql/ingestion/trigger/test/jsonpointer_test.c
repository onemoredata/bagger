#define _POSIX_C_SOURCE 202405L
#include <assert.h>
#include <setjmp.h>
#include <stdio.h>
#include <postgres.h>
#include <utils/elog.h>
#include "jsonpointer.h"

/*
The dummy palloc, palloc0, errstart_cold, and errcode
build enough of a test harness to catch exceptions raised with ereport.
We then use longjmp to throw the exception (just like postgres does).
The exceptions are caught and tested with a setjmp embedded in the CATCH macro.
*/

jmp_buf exenv;

#define BEGIN do{ fputs(__func__,stderr); fputs(": ",stderr); }while(0)
#define OK do{ fputs("ok\n", stderr); return; }while(0)
#define FAIL(e) do{ fputs("fail: error " #e " should have been thrown\n", stderr); exit(1); }while(0)
#define NOCATCH if(setjmp(exenv)){ fputs("fail: no error should have been thrown\n", stderr); exit(1); }

#define CATCH(e) switch(setjmp(exenv)){	\
	case 0:	\
		break;	\
	case e:	\
		OK;	\
	default:	\
		fputs("fail: uncaught error\n", stderr);	\
		exit(1);	\
	} \

void *
palloc(size_t size)
{
	void *p = malloc(size);
	assert(p);
	return p;
}

void *
palloc0(size_t size)
{
	void *p = calloc(1, size);
	assert(p);
	return p;
}

pg_attribute_cold bool
errstart_cold(int elevel, const char *domain)
{
	return true;
}

int
errcode(int sqlerrcode)
{
	longjmp(exenv, sqlerrcode);
}

/* The actual test cases */

static void
success(void)
{
	Jsonpointer *jp;
	char test[] = "/a/json/pointer";

	BEGIN;
	NOCATCH;

	jp = jsonpointer_parse(sizeof(test), test);

	assert(strcmp(jp->ref, "a") == 0);
	jp = jp->next;
	assert(strcmp(jp->ref, "json") == 0);
	jp = jp->next;
	assert(strcmp(jp->ref, "pointer") == 0);
	assert(jp->next == NULL);

	OK;
}

static void
invalid_buffer(void)
{
	BEGIN;
	CATCH(ERRCODE_INVALID_PARAMETER_VALUE);
	jsonpointer_parse(42, NULL);
	FAIL(ERRCODE_INVALID_PARAMETER_VALUE);
}

static void
rootless(void)
{
	char test[] = "a/json/pointer";

	BEGIN;
	CATCH(ERRCODE_DATA_EXCEPTION);
	jsonpointer_parse(sizeof(test), test);
	FAIL(ERRCODE_DATA_EXCEPTION);
}


static void
embedded_null(void)
{
	char test[] = "/a/js\0on/pointer";

	BEGIN;
	CATCH(ERRCODE_INVALID_ESCAPE_SEQUENCE);
	jsonpointer_parse(sizeof(test), test);
	FAIL(ERRCODE_INVALID_ESCAPE_SEQUENCE);
}

static void
ends_with_null(void)
{
	char test[] = "/a/json/pointer\0";

	BEGIN;
	CATCH(ERRCODE_INVALID_ESCAPE_SEQUENCE);
	jsonpointer_parse(sizeof(test), test);
	FAIL(ERRCODE_INVALID_ESCAPE_SEQUENCE);
}

static void
ptr_starts_with_null(void)
{
	char test[] = "\0/a/json/pointer";

	BEGIN;
	CATCH(ERRCODE_DATA_EXCEPTION);
	jsonpointer_parse(sizeof(test), test);
	FAIL(ERRCODE_DATA_EXCEPTION);
}

static void
key_ends_with_null(void)
{
	char test[] = "/a\0/json/pointer";

	BEGIN;
	CATCH(ERRCODE_INVALID_ESCAPE_SEQUENCE);
	jsonpointer_parse(sizeof(test), test);
	FAIL(ERRCODE_INVALID_ESCAPE_SEQUENCE);
}

static void
key_starts_with_null(void)
{
	char test[] = "/\0a/json/pointer";

	BEGIN;
	CATCH(ERRCODE_INVALID_ESCAPE_SEQUENCE);
	jsonpointer_parse(sizeof(test), test);
	FAIL(ERRCODE_INVALID_ESCAPE_SEQUENCE);
}

int
main()
{
	success();
	invalid_buffer();
	rootless();
	embedded_null();
	ends_with_null();
	ptr_starts_with_null();
	key_ends_with_null();
	key_starts_with_null();
}
