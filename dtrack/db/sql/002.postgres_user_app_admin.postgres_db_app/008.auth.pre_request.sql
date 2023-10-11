CREATE SCHEMA pre;

ALTER SCHEMA pre OWNER TO "$POSTGRES_USER_APP_ADMIN";

CREATE
OR REPLACE FUNCTION pre.request () RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_state TEXT;
    v_msg TEXT;
BEGIN
    -- TODO: Consider checking audience and issuer
    PERFORM set_config('cyanaudit.uid', auth.get_current_user_id()::varchar, true);
EXCEPTION
    WHEN insufficient_privilege THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        RAISE WARNING '%: %', v_state, v_msg;
END;
$$;

GRANT USAGE ON SCHEMA pre TO anon;

GRANT USAGE ON SCHEMA pre TO basic;

GRANT
EXECUTE ON FUNCTION pre.request TO anon;

GRANT
EXECUTE ON FUNCTION pre.request TO basic;
