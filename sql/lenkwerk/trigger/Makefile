EXTENSION = bagger_trigger
PG_CONFIG ?= pg_config
DATA = $(wildcard sql/*--*.sql)
PGXS := $(shell $(PG_CONFIG) --pgxs)
MODULE_big = bagger_data
OBJS = $(patsubst %.c,%.o,$(wildcard src/*.c))
TESTS        = $(wildcard test/sql/*.sql)
REGRESS      = $(patsubst test/sql/%.sql,%,$(TESTS))
REGRESS_OPTS = --inputdir=test --load-language=plpgsql
PG_CPPFLAGS = "-std=c99"
include $(PGXS)

