EXTENSION = bagger_lw_storage
EXTVERSION = 0.0.1
DATA = $(wildcard sql/*--*.sql)
DATA_built = sql/$(EXTENSION)--$(EXTVERSION).sql
PG_CONFIG := pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

sql/$(EXTENSION)--$(EXTVERSION).sql: sql/$(EXTENSION).sql
	cp $< $@
$(EXTENSION).control: $(EXTENSION).control.in
	sed 's/EXTVERSION/$(EXTVERSION)/;s/EXTENSION/$(EXTENSION)/;s/EXTCOMMENT/$(EXTCOMMENT)/' $< > $@
