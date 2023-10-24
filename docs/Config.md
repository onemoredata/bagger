#Bagger Configuration

This document lists a full list of Bagger configuration options and their
relevant values.  Each major component describes the configuration schema and
each option is documented.

##Storage

This sets up the configuration for storing data on Bagger storage nodes.  It
is stored in the storage schema on lenkwerk and storage databases.

Here the value is any JSON value (object, array, string, or number) which
allows great flexibility bur adds some complexity for management.

Storage configuration settings are:

 - production
    - If this is missing or 0, then index and partitions can be valid into the
      past.  Schaufel will NOT start in this configuration.
    
    - If this is present and 1, then schaufel will start, but partition
      dimensions can no longer be backdated.  If this is true, then by default
      imdexes also cannot be backdated, but see `all_backedated_indexes below`.
 
 - allow_backedated_indexes
    - If absent or 0, then index creation cannot be backdated in production
    - If present or 1, thn index creation can always be backdated (and
      backfilled)
    - See `production` above.

 - dimensions_hrs_in_future
    - Defaults to 1
    - If present, must be a positive integer
    - How many hours ahead, on production, we future-date partition dimension
      changes

 - indexes_hrs_in_future
    - Defaults to 1
    - If present must be a positive integer
    - How many hours ahead, on production, we future create index specifications

 - data_storage_mode
    - The storage mode of the data column for the main data tables.
      When the table is created, this will be used to ALTER TABLE and set the
      storage mode for the column
