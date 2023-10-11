CREATE
OR REPLACE FUNCTION internal.areas_of_work_upsert () RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    new_aow_id integer;
BEGIN
    IF NEW.id IS NULL THEN
        INSERT INTO internal.areas_of_work (name)
        VALUES (NEW.name)
        RETURNING aow_id INTO new_aow_id;
    ELSE
        new_aow_id = NEW.ID;
        INSERT INTO internal.areas_of_work (aow_id, name)
        VALUES (new_aow_id, NEW.name)
        ON CONFLICT (aow_id)
        DO UPDATE SET
            name = NEW.name;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER areas_of_work_instead_of_insert INSTEAD OF INSERT ON api.areas_of_work FOR EACH ROW
EXECUTE FUNCTION internal.areas_of_work_upsert ();

CREATE TRIGGER areas_of_work_instead_of_update INSTEAD OF
UPDATE ON api.areas_of_work FOR EACH ROW
EXECUTE FUNCTION internal.areas_of_work_upsert ();

CREATE
OR REPLACE FUNCTION internal.areas_of_work_delete () RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM internal.areas_of_work
    WHERE aow_id = OLD.id;
    RETURN OLD;
END;
$$;

CREATE TRIGGER areas_of_work_instead_of_delete INSTEAD OF DELETE ON api.areas_of_work FOR EACH ROW
EXECUTE FUNCTION internal.areas_of_work_delete ();
