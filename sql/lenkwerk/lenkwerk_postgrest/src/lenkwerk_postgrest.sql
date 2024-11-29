-- extension source

-- depends on pgcrypto
-- basic design is such:

-- assumption here is that secrets are reasonably well protected and that
-- and that we rely on specific validation logic by approved users.

-- Additionally for version 1 we will assume that we are not generally having
-- to do sharing of JWTs in a way which requires asymmetric encryption.  Support
-- for public key encyption here will be left for a later version and subject to
-- customer/product discovery efforts.  In that case the key management is
-- the hard part.

-- We will depend here on Michel Paquier's pgjwt extension installed into a jwt
-- schema.

CREATE SCHEMA lenkwerk_postgrest;
CREATE ROLE IF NOT EXISTS lenkwerk_queryproxy_op INHERIT NOLOGIN;
-- Must set auth info outside
CREATE ROLE IF NOT EXISTS queryproxy NOINHERIT LOGIN;

CREATE TABLE lenkwerk_postgrest.user_auth (
    username TEXT PRIMARY KEY,
    auth TEXT,
    role TEXT
);
SELECT pg_catalog.pg_extension_config_dump('lenkwerk_postgrest.user_auth', '');

REVOKE ALL ON lenkwerk_postgrest.user_auth FROM public;


CREATE TABLE lenkwerk_postgrest.secrets (
    secret_name TEXT PRIMARY KEY,
    secret_value TEXT,
    is_base64 BOOL
);
SELECT pg_catalog.pg_extension_config_dump('lenkwerk_postgrest.secrets', '');

REVOKE ALL ON lenkwerk_postgrest.secrets FROM public;

CREATE TABLE lenkwerk_postgrest.config (
    config_name TEXT PRIMARY KEY,
    config_value JSONB
);
SELECT pg_catalog.pg_extension_config_dump('lenkwerk_postgrest.config', '');

CREATE FUNCTION lenkwerk_postgres.pgrest_preconfig() LANGUAGE SQL
SECURITY DEFINER RETURNS VOID
BEGIN ATOMIC
  SELECT set_config('pgrst.jwt_secret', secret_value, true) FROM lenkwerk_postgres.secrets where secret_name = 'jwt_secret';
  SELECT set_config('pgrst.db_schemas', 'storage', true);
END;

CREATE FUNCTION lenkwerk_postgres.set_jwt_secret(secret TEXT, base64 BOOL)
LANGUAGE SQL SECURITY DEFINER
RETURNS VOID
BEGIN ATOMIC
INSERT INTO lenkwerk_postgres.secrets (secret_name, secret_value, in_base64)
VALUES ('jwt_secret', secret, base64)
ON CONFLICT (secret_name) update set secret_name = secret, is_base64 = base64;
END;

CREATE FUNCTION lenkwerk_postgres.generate_jwt(in_role TEXT) RETURNS text
LANGUAGE SQL AS
$$
SELECT jwt.sign( row_to_json(r), current_setting('pgrst.jwt_secret')) AS token
FROM ( SELECT in_role AS role, 
              extract(epoch FROM now() + current_setting('pgrst.timeout') 
                AS exp
     ) r;
$$;

CREATE FUNCTION lenkwerk_postgres.authenticate_user
(in_username TEXT, in_password TEXT)
returns TEXT
LANGUAGE SQL AS
$$
SELECT ROLE FROM lenkwerk_postgres.user_auth 
 WHERE in_username = username AND auth = crypt(in_password, auth);
$$ SECURITY DEFINER;

CREATE FUNCTION lenkwerk_postgres.change_password(username, password)
RETURNS BOOL LANGUAGE PLPGSQL SECURITY DEFINER AS
$$
BEGIN
    UPDATE lenkwerk_postgres.user_auth SET auth = crypt(password, 
        gen_salt('bf', 8)); -- going with high work factor since this is not
                            -- done on every request
    RETURN FOUND;
$$;



