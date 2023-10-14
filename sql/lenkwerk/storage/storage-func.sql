
-------------
-- Instances
------------

-- cannot use create or replace in extensions due to
-- security problems. -- CT
DROP FUNCTION IF EXISTS storage.register_pg_instance
(in_host text, in_port int, in_username text);

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

DROP FUNCTION IF EXISTS storage.set_pg_instance_status
(in_id int, in_status int);

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

DROP FUNCTION IF EXISTS storage.get_pg_instance_by_id(in_id int);
CREATE FUNCTION storage.get_pg_instance_by_id(in_id int)
RETURNS storage.postgres_instance LANGUAGE SQL BEGIN ATOMIC
SELECT * FROM storage.postgres_instance where id = in_id;
END;

----

DROP FUNCTION IF EXISTS storage.get_pg_instance_by_host_and_port
(in_host text, in_port int);

CREATE FUNCTION storage.get_pg_instance_by_host_and_port
(in_host text, in_port int)
returns storage.postgres_instance LANGUAGE SQL BEGIN ATOMIC
select * from storage.postgres_instance where host = in_host and port = in_port;
END;

----

DROP FUNCTION IF EXISTS storage.list_pg_instances();

CREATE FUNCTION storage.list_pg_instances()
RETURNS SETOF storage.postgres_instance LANGUAGE SQL BEGIN ATOMIC
SELECT * FROM storage.postgres_instance;
END;

-----------------
-- Dimensions
-----------------


DROP FUNCTION IF EXISTS storage.get_dimensions();

CREATE FUNCTION storage.get_dimensions()
RETURNS SETOF storage.dimensions
LANGUAGE SQL BEGIN ATOMIC
  SELECT * FROM storage.dimensions 
ORDER BY ordinality;
END;

COMMENT ON FUNCTION storage.get_dimensions() IS
$$ Selects an ordered set of dimensions.  Note that the ordinality is the
order of evaluation for partitioning and all dimensions are evaluated.$$;

----

DROP FUNCTION IF EXISTS storage.append_dimension 
(in_fieldname varchar, in_default_val varchar);

CREATE FUNCTION storage.append_dimension
(in_fieldname varchar, in_default_val varchar)
returns storage.dimensions
language sql BEGIN ATOMIC
insert into storage.dimensions
            (ordinality, fieldname, default_val)
     select max(ordinality) + 1, in_fieldname, in_default_val
       FROM storage.dimensions
  RETURNING *;
END; 

COMMENT ON FUNCTION storage.append_dimension(varchar, varchar) IS
$$This function inserts a named dimension at the end of the list.

It returns the row as saved.
$$;

-----

DROP FUNCTION IF EXISTS storage.insert_dimension
(in_ordinality int, in_fieldname varchar, in_default_val varchar);

CREATE FUNCTION storage.insert_dimension
(in_ordinality int, in_fieldname varchar, in_default_val varchar)
returns storage.dimensions language sql BEGIN ATOMIC
-- This is why the ordinality unique constraint is 
-- initially deferred.
UPDATE storage.dimensions
   SET ordinality = ordinality + 1
 WHERE ordinality >= in_ordinality;

INSERT INTO storage.dimensions
            (ordinality, fieldname, default_val)
     VALUES (in_ordinality, in_fieldname, in_default_val)
  RETURNING *;
END;

COMMENT ON FUNCTION storage.insert_dimension
(in_ordinality int, in_fieldname varchar, in_default_val varchar) IS
$$ This function inserts the dimension at the desired place and returns the row
as saved in the database.

The ordinality of all dimensions equal to or greater than the requested
ordinality number are incremented.
$$;

-----------------------
-- Indexes
-----------------------

DROP FUNCTION IF EXISTS storage.insert_index_field(int, int, varchar);
CREATE FUNCTION storage.insert_index_field
(in_index_id int, in_ordinality int, in_expression varchar)
RETURNS storage.index_fields LANGUAGE SQL BEGIN ATOMIC
UPDATE storage.index_fields
   SET ordinality = ordinality + 1
 WHERE index_id = in_index_id and ordinality >= in_ordinality;

INSERT INTO storage.index_fields
       (index_id, ordinality, expression)
VALUES (in_index_id, in_ordinality, in_expression)
RETURNING *;
END;
--
DROP FUNCTION IF EXISTS storage.append_index_field(int, varchar);
CREATE FUNCTION storage.append_index_field(in_index_id int, in_expression varchar)
RETURNS storage.index_fields LANGUAGE SQL BEGIN ATOMIC
INSERT INTO storage.index_fields
       (index_id, expression, ordinality)
SELECT in_index_id, in_expression, max(ordinality) + 1
  FROM storage.index_fields WHERE index_id = in_index_id
RETURNING *;
END;
--
DROP FUNCTION IF EXISTS storage.get_index_fields(int);
CREATE FUNCTION storage.get_index_fields(in_index_id int)
RETURNS SETOF storage.index_fields LANGUAGE SQL BEGIN ATOMIC
select * from storage.index_fields WHERE index_id = in_index_id;
END;
--
DROP FUNCTION IF EXISTS storage.get_index(text);
CREATE FUNCTION storage.get_index(in_indexname text)
RETURNS storage.indexes LANGUAGE SQL BEGIN ATOMIC
SELECT * FROM storage.indexes WHERE indexname = in_indexname;
END;
--
DROP FUNCTION IF EXISTS storage.save_index(text, text, text);
CREATE FUNCTION storage.save_index(in_indexname text, in_access_method text, in_tablespc text)
RETURNS storage.indexes LANGUAGE SQL BEGIN ATOMIC
INSERT INTO storage.indexes (indexname, access_method, tablespc)
VALUES (in_indexname, in_access_method, tablespc)
ON CONFLICT(indexname)
DO UPDATE SET access_method = in_access_method
RETURNING *;
END;

/* get_index_statement will be done on storage nodes */

-----------------------
-- Config
-----------------------
DROP FUNCTION IF EXISTS storage.get_config(text);
CREATE FUNCTION storage.get_config(in_key text)
RETURNS storage.config LANGUAGE SQL BEGIN ATOMIC
SELECT * FROM storage.config where key = in_key;
END;
--
DROP FUNCTION IF EXISTS storage.save_config(text, json);
CREATE FUNCTION storage.save_config(in_key text, in_value json)
RETURNS storage.config LANGUAGE SQL BEGIN ATOMIC
INSERT INTO storage.config (key, value)
VALUES (in_key, in_value)
ON CONFLICT (key)
DO update set value = in_value
RETURNING *;
END;
---
