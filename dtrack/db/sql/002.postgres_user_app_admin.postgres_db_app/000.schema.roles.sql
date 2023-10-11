-- Revoke public function execution
ALTER DEFAULT PRIVILEGES
REVOKE
EXECUTE ON FUNCTIONS
FROM
    PUBLIC;

-- privileges are cumulative (except pm and lead are in line)
GRANT basic TO pm;

GRANT basic TO lead;

GRANT pm TO power;

GRANT lead TO power;

GRANT power TO "$POSTGRES_USER_APP_ADMIN";

-- Allow each role to login via "$POSTGRES_USER_APP"
GRANT anon TO "$POSTGRES_USER_APP";

GRANT basic TO "$POSTGRES_USER_APP";

GRANT pm TO "$POSTGRES_USER_APP";

GRANT lead TO "$POSTGRES_USER_APP";

GRANT power TO "$POSTGRES_USER_APP";

-- Internal schema is home to main data
CREATE SCHEMA internal;

ALTER DEFAULT PRIVILEGES IN SCHEMA internal
GRANT
SELECT
,
    INSERT,
    DELETE,
UPDATE ON TABLES TO basic;

-- change to soft delete
ALTER DEFAULT PRIVILEGES IN SCHEMA internal
GRANT
SELECT
,
    USAGE ON SEQUENCES TO basic;

-- Views abstract what data is allowed to be consumed by the API
CREATE SCHEMA api;

ALTER DEFAULT PRIVILEGES IN SCHEMA api
GRANT
SELECT
,
    INSERT,
    DELETE,
UPDATE ON TABLES TO basic;

-- change to soft delete
ALTER DEFAULT PRIVILEGES IN SCHEMA api
GRANT
SELECT
,
    USAGE ON SEQUENCES TO basic;

-- Schema usage
GRANT USAGE ON SCHEMA api TO anon;

GRANT USAGE ON SCHEMA api TO basic;

GRANT USAGE ON SCHEMA internal TO basic;

GRANT USAGE ON SCHEMA auth TO basic;

-- Allow PostgREST login
GRANT CONNECT ON DATABASE "$POSTGRES_DB_APP" TO "$POSTGRES_USER_APP";

-- Allow basic and above access to executing functions
GRANT
EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO basic;
