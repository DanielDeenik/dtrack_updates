--- Fast forward new server transaction ids to after the historic ones
DO $$
DECLARE
    current_value BIGINT := 0;
    target_value BIGINT;
BEGIN
    SELECT max(txid) INTO target_value FROM cyanaudit.vw_audit_log;
    WHILE current_value < target_value LOOP
    current_value := txid_current();
    COMMIT;
    RAISE NOTICE 'Current value: %', current_value;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

--- Recreate users
SELECT
  auth.create_user (email)
FROM
  unnest(
    (
      SELECT
        array_agg(email)
      FROM
        api.employees
      WHERE
        roles IS NULL
        AND email LIKE '%@hellodnk8n.onmicrosoft.com'
    )
  ) AS t (email);

--- Reassign PM role if applicable
DO $$
DECLARE
  lead_email text;
BEGIN
  FOR lead_email IN
    SELECT distinct email
    FROM internal.user_project_roles AS upr
    JOIN api.employees AS employees ON employees.id = upr.user_id
    WHERE is_lead = TRUE
    AND NOT (roles @> '["pm"]'::jsonb)
  LOOP
    PERFORM auth.grant_priv(lead_email, 'pm');
  END LOOP;
END;
$$ LANGUAGE plpgsql;

--- Reassign lead role if applicable
DO $$
DECLARE
  lead_email text;
BEGIN
  FOR lead_email IN
    SELECT distinct e.email
    FROM internal.aoe_hierarchies AS aoeh
    JOIN api.employees AS e ON aoeh.lead_id = e.id
    WHERE auth.is_supervisor(e.id)
    AND NOT (e.roles @> '["lead"]'::jsonb)
  LOOP
    PERFORM auth.grant_priv(lead_email, 'lead');
  END LOOP;
END;
$$ LANGUAGE plpgsql;

--- TODO: Elevate power users by making a record in the database so that their permissions can be recreated
