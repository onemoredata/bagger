
-------------
-- Instances
------------

-- cannot use create or replace in extensions due to
-- security problems. -- CT
DROP FUNCTION IF EXISTS storage.register_pg_instance
(in_host text, in_port int, in_username text);

CREATE FUNCTION storage.register_pg_instance
(in_host text, in_port int, in_username text)
RETURNS storage.postgres_instance LANGUAGE SQL AS
$$
INSERT INTO storage.postgres_instance (host, port, username)
     VALUES (in_host, in_port, in_username)
RETURNING *;
$$;

COMMENT ON FUNCTION storage.register_pg_instance
(in_host text, in_port int, in_username text)
IS
$$This function registers a new Postgres instance as a storage node.

By design the new node is created offline (state 0).  The arguments are:

 - in_host:      The hostname or IP address of the host.
 - in_port:      The port that this Postgres instance is listening on.
 - in_username:  The username that Schaufel should connect as.

$$;

DROP FUNCTION IF EXISTS storage.set_pg_instance_status
(in_id int, in_status int);

CREATE FUNCTION STORAGE.set_pg_instance_status
(in_id int, in_status int) 
returns storage.postgres_instance LANGUAGE SQL AS
$$
UPDATE storage.postgres_instance
   SET status = in_status
 WHERE id = in_id
RETURNING *;
$$;

COMMENT ON FUNCTION storage.set_pg_instance_status
(in_id int, in_status int) IS
$$ This function sets the status of a pg_instance to the value set, returning
a complete database row for the instance as stored if successful.$$;

DROP FUNCTION IF EXISTS storage.get_pg_instance_by_id(in_id int);
CREATE FUNCTION storage.get_pg_instance_by_id(in_id int)
RETURNS storage.postgres_instance LANGUAGE SQL AS
$$
SELECT * FROM storage.postgres_instance where id = in_id;
$$;

DROP FUNCTION IF EXISTS storage.get_pg_instance_by_host_and_port
(in_host text, in_port int);

CREATE FUNCTION storage.get_pg_instance_by_host_and_port
(in_host text, in_port int)
returns storage.postgres_instance LANGUAGE SQL as
$$
select * from storage.postgres_instance where host = in_host and port = in_port
$$;

DROP FUNCTION IF EXISTS storage.get_dimensions();

CREATE FUNCTION storage.get_dimensions()
RETURNS SETOF partition.dimensions
LANGUAGE SQL AS
$$
  SELECT * FROM partition.dimensions 
ORDER BY ordinality;
$$;


-----------------
-- Dimensions
-----------------

COMMENT ON FUNCTION storage.get_dimensions() IS
$$ Selects an ordered set of dimensions.  Note that the ordinality is the
order of evaluation for partitioning and all dimensions are evaluated.$$;

DROP FUNCTION IF EXISTS storage.append_dimension 
(in_fieldname varchar, in_default_val varchar);

CREATE FUNCTION storage.append_dimension
(in_fieldname varchar, in_default_val varchar)
returns storage.dimensions
language sql as
$$
insert into storage.dimensions
            (ordinality, fieldname, default_val)
     select max(ordinality) + 1, in_fieldname, in_default_val
       FROM storage_dimensions
  RETURNING *;
$$; 

COMMENT ON FUNCTION storage.append_dimension(varchar, varchar) IS
$$This function inserts a named dimension at the end of the list.

It returns the row as saved.
$$;

CREATE FUNCTION storage.insert_dimension
(in_ordinality int, in_fieldname varchar, in_default_val varchar)
returns storage.dimensions language sql as
$$
-- This is why the ordinality unique constraint is 
-- initially deferred.
UPDATE storage.dimensions
   SET ordinality = ordinality + 1
 WHERE ordinality >= in_ordinality;

INSERT INTO storage.dimensions
            (ordinality, fieldname, default_val)
     VALUES (in_ordinality, fieldname, default_val)
  RETURNING *;
$$;

COMMENT ON FUNCTION storage.insert_dimension
(in_ordinality int, in_fieldname varchar, in_default_val varchar) IS
$$ This function inserts the dimension at the desired place and returns the row
as saved in the database.

The ordinality of all dimensions equal to or greater than the requested
ordinality number are incremented.
$$;

-----------------------
-- Partitions
-----------------------



-----------------------
-- Indexes
-----------------------



-----------------------
-- Config
-----------------------
