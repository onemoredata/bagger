/* This is boilerplate from the example in the Postgres docs */
#include "postgres.h"
#include "fmgr.h"
#include "executor/spi.h"       /* this is what you need to work with SPI */
#include "commands/trigger.h"   /* ... triggers ... */
#include "utils/rel.h"          /* ... and relations */

/* End boilerplate */
#include "jsonpointer.h"
#include "names.h"
#include "bagger.h"


PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(ingestion_trigger);

Datum
ingestion_trigger(PG_FUNCTION_ARGS)
{
    TriggerData *trigdata;
    TupleDesc    tupdesc;
    HeapTuple    tuple;
    bool         isnull;
    Datum        jsonvalue;
    int          ret;


    char *partition_tablename;
    SPIPlanPtr insert_plan;
    trigdata = (TriggerData *) fcinfo->context;

    tuple = trigdata->tg_trigtuple;

    tupdesc = trigdata->tg_relation->rd_att;

    if ((ret = SPI_connect()) < 0)
        elog(ERROR, "SPI_connect returned %d", ret);

    if (tupdesc->natts != 1)
        elog(ERROR, "Currently only one column is supported");

    jsonvalue = SPI_getbinval(tuple, tupdesc, 1, &isnull);


    if (!CALLED_AS_TRIGGER(fcinfo))
        elog(ERROR, "Ingestion_trigger can only be called as a trigger");

    if (TrigInitialized == 0)
    {
        initialize_ctx();
        initialize_dimensions();
    }

    partition_tablename = partition_name(jsonvalue);
    insert_plan = get_cached_plan(partition_tablename); 

    ret = SPI_execute_plan(insert_plan, &jsonvalue, NULL, false, 1);
    return PointerGetDatum(NULL);
}

