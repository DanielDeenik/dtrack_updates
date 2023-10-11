DO $$
DECLARE
    r RECORD;
BEGIN
    UPDATE cyanaudit.tb_config SET VALUE = 'users' WHERE NAME = 'user_table';
    -- Because postgres user/roles take format of email, username_col must match to email
    -- Role needs to come from JWT preferred username (which is an email)
    UPDATE cyanaudit.tb_config SET VALUE = 'email' WHERE NAME = 'user_table_username_col';
    UPDATE cyanaudit.tb_config SET VALUE = 'email' WHERE NAME = 'user_table_email_col';
    UPDATE cyanaudit.tb_config SET VALUE = 'user_id' WHERE NAME = 'user_table_uid_col';
    FOR r IN (
        SELECT nspname
        FROM pg_namespace
        WHERE nspname NOT IN ('cyanaudit', 'pg_toast', 'pg_catalog', 'information_schema')
    )
    LOOP
        BEGIN
            EXECUTE format('SELECT cyanaudit.fn_update_audit_fields(%L)', r.nspname);
            RAISE INFO 'Turned on CyanAudit logging for schema %', r.nspname;
        EXCEPTION WHEN insufficient_privilege THEN
            RAISE WARNING 'Permission denied for schema %: skipping update', r.nspname;
        END;
    END LOOP;
END $$;
