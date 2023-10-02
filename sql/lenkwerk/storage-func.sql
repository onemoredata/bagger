-- cannot use create or replace in extensions due to
-- security problems. -- CT
DROP FUNCTION IF EXISTS storage.register_pg_instance
(in_host text, in_port int, in_username text);

CREATE FUNCTION storage.register_pg_instance
(in_host text, in_port int, in_username text)
RETURNS storage.pg_instance LANGUAGE SQL AS
$$
INSERT INTO storage.pg_instance (host, port, username)
     VALUES (in_host, in_port in_username)
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
returns storage.pg_instance AS
$$
UPDATE storage.pg_instance
   SET status = in_status
 WHERE id = in_id
RETURNING *;
$$;

COMMENT ON FUNCTION storage.set_pg_instance_status
(in_id int, in_status int) IS
$$ This function sets the status of a pg_instance to the value set, returning
a complete database row for the instance as stored if successful.$$;
