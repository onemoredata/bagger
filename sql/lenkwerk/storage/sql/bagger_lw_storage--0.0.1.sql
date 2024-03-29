
create schema if not exists storage;

create table storage.time_bound (
    valid_from timestamp not null default '-infinity',
    valid_until timestamp not null default 'infinity',
    check (valid_from is null) NO INHERIT -- ensure nothing is saved here
);

create function storage.validrange(storage.time_bound)
returns tsrange language sql
return (tsrange($1.valid_from, $1.valid_until, '[)'));

comment on table storage.time_bound IS
$$
This table is an interface table which, via inheritance, gives a consistent way
of handling database entities which need to be available during various time
ranges.
$$;

create table storage.postgres_instance (
   id serial not null unique,
   host varchar,
   port int,
   username varchar not null,
   status smallint not null default 0,
   primary key (host, port),
   check (status >= 0 and status <= 3) -- if you change this, change docs below
);

SELECT pg_catalog.pg_extension_config_dump('storage.postgres_instance', '');
SELECT pg_catalog.pg_extension_config_dump('storage.postgres_instance_id_seq', '');

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

create table storage.servermap (
   id serial primary key,
   server_map json not null
);

SELECT pg_catalog.pg_extension_config_dump('storage.servermap', '');
SELECT pg_catalog.pg_extension_config_dump('storage.servermap_id_seq', '');

comment on table storage.servermap is
$$ The servermap table stores the server maps by generation so that
we can determine which servers are supposed to receive writes together.$$;

CREATE TABLE storage.dimension (
   id serial NOT NULL UNIQUE,
   ordinality INT NOT NULL UNIQUE DEFERRABLE INITIALLY DEFERRED,
   default_val varchar null default 'notexist',
   fieldname varchar PRIMARY KEY
) inherits (storage.time_bound);

SELECT pg_catalog.pg_extension_config_dump('storage.dimension', '');
SELECT pg_catalog.pg_extension_config_dump('storage.dimension_id_seq', '');


COMMENT ON TABLE storage.dimension IS
$$ This contains the partitions by which data is partitioned. Default values
can be set using the default_val field though this is not yet supported.$$;


create table storage.index (
   id serial not null unique,
   indexname varchar(16) default 'bagger_idx',
   access_method varchar not null, -- extensible, enforced in tooling
   tablespc varchar not null default 'pg_default',
   primary key (indexname)
) inherits (storage.time_bound);

SELECT pg_catalog.pg_extension_config_dump('storage.index', '');
SELECT pg_catalog.pg_extension_config_dump('storage.index_id_seq', '');

comment on table storage.index is
$$ This table includes index definition information for bagger nodes.

This allows us to specify GIN, GIST, btree, and hash index.$$;

--

CREATE TABLE storage.index_field (
   id serial not null unique,
   index_id int not null references storage.index (id),
   ordinality int,
   expression varchar not null,
   primary key (index_id, ordinality) DEFERRABLE INITIALLY DEFERRED
) inherits (storage.time_bound);

SELECT pg_catalog.pg_extension_config_dump('storage.index_field', '');
SELECT pg_catalog.pg_extension_config_dump('storage.index_field_id_seq', '');

COMMENT ON TABLE storage.index_field IS
$$Stores the index fields or expressions.

Some care needs to be paid as to the nature of the contents of this table
because while naive SQL injection is not possile at index creation time,
index can perform arbitrary code at insert or update time.

For this reason registering index is a privileged operation.
$$;



comment on column storage.index_field.expression is
$$This column has an important security consideration because improper
management of index could allow attackers to run arbitrary code during
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

SELECT pg_catalog.pg_extension_config_dump('storage.config', '');
SELECT pg_catalog.pg_extension_config_dump('storage.config_id_seq', '');

comment on table storage.config is
$$ This table stores configuration for the storage nodes.
$$;

comment on column storage.config.value is
$$ JSON is selected here because it is richer than plain text and serialization
libraries are available in all major languages.$$;

-------------
-- Instances
------------

CREATE FUNCTION storage.register_pg_instance
(in_host text, in_port int, in_username text)
RETURNS storage.postgres_instance LANGUAGE SQL
BEGIN ATOMIC
INSERT INTO storage.postgres_instance (host, port, username)
      VALUES (in_host, in_port, in_username)
RETURNING *;
END;

COMMENT ON FUNCTION storage.register_pg_instance
(in_host text, in_port int, in_username text)
IS
$$This function registers a new Postgres instance as a storage node.

By design the new node is created offline (state 0).  The arguments are:

 - in_host:      The hostname or IP address of the host.
 - in_port:      The port that this Postgres instance is listening on.
 - in_username:  The username that Schaufel should connect as.

$$;

----


CREATE FUNCTION STORAGE.set_pg_instance_status
(in_id int, in_status int) 
returns storage.postgres_instance LANGUAGE SQL
BEGIN ATOMIC
UPDATE storage.postgres_instance
   SET status = in_status
 WHERE id = in_id
RETURNING *;
END;

COMMENT ON FUNCTION storage.set_pg_instance_status
(in_id int, in_status int) IS
$$ This function sets the status of a pg_instance to the value set, returning
a complete database row for the instance as stored if successful.$$;

----

CREATE FUNCTION storage.get_pg_instance_by_id(in_id int)
RETURNS storage.postgres_instance LANGUAGE SQL BEGIN ATOMIC
SELECT * FROM storage.postgres_instance where id = in_id;
END;

----

CREATE FUNCTION storage.get_pg_instance_by_host_and_port
(in_host text, in_port int)
returns storage.postgres_instance LANGUAGE SQL BEGIN ATOMIC
select * from storage.postgres_instance where host = in_host and port = in_port;
END;

----

CREATE FUNCTION storage.list_pg_instances()
RETURNS SETOF storage.postgres_instance LANGUAGE SQL BEGIN ATOMIC
SELECT * FROM storage.postgres_instance;
END;

-----------------
-- Dimensions
-----------------


CREATE FUNCTION storage.get_dimensions()
RETURNS SETOF storage.dimension
LANGUAGE SQL BEGIN ATOMIC
  SELECT * FROM storage.dimension
ORDER BY ordinality;
END;

COMMENT ON FUNCTION storage.get_dimensions() IS
$$ Selects an ordered set of dimension.  Note that the ordinality is the
order of evaluation for partitioning and all dimension are evaluated.$$;

----

CREATE FUNCTION storage.append_dimension
(in_fieldname varchar, in_default_val varchar, 
 in_valid_from timestamp, in_valid_until timestamp)
returns storage.dimension
language sql BEGIN ATOMIC
insert into storage.dimension
            (ordinality, fieldname, default_val, valid_from, valid_until)
     select coalesce(max(ordinality) + 1, 0), in_fieldname, 
            coalesce(in_default_val, 'notexist'),
            coalesce(in_valid_from, '-infinity'), 
            coalesce(in_valid_until, 'infinity')
       FROM storage.dimension
  RETURNING *;
END; 

COMMENT ON FUNCTION storage.append_dimension(varchar, varchar, timestamp, timestamp) IS
$$This function inserts a named dimension at the end of the list.

It returns the row as saved.
$$;

-----

CREATE FUNCTION storage.insert_dimension
(in_ordinality int, in_fieldname varchar, in_default_val varchar,
 in_valid_from timestamp, in_valid_until timestamp)
returns storage.dimension language sql BEGIN ATOMIC
-- This is why the ordinality unique constraint is 
-- initially deferred.
UPDATE storage.dimension
   SET ordinality = ordinality + 1
 WHERE ordinality >= in_ordinality;

INSERT INTO storage.dimension
            (ordinality, fieldname, default_val, valid_from, valid_until)
     VALUES (in_ordinality, in_fieldname,
            coalesce(in_default_val, 'notexist'),
             coalesce(in_valid_from, '-infinity'), 
             coalesce(in_valid_until, 'infinity'))
  RETURNING *;
END;

COMMENT ON FUNCTION storage.insert_dimension
(in_ordinality int, in_fieldname varchar, in_default_val varchar,
timestamp, timestamp) IS
$$ This function inserts the dimension at the desired place and returns the row
as saved in the database.

The ordinality of all dimensions equal to or greater than the requested
ordinality number are incremented.
$$;


CREATE FUNCTION storage.expire_dimension 
(in_id int, in_valid_until timestamp)
returns storage.dimension
language sql begin atomic
update storage.dimension
   set valid_until = in_valid_until
 where id = in_id
RETURNING *;
END;

-----------------------
-- Indexes
-----------------------

CREATE FUNCTION storage.insert_index_field
(in_index_id int, in_ordinality int, in_expression varchar,
in_valid_from timestamp, in_valid_until timestamp)
RETURNS storage.index_field LANGUAGE SQL BEGIN ATOMIC
UPDATE storage.index_field
   SET ordinality = ordinality + 1
 WHERE index_id = in_index_id and ordinality >= in_ordinality;

INSERT INTO storage.index_field
       (index_id, ordinality, expression, valid_from, valid_until)
VALUES (in_index_id, in_ordinality, in_expression, in_valid_from,
       in_valid_until)
RETURNING *;
END;
--
CREATE FUNCTION storage.append_index_field(in_index_id int, in_expression varchar,
in_valid_from timestamp, in_valid_until timestamp)
RETURNS storage.index_field LANGUAGE SQL BEGIN ATOMIC
INSERT INTO storage.index_field
       (index_id, expression, ordinality, valid_from, valid_until)
SELECT in_index_id, in_expression, coalesce(max(ordinality) + 1, 0),
       coalesce(in_valid_from, '-infinity'),
       coalesce(in_valid_until, 'infinity')
  FROM storage.index_field WHERE index_id = in_index_id
RETURNING *;
END;
--
CREATE FUNCTION storage.expire_index_field
(in_id int, in_valid_until timestamp)
returns storage.index_field language sql begin atomic
UPDATE storage.index_field
   SET valid_until = in_valid_until
 WHERE id = in_id
RETURNING *;
END;
--
CREATE FUNCTION storage.expire_index
(in_id int, in_valid_until timestamp)
returns storage.index language sql begin atomic
UPDATE storage.index
   SET valid_until = in_valid_until
 WHERE id = in_id
RETURNING *;
END;
--
CREATE FUNCTION storage.get_index_fields(in_index_id int)
RETURNS SETOF storage.index_field LANGUAGE SQL BEGIN ATOMIC
select * from storage.index_field WHERE index_id = in_index_id;
END;
--
CREATE FUNCTION storage.get_index(in_indexname text)
RETURNS storage.index LANGUAGE SQL BEGIN ATOMIC
SELECT * FROM storage.index WHERE indexname = in_indexname;
END;
--
CREATE FUNCTION storage.save_index(in_indexname text, 
in_access_method text, in_tablespc text,
in_valid_until timestamp, in_valid_from timestamp)
RETURNS storage.index LANGUAGE SQL BEGIN ATOMIC
INSERT INTO storage.index (indexname, access_method, tablespc, valid_until,
                             valid_from)
VALUES (in_indexname, in_access_method, coalesce(in_tablespc, 'pg_default'),
       coalesce(in_valid_until, 'infinity'),
       coalesce(in_valid_from, '-infinity'))
ON CONFLICT(indexname)
DO UPDATE SET access_method = in_access_method, valid_until = in_valid_until
RETURNING *;
END;

/* get_index_statement will be done on storage nodes */

-----------------------
-- Config
-----------------------
CREATE FUNCTION storage.get_config(in_key text)
RETURNS storage.config LANGUAGE SQL BEGIN ATOMIC
SELECT * FROM storage.config where key = in_key;
END;
--
CREATE FUNCTION storage.save_config(in_key text, in_value json)
RETURNS storage.config LANGUAGE SQL BEGIN ATOMIC
INSERT INTO storage.config (key, value)
VALUES (in_key, in_value)
ON CONFLICT (key)
DO update set value = in_value
RETURNING *;
END;
---

----------------------
-- Servermaps
----------------------
CREATE FUNCTION storage.get_servermap(in_id int)
returns storage.servermap LANGUAGE SQL BEGIN ATOMIC
SELECT * FROM storage.servermap where id = in_id;
END;

CREATE FUNCTION storage.most_recent_servermap()
RETURNS storage.servermap LANGUAGE SQL BEGIN ATOMIC
SELECT * FROM storage.servermap ORDER BY id desc limit 1;
end;

CREATE FUNCTION storage.save_servermap(in_server_map json)
RETURNS storage.servermap LANGUAGE SQL BEGIN ATOMIC
INSERT INTO storage.servermap (server_map)
VALUES (in_server_map)
RETURNING *;
END;

CREATE FUNCTION storage.servermap_rotate_num()
RETURNS int language sql begin atomic
SELECT count(*) from storage.postgres_instance
group by host order by 1 desc limit 1;
end;

COMMENT ON FUNCTION storage.save_servermap(in_server_map json)
IS
$$ This function always inserts a new record.$$;

---------------------
-- Inbound from kvstore
---------------------

CREATE FUNCTION storage.inbound_from_kvstore
(in_relname regclass, in_value json)
returns void
language plpgsql
as
$$
begin
    -- Note that regclass as a type does escaping during stringification
    execute format(
        'INSERT INTO %s SELECT * from json_populate_record(NULL::%s, $1)',
        in_relname, in_relname) using in_value;
EXCEPTION WHEN unique_violation THEN -- rare enough to take the subtrans hit
    execute format('delete from %s WHERE id = %L', in_relname, in_value->>id::int);
    execute format(
        'INSERT INTO %s SELECT * from json_populate_record(NULL::%s, $1)',
        in_relname, in_relname) using in_value;
    -- if that fails abort.
end;
$$;

CREATE FUNCTION storage.enforce_retention
()
returns void
language plpgsql
as
$$
declare retain_hrs int;
        retain_threshold timestamp;
        delete_rel regclass;
begin
    select trim(both '"' from value)::int into retain_hrs
     FROM storage.config WHERE key = 'retain_hrs';
    IF NOT FOUND THEN
        retain_hrs := 24;
    END IF;
    IF retain_hrs = 0 THEN
        RETURN;
    END IF;
    retain_threshold := now() - make_interval(hours => retain_hrs);

    FOR delete_rel IN 
        SELECT oid FROM regclass 
         WHERE relnamespace::regnamespace::text LIKE 'partition%' AND
               remain_threshold >
               to_timestamp(substring(relname from '.{13}$'),'YYYY_MM_DD_HH24')
    LOOP
        -- we may need to add some sort of lock management here.  My thinking
        -- is that we could set a lock_timeout and skip those we cannot lock
        -- for the current hour.  After all we will try agian next hour.
        -- bot for V1, keeping it very simple.
        execute format('drop table %s', delete_rel::text);
    END LOOP;
end;
$$;

---------------------
-- Other
---------------------

CREATE PUBLICATION bagger_lw_storage
FOR TABLE storage.postgres_instance, 
          storage.index, 
          storage.index_field, 
          storage.dimension, 
          storage.servermap , 
          storage.config;
