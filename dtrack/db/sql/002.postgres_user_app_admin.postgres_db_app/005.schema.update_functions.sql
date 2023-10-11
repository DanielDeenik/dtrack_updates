CREATE
OR REPLACE FUNCTION api.time_trackings_instead_of_update () RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE internal.time_trackings
    SET description = NEW.description,
        date = NEW.date,
        duration = NEW.duration::interval,
        user_id = (NEW.user->>'id')::integer,
        project_id = (NEW.project->>'id')::integer,
        activity_id = (NEW.activity->>'id')::integer,
        aow_id = (NEW.aow->>'id')::integer
    WHERE task_id = OLD.id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER time_trackings_instead_of_update INSTEAD OF
UPDATE ON api.time_trackings FOR EACH ROW
EXECUTE FUNCTION api.time_trackings_instead_of_update ();
