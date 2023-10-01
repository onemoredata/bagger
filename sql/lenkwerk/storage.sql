
create schema if not exists storage;


create table storage.postgres_instance (
   id serial not null unique,
   host varchar,
   port int,
   username varchar not null,
   status smallint not null default 0,
   primary key (host, port),
   check (status >= 0 and status <= 3) -- if you change this, change docs below
);

COMMENT ON TABLE storage.postgres_instance IS
$$The postgres_instance table provides enough information for Bagger components 
to connect to the relevant database instances.  Note that authentication is NOT
in scope and must be set separately.  We recommend certificate authentication
or gssapi.  As a fallback, the .pgpass can be used though rotating passwords is
not easy.

DO NOT STORE PASSWORDS IN PLAIN TEXT IN THE DATABASE$$; 

COMMENT ON COLUMN storage.postgres_instance.status IS 
$$ The status here is a bit string for various statuses.  
Currently the bits are: 
0 - Can read 
1 - Can write

This leads to the following values:
0 - Offline
1 - read-only
2 - write-only
3 - Online (can read and write)

New states may be added in the future.
$$;

create table servermaps (
   generation serial primary key,
   server_map json not null
);

comment on table servermaps is
$$ The servermaps table stores the server maps by generation so that
we can determine which servers are supposed to receive writes together.$$;

create table partitions (
     id bigserial not null unique,
     primary_instance_id int references(postgres_instance.id),
     generation int not null,
     copies int[] not null,
     schema text,
     name text,
     timerange tsrange not null,
     primary key(primary_instance_id, schema, name);
);

comment on table partitions is
$$ This table tracks (for the current version) the tables that have been
created on the various backends and the timeframes they are valid for.
$$;

comment on column partitions.primary_instance_id is
$$ This is the instance where the bagger responsible created the partition.
Copies are all co-equal but this is expected to be local on the system. and
therefore the preferred copy for reading.
$$;

comment on column partitions.copies is
$$ This contains an array of instance ids where the same table is stored.
It will be an array of the length defined by the replication factor.  In the
first version, that is limited to 2.$$;

create table indexes (
      
     
);

create table config (
);
