CREATE TABLE IF NOT EXISTS
    auth.users (
        user_id serial primary key,
        username text unique not null,
        email text unique not null,
        first_name text,
        last_name text,
        position text
    );

GRANT
SELECT
    ON TABLE auth.users TO basic;

GRANT
SELECT
    ON SEQUENCE auth.users_user_id_seq TO basic;

GRANT INSERT,
UPDATE ON TABLE auth.users TO power;

GRANT
UPDATE ON SEQUENCE auth.users_user_id_seq TO power;

CREATE TABLE IF NOT EXISTS
    internal.activities (
        activity_id serial primary key,
        name text unique not null,
        description text
    );

CREATE TABLE IF NOT EXISTS
    internal.areas_of_work (
        aow_id serial primary key,
        name text unique not null
    );

CREATE TABLE IF NOT EXISTS
    internal.projects (
        project_id serial primary key,
        name text unique not null,
        start_date date,
        end_date date,
        description text
    );

CREATE TABLE IF NOT EXISTS
    internal.project_activities (
        project_id integer not null,
        activity_id integer not null,
        primary key (project_id, activity_id),
        foreign key (project_id) references internal.projects (project_id) on delete restrict on update cascade,
        foreign key (activity_id) references internal.activities (activity_id) on delete restrict on update cascade
    );

CREATE TABLE IF NOT EXISTS
    internal.project_areas_of_work (
        project_id integer not null,
        aow_id integer not null,
        primary key (project_id, aow_id),
        foreign key (project_id) references internal.projects (project_id) on delete restrict on update cascade,
        foreign key (aow_id) references internal.areas_of_work (aow_id) on delete restrict on update cascade
    );

CREATE TABLE IF NOT EXISTS
    internal.user_project_roles (
        user_id integer not null,
        project_id integer not null,
        primary key (user_id, project_id),
        foreign key (user_id) references auth.users (user_id) on delete restrict on update cascade,
        foreign key (project_id) references internal.projects (project_id) on delete restrict on update cascade,
        is_lead boolean not null
    );

CREATE TABLE IF NOT EXISTS
    internal.time_trackings (
        task_id serial primary key,
        description text,
        date date not null,
        duration interval not null,
        user_id integer not null,
        project_id integer not null,
        activity_id integer not null,
        aow_id integer not null,
        foreign key (user_id) references auth.users (user_id) on delete restrict on update cascade,
        foreign key (project_id) references internal.projects (project_id) on delete restrict on update cascade,
        foreign key (activity_id) references internal.activities (activity_id) on delete restrict on update cascade,
        foreign key (aow_id) references internal.areas_of_work (aow_id) on delete restrict on update cascade
    );

ALTER TABLE internal.time_trackings
ADD CONSTRAINT duration_check CHECK (
    EXTRACT(
        epoch
        FROM
            duration
    ) % (15 * 60) = 0
);

-- Create the internal.areas_of_expertise table to store information about areas
-- of expertise
CREATE TABLE IF NOT EXISTS
    internal.areas_of_expertise (
        aoe_id serial primary key,
        name text unique not null,
        description text
    );

-- Create the internal.aoe_hierarchies table to store information about the
-- hierarchy of teams within each area of expertise
CREATE TABLE IF NOT EXISTS
    internal.aoe_hierarchies (
        aoe_id integer not null,
        lead_id integer not null,
        member_id integer not null,
        primary key (aoe_id, lead_id, member_id),
        foreign key (aoe_id) references internal.areas_of_expertise (aoe_id) on delete restrict on update cascade,
        foreign key (lead_id) references auth.users (user_id) on delete restrict on update cascade,
        foreign key (member_id) references auth.users (user_id) on delete restrict on update cascade
    );

-- Create a trigger function to check that a member cannot belong to multiple
-- teams within the same area of expertise before allowing an insert or update
-- operation on the internal.aoe_hierarchies table
CREATE
OR REPLACE FUNCTION internal.check_unique_member_per_aoe () RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM internal.aoe_hierarchies WHERE aoe_id = NEW.aoe_id AND member_id = NEW.member_id AND lead_id <> NEW.lead_id) THEN
        RAISE EXCEPTION 'A member cannot belong to multiple teams within the same area of expertise';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to execute the check_unique_member_per_aoe function before
-- insert or update operations on the internal.aoe_hierarchies table
CREATE TRIGGER check_unique_member_per_aoe BEFORE INSERT
OR
UPDATE ON internal.aoe_hierarchies FOR EACH ROW
EXECUTE FUNCTION internal.check_unique_member_per_aoe ();
