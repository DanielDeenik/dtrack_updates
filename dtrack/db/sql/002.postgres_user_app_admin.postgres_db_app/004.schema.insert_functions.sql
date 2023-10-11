CREATE
OR REPLACE FUNCTION api.time_trackings_instead_of_insert () RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO internal.time_trackings (
        description,
        date,
        duration,
        user_id,
        project_id,
        activity_id,
        aow_id
    )
    VALUES (
        NEW.description,
        NEW.date,
        NEW.duration::interval,
        (NEW.user->>'id')::integer,
        (NEW.project->>'id')::integer,
        (NEW.activity->>'id')::integer,
        (NEW.aow->>'id')::integer
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER time_trackings_instead_of_insert INSTEAD OF INSERT ON api.time_trackings FOR EACH ROW
EXECUTE FUNCTION api.time_trackings_instead_of_insert ();

-- This function is a trigger function for upserting Area of Expertise (AoE) teams in the internal.aoe_hierarchies table.
-- It performs various checks and operations such as checking if lead.id is empty, checking if the user has permission to edit AoE or Line Manager,
-- deleting and inserting rows in the internal.aoe_hierarchies table, and updating privileges based on changes.
CREATE
OR REPLACE FUNCTION internal.upsert_aoe_teams () RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  new_member_ids jsonb;
BEGIN
  -- The trigger function only operates on INSERT or UPDATE operations
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    -- Check if lead.id is empty
    IF NEW.lead->>'id' IS NULL THEN
      RAISE EXCEPTION 'Lead cannot be empty';
    END IF;

    -- Check if the user has permission to edit AoE or Line Manager
    IF (OLD.lead->>'id' <> NEW.lead->>'id' OR OLD.aoe->>'id' <> NEW.aoe->>'id')
    AND NOT pg_has_role('power', 'MEMBER') THEN
      RAISE EXCEPTION 'Permission denied to edit AoE or Line Manager';
    END IF;

    -- If no value is passed in for members, use the lead.id as the default value
    new_member_ids = COALESCE(NULLIF(NEW.member_ids, '[]'), jsonb_build_array(NEW.lead->>'id'));

    -- Delete only the necessary rows for the given aoe_id and lead_id
    DELETE FROM internal.aoe_hierarchies as aoe_hierarchies
    WHERE aoe_id = (OLD.aoe->>'id')::integer
    AND lead_id = (OLD.lead->>'id')::integer
    AND member_id NOT IN (
        SELECT value::integer
        FROM jsonb_array_elements_text(new_member_ids)
    );

    -- Insert only the necessary rows for each member_id in new_member_ids
    INSERT INTO internal.aoe_hierarchies (aoe_id, lead_id, member_id)
    SELECT
        (NEW.aoe->>'id')::integer,
        (NEW.lead->>'id')::integer,
        new_member_id
    FROM (
        SELECT jsonb_array_elements_text(new_member_ids)::integer AS new_member_id
    ) AS new_members
    WHERE new_member_id NOT IN (
        SELECT value::integer
        FROM jsonb_array_elements_text(OLD.member_ids)
    );

    -- Cleanup placeholder if it exists when it shouldn't (i.e. entry where lead_id = member_id is not the only record for given aoe_id)
    DELETE FROM internal.aoe_hierarchies
    WHERE aoe_id = (NEW.aoe->>'id')::integer
      AND lead_id = (NEW.lead->>'id')::integer
      AND lead_id = member_id
      AND EXISTS (
        SELECT 1 FROM internal.aoe_hierarchies
        WHERE aoe_id = (NEW.aoe->>'id')::integer
          AND lead_id = (NEW.lead->>'id')::integer
          AND lead_id <> member_id
      );

    -- Update privileges based on changes using the internal.aoe_teams_grant_or_revoke_privs function
    PERFORM internal.aoe_teams_grant_or_revoke_privs ((NEW.lead->>'id')::integer);

  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER upsert_aoe_teams INSTEAD OF INSERT
OR
UPDATE ON api.aoe_teams FOR EACH ROW
EXECUTE FUNCTION internal.upsert_aoe_teams ();
