/* -------------------------------------------------------------------------
 *
 * ingestion_trigger.c
 *
 * -------------------------------------------------------------------------
 */

#include "postgres.h"

#include "fmgr.h"
#include "varatt.h"
#include "utils/builtins.h"
#include "utils/jsonb.h"

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(ingestion_trigger);

PG_FUNCTION_INFO_V1(jsonpointer_get_timestamptz);

/*
 * ingestion_trigger()
 *
 */
Datum
ingestion_trigger(PG_FUNCTION_ARGS)
{
	PG_RETURN_NULL();
}
