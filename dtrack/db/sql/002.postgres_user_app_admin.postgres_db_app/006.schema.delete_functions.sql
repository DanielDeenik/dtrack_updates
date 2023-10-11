CREATE
OR REPLACE FUNCTION api.time_trackings_instead_of_delete () RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM internal.time_trackings
    WHERE task_id = OLD.id;
    RETURN OLD;
END;
$$;

CREATE TRIGGER time_trackings_instead_of_delete INSTEAD OF DELETE ON api.time_trackings FOR EACH ROW
EXECUTE FUNCTION api.time_trackings_instead_of_delete ();

CREATE
OR REPLACE FUNCTION auth.auto_aoe_hierarchies_insert (given_aoe_id integer, given_lead_id integer) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM internal.aoe_hierarchies WHERE aoe_id = given_aoe_id AND lead_id = given_lead_id) THEN
        INSERT INTO internal.aoe_hierarchies (aoe_id, lead_id, member_id)
        VALUES (given_aoe_id, given_lead_id, given_lead_id);
    END IF;
END;
$$;

GRANT
EXECUTE ON FUNCTION auth.auto_aoe_hierarchies_insert (given_aoe_id integer, given_lead_id integer) TO lead;

-- TODO: Add description
CREATE
OR REPLACE FUNCTION internal.delete_aoe_teams () RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Delete rows for the given aoe_id and lead_id
        DELETE FROM internal.aoe_hierarchies WHERE aoe_id = (OLD.aoe->>'id')::integer AND lead_id = (OLD.lead->>'id')::integer;

        -- Power users can fully delete the record, but a lead should only be
        -- able to delete their members from the team, leaving themselves as a placeholder
        IF NOT pg_has_role('power', 'MEMBER') THEN
            PERFORM auth.auto_aoe_hierarchies_insert((OLD.aoe->>'id')::integer, (OLD.lead->>'id')::integer);
        END IF;

        -- Sync privs
        PERFORM internal.aoe_teams_grant_or_revoke_privs ((OLD.lead->>'id')::integer);
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- TODO: Add description
CREATE TRIGGER delete_aoe_teams INSTEAD OF DELETE ON api.aoe_teams FOR EACH ROW
EXECUTE FUNCTION internal.delete_aoe_teams ();

-- Create a trigger function to perform upsert operations on the
-- internal.areas_of_expertise table when an insert or update operation is
-- performed on the api.areas_of_expertise view
CREATE
OR REPLACE FUNCTION internal.upsert_areas_of_expertise () RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO internal.areas_of_expertise (name, description)
        VALUES (NEW.name, NEW.description)
        ON CONFLICT (name) DO UPDATE SET description = EXCLUDED.description;
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        UPDATE internal.areas_of_expertise SET name = NEW.name, description = NEW.description WHERE aoe_id = OLD.id;
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to execute the upsert_areas_of_expertise function instead of
-- insert or update operations on the api.areas_of_expertise view
CREATE TRIGGER upsert_areas_of_expertise INSTEAD OF INSERT
OR
UPDATE ON api.areas_of_expertise FOR EACH ROW
EXECUTE FUNCTION internal.upsert_areas_of_expertise ();

CREATE
OR REPLACE FUNCTION internal.delete_areas_of_expertise () RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM internal.areas_of_expertise
    WHERE aoe_id = OLD.id;
    RETURN OLD;
END;
$$;

CREATE TRIGGER delete_areas_of_expertise INSTEAD OF DELETE ON api.areas_of_expertise FOR EACH ROW
EXECUTE FUNCTION internal.delete_areas_of_expertise ();

CREATE
OR REPLACE FUNCTION internal.delete_employee () RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    user_email text;
BEGIN
    DELETE FROM internal.aoe_hierarchies
    WHERE lead_id = OLD.id OR member_id = OLD.id;
    DELETE FROM internal.user_project_roles
    WHERE user_id = OLD.id;
    PERFORM auth.del_user(OLD.email);
    RETURN OLD;
END;
$$;

CREATE TRIGGER delete_employee INSTEAD OF DELETE ON api.employees FOR EACH ROW
EXECUTE FUNCTION internal.delete_employee ();
