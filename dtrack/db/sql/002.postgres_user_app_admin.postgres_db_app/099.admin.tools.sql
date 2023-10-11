CREATE SCHEMA admin AUTHORIZATION "$POSTGRES_USER_APP_ADMIN";

-- Get transactions
CREATE
OR REPLACE FUNCTION admin.transactions () RETURNS TABLE (txid bigint, recorded timestamp, duration numeric) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.txid AS txid,
        MIN(c.recorded AT TIME ZONE 'UTC' AT TIME ZONE current_setting('TimeZone')) AS recorded,
        EXTRACT(EPOCH FROM MAX(c.recorded) - MIN(c.recorded)) AS duration
    FROM cyanaudit.vw_audit_log AS c
    GROUP BY c.txid
    ORDER BY c.txid DESC;
END;
$$ LANGUAGE plpgsql;

-- Get slowest transactions
CREATE
OR REPLACE FUNCTION admin.slowest_transactions () RETURNS TABLE (txid bigint, duration numeric, recorded timestamp) AS $$
BEGIN
    RETURN QUERY
    SELECT t.txid AS txid, t.duration AS duration, t.recorded AS recorded
    FROM admin.transactions() AS t
    ORDER BY t.duration DESC;
END;
$$ LANGUAGE plpgsql;

-- Get latest transactions
CREATE
OR REPLACE FUNCTION admin.latest_transactions () RETURNS TABLE (txid bigint, recorded timestamp, duration numeric) AS $$
BEGIN
    RETURN QUERY
    SELECT t.txid AS txid, t.recorded AS recorded, t.duration AS duration
    FROM admin.transactions() AS t
    ORDER BY t.recorded DESC;
END;
$$ LANGUAGE plpgsql;

-- Get details about transaction
CREATE
OR REPLACE FUNCTION admin.transaction_details (p_txid bigint) RETURNS TABLE (
    recorded timestamp,
    uid integer,
    user_email varchar,
    txid bigint,
    description varchar,
    table_name varchar,
    column_name varchar,
    pk_vals text[],
    op character,
    old_value text,
    new_value text
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.recorded AT TIME ZONE 'UTC' AT TIME ZONE current_setting('TimeZone') AS recorded,
        c.uid AS uid,
        c.user_email AS user_email,
        c.txid AS txid,
        c.description AS description,
        c.table_name AS table_name,
        c.column_name AS column_name,
        c.pk_vals AS pk_vals,
        c.op AS op,
        c.old_value AS old_value,
        c.new_value AS new_value
    FROM cyanaudit.vw_audit_log AS c
    WHERE c.txid = p_txid
    ORDER BY c.recorded DESC;
END;
$$ LANGUAGE plpgsql;

-- Get the latest transaction id
CREATE
OR REPLACE FUNCTION admin.latest_transaction_id () RETURNS bigint AS $$
BEGIN
    RETURN (SELECT MAX(txid) FROM admin.latest_transactions() LIMIT 1);
END;
$$ LANGUAGE plpgsql;
