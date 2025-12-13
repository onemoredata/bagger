# bagger/ingestion/Makefile
  
MODULE_big = bagger_schute
OBJS = \
	bagger_schute.o

EXTENSION = bagger_schute
DATA = bagger_schute--1.0.sql
PGFILEDESC = "bagger_schute -- bagger partitioning configuration"

#ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
#else
#...
#endif
