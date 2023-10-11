-- For timestamps to be set to your timezone
SET
    TIMEZONE = 'Africa/Johannesburg';

-- Get latest transactions
SELECT
    *
FROM
    admin.latest_transactions ()
LIMIT
    10;

-- Get slowest transactions
SELECT
    *
FROM
    admin.slowest_transactions ()
LIMIT
    10;

-- Get latest transaction id
SELECT
    admin.latest_transaction_id ();

-- Get details about transaction (can sub in value instead of admin.latest_transaction_id())
SELECT
    *
FROM
    admin.transaction_details (admin.latest_transaction_id ());

-- Undo transaction by txid (use with caution, not guaranteed to work in all cases)
SELECT
    cyanaudit.fn_undo_transaction (admin.latest_transaction_id ());

-- Latest transactions, showing user and table
WITH
    lt AS (
        SELECT
            txid,
            recorded
        FROM
            admin.latest_transactions ()
    )
SELECT
    lt.txid,
    lt.recorded,
    td.user_email,
    td.table_name
FROM
    lt,
    LATERAL (
        SELECT DISTINCT
            user_email,
            table_name
        FROM
            admin.transaction_details (lt.txid)
    ) td;

-- Plot activity chart in hourly buckets
WITH
    hourly_buckets AS (
        SELECT
            generate_series(
                date_trunc('hour', MIN(recorded)),
                date_trunc('hour', MAX(recorded)),
                interval '1 hour'
            ) AS hour
        FROM
            admin.latest_transactions ()
    )
SELECT
    TO_CHAR(hb.hour, 'Day') AS day_of_week,
    TO_CHAR(hb.hour, 'IYYY-IW') AS iso_week,
    TO_CHAR(hb.hour, 'YYYY-MM-DD HH24') || ':00' AS hour,
    COALESCE(COUNT(lt.txid)::integer, 0) AS count,
    REPEAT('█', COALESCE(COUNT(lt.txid)::integer, 0)) AS bar
FROM
    hourly_buckets hb
    LEFT JOIN admin.latest_transactions () lt ON date_trunc('hour', lt.recorded) = hb.hour
GROUP BY
    hb.hour
ORDER BY
    hour DESC;

-- Plot activity chart in daily buckets
WITH
    daily_buckets AS (
        SELECT
            generate_series(
                date_trunc('day', MIN(recorded)),
                date_trunc('day', MAX(recorded)),
                interval '1 day'
            ) AS day
        FROM
            admin.latest_transactions ()
    )
SELECT
    TO_CHAR(db.day, 'Day') AS day_of_week,
    TO_CHAR(db.day, 'IYYY-IW') AS iso_week,
    TO_CHAR(db.day, 'YYYY-MM-DD') AS day,
    COALESCE(COUNT(lt.txid)::integer, 0) AS count
FROM
    daily_buckets db
    LEFT JOIN admin.latest_transactions () lt ON date_trunc('day', lt.recorded) = db.day
GROUP BY
    db.day
ORDER BY
    day DESC;

-- Plot activity chart in weekly buckets
WITH
    weekly_buckets AS (
        SELECT
            generate_series(
                date_trunc('week', MIN(recorded)),
                date_trunc('week', MAX(recorded)),
                interval '1 week'
            ) AS week
        FROM
            admin.latest_transactions ()
    )
SELECT
    TO_CHAR(wb.week, 'IYYY-IW') AS iso_week,
    COALESCE(COUNT(lt.txid)::integer, 0) AS count
FROM
    weekly_buckets wb
    LEFT JOIN admin.latest_transactions () lt ON date_trunc('week', lt.recorded) = wb.week
GROUP BY
    wb.week
ORDER BY
    iso_week DESC;

-- Plot activity chart in monthly buckets
WITH
    monthly_buckets AS (
        SELECT
            generate_series(
                date_trunc('month', MIN(recorded)),
                date_trunc('month', MAX(recorded)),
                interval '1 month'
            ) AS month
        FROM
            admin.latest_transactions ()
    )
SELECT
    TO_CHAR(mb.month, 'YYYY-MM') AS month,
    COALESCE(COUNT(lt.txid)::integer, 0) AS count
FROM
    monthly_buckets mb
    LEFT JOIN admin.latest_transactions () lt ON date_trunc('month', lt.recorded) = mb.month
GROUP BY
    mb.month
ORDER BY
    month DESC;

-- Plot activity chart in day of week buckets
SELECT
    TO_CHAR(recorded, 'Day') AS day_of_week,
    COALESCE(COUNT(txid)::integer, 0) AS count
FROM
    admin.latest_transactions ()
GROUP BY
    day_of_week
ORDER BY
    count desc;
