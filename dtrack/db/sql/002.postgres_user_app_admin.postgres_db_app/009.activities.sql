CREATE
OR REPLACE FUNCTION internal.activities_upsert () RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    new_activity_id integer;
BEGIN
    IF NEW.id IS NULL THEN
        INSERT INTO internal.activities (name, description)
        VALUES (NEW.name, NEW.description)
        RETURNING activity_id INTO new_activity_id;
    ELSE
        new_activity_id = NEW.ID;
        INSERT INTO internal.activities (activity_id, name, description)
        VALUES (new_activity_id, NEW.name, NEW.description)
        ON CONFLICT (activity_id)
        DO UPDATE SET
            name = NEW.name,
            description = NEW.description;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER activities_instead_of_insert INSTEAD OF INSERT ON api.activities FOR EACH ROW
EXECUTE FUNCTION internal.activities_upsert ();

CREATE TRIGGER activities_instead_of_update INSTEAD OF
UPDATE ON api.activities FOR EACH ROW
EXECUTE FUNCTION internal.activities_upsert ();

CREATE
OR REPLACE FUNCTION internal.activities_delete () RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM internal.activities
    WHERE activity_id = OLD.id;
    RETURN OLD;
END;
$$;

CREATE TRIGGER activities_instead_of_delete INSTEAD OF DELETE ON api.activities FOR EACH ROW
EXECUTE FUNCTION internal.activities_delete ();
