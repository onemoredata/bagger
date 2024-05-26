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

CREATE SCHEMA lenkwerk_postgres;
CREATE ROLE IF NOT EXISTS lenkwerk_queryproxy_op INHERIT NOLOGIN;
-- Must set auth info outside
CREATE ROLE IF NOT EXISTS queryproxy NOINHERIT LOGIN;

CREATE TABLE lenkwerk_postgres.user_auth (
    username text primary key,
    auth text,
    role text
);

REVOKE ALL ON lenkwerk_postgres.user_auth FROM public;


CREATE TABLE lenkwerk_postgres.secrets (
    secret_name text primary key,
    secret_value text,
    is_base64 bool
);

REVOKE ALL ON lenkwerk_postgres.secrets FROM public;

CREATE TABLE lenkwerk_postgres.config (
    config_name text primary key,
    config_value JSONB
);

CREATE FUNCTION lenkwerk_postgres.pgrest_preconfig() LANGUAGE SQL
SECURITY DEFINER RETURNS VOID
BEGIN ATOMIC
  select set_config('pgrst.jwt_secret', secret_value, true) from lenkwerk_postgres.secrets where secret_name = 'jwt_secret';
  select set_config('pgrst.db_schemas', 'storage', true);
END;

CREATE FUNCTION lenkwerk_postgres.set_jwt_secret(secret text, base64 bool)
LANGUAGE SQL SECURITY DEFINER
RETURNS VOID
BEGIN ATOMIC
INSERT INTO lenkwerk_postgres.secrets (secret_name, secret_value, in_base64)
VALUES ('jwt_secret', secret, base64)
ON CONFLICT (secret_name) update set secret_name = secret, is_base64 = base64;
END;

CREATE FUNCTION lenkwerk_postgres.generate_jwt(in_role text) returns text
language sql as
$$
select jwt.sign( row_to_json(r), current_setting('pgrst.jwt_secret')) as token
FROM ( select in_role as role, 
              extract(epoch from now() + current_setting('pgrst.timeout') 
                as exp
     ) r;
$$;

CREATE FUNCTION lenkwerk_postgres.validate_jwt....

CREATE FUNCTION lenkwerk_postgres.authenticate_user
(in_username text, in_password text)
returns text
language sql as
$$
select role from lenkwerk_postgres.user_auth 
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



