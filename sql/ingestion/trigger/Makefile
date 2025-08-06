EXTENSION = bagger_trigger
EXTVERSION = 0.0.1
PG_CONFIG ?= pg_config
DATA = $(wildcard sql/*--*.sql)
PGXS := $(shell $(PG_CONFIG) --pgxs)
MODULE_big = bagger_ingestion
OBJS = $(patsubst %.c,%.o,$(wildcard src/*.c))
TESTS        = $(wildcard test/sql/*.sql)
REGRESS      = $(patsubst test/sql/%.sql,%,$(TESTS))
REGRESS_OPTS = --inputdir=test --load-language=plpgsql
PG_CPPFLAGS = -std=c17
include $(PGXS)
CFLAGS = $(CFLAGS) -I src

$(EXTENSION).control: $(EXTENSION).control.in
	sed 's/EXTVERSION/$(EXTVERSION)/;s/EXTENSION/$(EXTENSION)/;s/EXTCOMMENT/$(EXTCOMMENT)/' $< > $@
PG_INC := $(shell $(PG_CONFIG) --includedir-server)
LIBJSONPTR := $(shell pkg-config libjsonptr --cflags --libs)
jsonpointer_test:
	$(CC) $(CFLAGS) $(PG_CPPFLAGS) src/jsonpointer.c test/jsonpointer_test.c $(LIBJSONPTR) -I$(PG_INC) -Isrc -o test/jsonpointer_test
	test/jsonpointer_test
