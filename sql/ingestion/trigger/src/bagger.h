#ifndef BAGGER_H
#define BAGGER_H
/* c.h is PostgreSQL's optional C features abstraction header. */
//#include <c.h>
#include <postgres.h>
#include <fmgr.h>
#include <executor/spi.h>
#include <commands/trigger.h>
#include <utils/rel.h>
#include <utils/builtins.h>

/* Shared prototypes */
extern void initialize_ctx(void);
extern void clear_plan_cache(void);
extern SPIPlanPtr get_cached_plan(char *tablename);
extern FunctionCallInfo fcinfo;
#endif
