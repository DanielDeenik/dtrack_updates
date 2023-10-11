CREATE
OR REPLACE FUNCTION internal.projects_upsert () RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    new_project_id integer;
    lead_email_revoke text;
    lead_email_grant text;
BEGIN
    IF NEW.id IS NULL THEN
        INSERT INTO internal.projects (name, description, start_date, end_date)
        VALUES (NEW.name, NEW.description, NEW.start_date, NEW.end_date)
        RETURNING project_id INTO new_project_id;
    ELSE
        new_project_id = NEW.ID;
        INSERT INTO internal.projects (project_id, name, description, start_date, end_date)
        VALUES (new_project_id, NEW.name, NEW.description, NEW.start_date, NEW.end_date)
        ON CONFLICT (project_id)
        DO UPDATE SET
            name = NEW.name,
            description = NEW.description,
            start_date = NEW.start_date,
            end_date = NEW.end_date;
    END IF;

    -- Revoke pm role from removed leads
    FOR lead_email_revoke IN
        SELECT u.email
        FROM internal.user_project_roles upr
        JOIN auth.users u USING (user_id)
        WHERE upr.project_id = new_project_id
        AND upr.is_lead IS TRUE
        AND upr.user_id IN (
            SELECT value::integer FROM jsonb_array_elements_text(OLD.lead_ids)
        )
        AND upr.user_id NOT IN (
            SELECT value::integer FROM jsonb_array_elements_text(NEW.lead_ids)
        )
        AND NOT EXISTS (
            SELECT 1
            FROM internal.user_project_roles upr2
            WHERE upr2.user_id = upr.user_id
            AND upr2.project_id <> new_project_id
            AND upr2.is_lead IS TRUE
        )
    LOOP
        PERFORM auth.revoke_priv(lead_email_revoke, 'pm');
    END LOOP;

    -- Grant pm role to new leads if not already
    FOR lead_email_grant IN
        SELECT email
        FROM jsonb_array_elements_text(NEW.lead_ids) AS lead_id
        JOIN api.employees e ON lead_id::integer = e.id
        WHERE NOT e.roles ? 'pm'
    LOOP
        PERFORM auth.grant_priv(lead_email_grant, 'pm');
    END LOOP;

    -- Delete only the necessary user_project_roles records
    DELETE FROM internal.user_project_roles
    WHERE project_id = new_project_id AND (
        (is_lead = FALSE AND user_id NOT IN (SELECT value::integer FROM jsonb_array_elements_text(NEW.member_ids)))
        OR (is_lead = TRUE AND user_id NOT IN (SELECT value::integer FROM jsonb_array_elements_text(NEW.lead_ids)))
    );

    -- Add new members
    INSERT INTO internal.user_project_roles (user_id, project_id, is_lead)
    SELECT member_id::integer, new_project_id, FALSE
    FROM jsonb_array_elements_text(NEW.member_ids) AS member_id
    WHERE member_id::integer NOT IN (SELECT user_id FROM internal.user_project_roles WHERE project_id = new_project_id AND is_lead = FALSE);

    -- Add new leads
    INSERT INTO internal.user_project_roles (user_id, project_id, is_lead)
    SELECT lead_id::integer, new_project_id, TRUE
    FROM jsonb_array_elements_text(NEW.lead_ids) AS lead_id
    WHERE lead_id::integer NOT IN (SELECT user_id FROM internal.user_project_roles WHERE project_id = new_project_id AND is_lead = TRUE);

    -- Delete only the necessary project_areas_of_work records
    DELETE FROM internal.project_areas_of_work
    WHERE project_id = new_project_id AND aow_id NOT IN (SELECT value::integer FROM jsonb_array_elements_text(NEW.aow_ids));

    -- Add new aows
    INSERT INTO internal.project_areas_of_work (project_id, aow_id)
    SELECT new_project_id, aow_id::integer
    FROM jsonb_array_elements_text(NEW.aow_ids) AS aow_id
    WHERE aow_id::integer NOT IN (SELECT aow_id FROM internal.project_areas_of_work WHERE project_id = new_project_id);

    -- Delete only the necessary project_activities records
    DELETE FROM internal.project_activities
    WHERE project_id = new_project_id AND activity_id NOT IN (SELECT value::integer FROM jsonb_array_elements_text(NEW.activity_ids));

    -- Add new activities
    INSERT INTO internal.project_activities (project_id, activity_id)
    SELECT new_project_id, activity_id::integer
    FROM jsonb_array_elements_text(NEW.activity_ids) AS activity_id
    WHERE activity_id::integer NOT IN (SELECT activity_id FROM internal.project_activities WHERE project_id = new_project_id);

    RETURN NEW;
END;
$$;

CREATE TRIGGER projects_instead_of_insert INSTEAD OF INSERT ON api.projects FOR EACH ROW
EXECUTE FUNCTION internal.projects_upsert ();

CREATE TRIGGER projects_instead_of_update INSTEAD OF
UPDATE ON api.projects FOR EACH ROW
EXECUTE FUNCTION internal.projects_upsert ();

CREATE
OR REPLACE FUNCTION internal.projects_delete () RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    lead_email_revoke text;
BEGIN
    -- Revoke pm role from all OLD leads if they aren't also a lead elsewhere
    FOR lead_email_revoke IN
        SELECT u.email
        FROM internal.user_project_roles upr
        JOIN auth.users u USING (user_id)
        WHERE upr.user_id IN (
            SELECT value::integer FROM jsonb_array_elements_text(OLD.lead_ids)
        )
        AND NOT EXISTS (
            SELECT 1
            FROM internal.user_project_roles upr2
            WHERE upr2.user_id = upr.user_id
            AND upr2.project_id <> OLD.id
            AND upr2.is_lead IS TRUE
        )
    LOOP
        PERFORM auth.revoke_priv(lead_email_revoke, 'pm');
    END LOOP;
    -- internal.areas_of_work
    DELETE FROM internal.project_areas_of_work
    WHERE project_id = OLD.id;
    -- internal.activities
    DELETE FROM internal.project_activities
    WHERE project_id = OLD.id;
    -- internal.user_project_roles
    DELETE FROM internal.user_project_roles
    WHERE project_id = OLD.id;
    -- internal.projects
    DELETE FROM internal.projects
    WHERE project_id = OLD.id;
    --
    RETURN OLD;
END;
$$;

CREATE TRIGGER projects_instead_of_delete INSTEAD OF DELETE ON api.projects FOR EACH ROW
EXECUTE FUNCTION internal.projects_delete ();
