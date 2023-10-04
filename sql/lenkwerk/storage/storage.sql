
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

create table storage.servermaps (
   generation serial primary key,
   server_map json not null
);

comment on table storage.servermaps is
$$ The servermaps table stores the server maps by generation so that
we can determine which servers are supposed to receive writes together.$$;

CREATE TABLE storage.dimensions (
   id serial NOT NULL UNIQUE, 
   ordinality INT NOT NULL UNIQUE DEFERRABLE INITIALLY DEFERRED,
   default_val varchar not null,
   fieldname varchar PRIMARY KEY
);


COMMENT ON TABLE storage.domensions IS
$$ This contains the partitions by which data is partitioned. Default values 
can be set using the default_val field though this is not yet supported.$$;


create table storage.indexes (
   id serial not null unique, 
   index_name varchar(16) default 'bagger_idx',
   ordinal int,
   expression varchar not null,
   primary key (index_name, ordinal) DEFERRABLE INITIALLY DEFERRED
);

comment on table storage.indexes is
$$ This table includes index definition information for bagger nodes.

Some care needs to be paid as to the nature of the contents of this table
because while naive SQL injection is not possile at index creation time,
indexes can perform arbitrary code at insert or update time.

For this reason registering indexes is a privileged operation.
$$;



comment on column storage.indexes.expression is
$$This column has an important security consideration because improper
management of indexes could allow attackers to run arbitrary code during
index update.  The actual CREATE INDEX statement is not vulnerable to
SQL injection attacks itself, but expressions can include function calls
to any function marked immutable.  This means that a clever attacker could
create a function with destructive intent, mark it as immutable and then
call it from a function.

This problem is not actually related to storing the index expressions in
the database.  The problem can happen anywhere these expressions are stored
and therefore it is important to have careful controls on that process.

RECOMMENDATION:  update this table from an infrastructure-as-code framework
only and implement checks to ensure the two are in sync.$$;

create table storage.config (
    id serial not null unique,
    key text primary key,
    value json not null
);

comment on table storage.config is
$$ This table stores configuration for the storage nodes.
$$;

comment on column storage.config.value is
$$ JSON is selected here because it is richer than plain text and serialization
libraries are available in all major languages.$$;
