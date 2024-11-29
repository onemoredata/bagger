EXTENSION = lenkwerk_postgrest
EXTVERSION = 0.0.1
DATA = $(wildcard sql/*--*.sql)
PG_CONFIG := pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

all: sql/$(EXTENSION)--$(EXTVERSION).sql $(EXTENSION).control
sql/$(EXTENSION)--$(EXTVERSION).sql: sql/$(EXTENSION).sql
	cp $< $@
$(EXTENSION).control: $(EXTENSION).control.in
	sed 's/EXTVERSION/$(EXTVERSION)/;s/EXTENSION/$(EXTENSION)/;s/EXTCOMMENT/$(EXTCOMMENT)/' $< > $@
