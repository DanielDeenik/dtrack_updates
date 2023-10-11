--------------
-- PROJECTS --
--------------
-- Create row-level security policies for the projects table
ALTER TABLE internal.projects ENABLE ROW LEVEL SECURITY;

-- Only power users can delete projects
REVOKE DELETE ON internal.projects
FROM
    PUBLIC;

GRANT DELETE ON internal.projects TO power;

-- Current user can select the projects they and the AoE teams they lead are members/pms of
CREATE POLICY select_projects_policy ON internal.projects USING (
    EXISTS (
        WITH
            lead_status_cte AS (
                SELECT
                    user_id,
                    auth.is_lead_of (auth.get_current_user_id (), user_id) AS current_user_is_lead
                FROM
                    auth.users
            )
        SELECT
            1
        FROM
            lead_status_cte
            JOIN internal.user_project_roles upr USING (user_id)
        WHERE
            (
                current_user_is_lead IS TRUE
                OR user_id = auth.get_current_user_id ()
            )
            AND upr.project_id = internal.projects.project_id
    )
);

-- Only PMs can do inserts (upserts) on their projects, only power users can do inserts on new projects
CREATE POLICY insert_leads_projects_policy ON internal.projects FOR INSERT
WITH
    CHECK (
        auth.is_project_member (
            auth.get_current_user_id (),
            project_id::integer,
            is_lead => true
        )
    );

-- Only PMs can do updates on their projects
CREATE POLICY update_leads_projects_policy ON internal.projects FOR
UPDATE USING (
    auth.is_project_member (
        auth.get_current_user_id (),
        project_id::integer,
        is_lead => true
    )
)
WITH
    CHECK (
        auth.is_project_member (
            auth.get_current_user_id (),
            project_id::integer,
            is_lead => true
        )
    );

-- Create row-level security policies for the user_project_roles table
ALTER TABLE internal.user_project_roles ENABLE ROW LEVEL SECURITY;

-- Updates aren't allowed (TODO: Check what happens when user is changed from manager to member and visa versa)
REVOKE
UPDATE ON internal.user_project_roles
FROM
    PUBLIC;

-- All members can select their user_project_roles (or those that they lead?)
-- Permissive for now
CREATE POLICY select_user_project_roles_policy ON internal.user_project_roles FOR
SELECT
    USING (
        -- auth.is_project_member (auth.get_current_user_id (), project_id::integer)
        true
    );

-- Only leads (is_lead=true) can insert/delete relationships that define project membership (i.e. if row includes is_lead=false)
CREATE POLICY insert_user_project_roles_policy ON internal.user_project_roles FOR INSERT
WITH
    CHECK (
        (is_lead is false)
        AND (
            auth.is_project_member (
                auth.get_current_user_id (),
                project_id::integer,
                is_lead => true
            )
        )
    );

CREATE POLICY delete_user_project_roles_policy ON internal.user_project_roles FOR DELETE USING (
    (is_lead is false)
    AND (
        auth.is_project_member (
            auth.get_current_user_id (),
            project_id::integer,
            is_lead => true
        )
    )
);

-----------
-- Users --
-----------
-- Enable Row Level Security on the users table
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

-- Create a policy that allows SELECT and UPDATE operations on the users table only for the current user
CREATE POLICY select_users_policy ON auth.users FOR
SELECT
    USING (
        email = current_user
        OR auth.is_lead_of (auth.get_current_user_id (), user_id)
        OR auth.is_pm_of (auth.get_current_user_id (), user_id)
        OR auth.is_lead_of (user_id, auth.get_current_user_id ())
        OR auth.is_pm_of (user_id, auth.get_current_user_id ())
    );

CREATE POLICY update_users_policy ON auth.users FOR
UPDATE
WITH
    CHECK (email = current_user);

----------
-- AOWs --
----------
-- Create row-level security policies for the project_areas_of_work table
ALTER TABLE internal.project_areas_of_work ENABLE ROW LEVEL SECURITY;

-- Updates aren't allowed
REVOKE
UPDATE ON internal.project_areas_of_work
FROM
    PUBLIC;

-- All members can select their project_areas_of_work
CREATE POLICY select_project_areas_of_work_policy ON internal.project_areas_of_work FOR
SELECT
    USING (
        auth.is_project_member (auth.get_current_user_id (), project_id::integer)
    );

-- Only leads (is_lead=true) can insert/delete relationships that define areas of work
CREATE POLICY insert_project_areas_of_work_policy ON internal.project_areas_of_work FOR INSERT
WITH
    CHECK (
        auth.is_project_member (
            auth.get_current_user_id (),
            project_id::integer,
            is_lead => true
        )
    );

CREATE POLICY delete_project_areas_of_work_policy ON internal.project_areas_of_work FOR DELETE USING (
    auth.is_project_member (
        auth.get_current_user_id (),
        project_id::integer,
        is_lead => true
    )
);

-- Only power users can insert/delete internal.areas_of_work
ALTER TABLE internal.areas_of_work ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_areas_of_work_policy ON internal.areas_of_work FOR
SELECT
    USING (true);

CREATE POLICY insert_areas_of_work_policy ON internal.areas_of_work FOR INSERT
WITH
    CHECK (pg_has_role('power', 'MEMBER'));

CREATE POLICY delete_areas_of_work_policy ON internal.areas_of_work FOR DELETE USING (pg_has_role('power', 'MEMBER'));

----------------
-- Activities --
----------------
-- Create row-level security policies for the project_activities table
ALTER TABLE internal.project_activities ENABLE ROW LEVEL SECURITY;

-- Updates aren't allowed
REVOKE
UPDATE ON internal.project_activities
FROM
    PUBLIC;

-- All members can select their project_activities
CREATE POLICY select_project_activities_policy ON internal.project_activities FOR
SELECT
    USING (
        auth.is_project_member (auth.get_current_user_id (), project_id::integer)
    );

-- Only leads (is_lead=true) can insert/delete relationships that define activities
CREATE POLICY insert_project_activities_policy ON internal.project_activities FOR INSERT
WITH
    CHECK (
        auth.is_project_member (
            auth.get_current_user_id (),
            project_id::integer,
            is_lead => true
        )
    );

CREATE POLICY delete_project_activities_policy ON internal.project_activities FOR DELETE USING (
    auth.is_project_member (
        auth.get_current_user_id (),
        project_id::integer,
        is_lead => true
    )
);

-- Only power users can insert/delete internal.activities
ALTER TABLE internal.activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_activities_policy ON internal.activities FOR
SELECT
    USING (true);

CREATE POLICY insert_activities_policy ON internal.activities FOR INSERT
WITH
    CHECK (pg_has_role('power', 'MEMBER'));

CREATE POLICY delete_activities_policy ON internal.activities FOR DELETE USING (pg_has_role('power', 'MEMBER'));

-------------------
-- Time Tracking --
-------------------
-- Enable row-level security on the internal.time_trackings table.
ALTER TABLE internal.time_trackings ENABLE ROW LEVEL SECURITY;

-- This is a row-level security policy for the internal.time_trackings table.
-- It allows users to see and modify rows where:
-- 1. The user_id column matches their own ID (as returned by the auth.get_current_user_id() function)
-- 2. They are a lead of the member whose ID is in the user_id column (as determined by calling the auth.is_lead_of() function)
CREATE POLICY time_trackings_policy ON internal.time_trackings USING (
    user_id = auth.get_current_user_id ()
    OR auth.is_lead_of (auth.get_current_user_id (), user_id)
)
WITH
    CHECK (
        user_id = auth.get_current_user_id ()
        OR auth.is_lead_of (auth.get_current_user_id (), user_id)
    );

-----------------
-- AoE / Teams --
-----------------
ALTER TABLE internal.areas_of_expertise ENABLE ROW LEVEL SECURITY;

CREATE POLICY aoe_policy ON internal.areas_of_expertise FOR
SELECT
    USING (
        EXISTS (
            SELECT
                1
            FROM
                internal.aoe_hierarchies
            WHERE
                internal.aoe_hierarchies.aoe_id = internal.areas_of_expertise.aoe_id
                AND (
                    internal.aoe_hierarchies.lead_id = auth.get_current_user_id ()
                    OR internal.aoe_hierarchies.member_id = auth.get_current_user_id ()
                )
        )
    );

ALTER TABLE internal.aoe_hierarchies ENABLE ROW LEVEL SECURITY;

REVOKE
UPDATE ON internal.aoe_hierarchies
FROM
    PUBLIC;

CREATE POLICY select_aoe_hierarchies_policy ON internal.aoe_hierarchies FOR
SELECT
    USING (
        lead_id = auth.get_current_user_id ()
        OR member_id = auth.get_current_user_id ()
    );

CREATE POLICY insert_aoe_hierarchies_policy ON internal.aoe_hierarchies FOR INSERT
WITH
    CHECK (lead_id = auth.get_current_user_id ());

CREATE POLICY delete_aoe_hierarchies_policy ON internal.aoe_hierarchies FOR DELETE USING (lead_id = auth.get_current_user_id ());
