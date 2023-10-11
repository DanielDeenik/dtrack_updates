CREATE OR REPLACE VIEW
    api.employees
WITH
    (security_invoker = on) AS
SELECT
    user_id as id,
    username,
    email,
    to_jsonb(roles) as roles,
    'power' = ANY (roles) as is_power,
    first_name,
    last_name,
    position,
    member_of_projects,
    COALESCE(member_of_project_ids, '[]'::jsonb) as member_of_project_ids,
    lead_of_projects,
    COALESCE(lead_of_project_ids, '[]'::jsonb) as lead_of_project_ids,
    COALESCE(member_of_teams, '[]'::jsonb) as member_of_teams,
    COALESCE(member_of_team_ids, '[]'::jsonb) as member_of_team_ids,
    COALESCE(lead_of_teams, '[]'::jsonb) as lead_of_teams,
    COALESCE(lead_of_team_ids, '[]'::jsonb) as lead_of_team_ids
FROM
    auth.users
    LEFT JOIN (
        SELECT
            user_id,
            jsonb_agg(
                jsonb_build_object('id', project_id, 'name', name)
            ) FILTER (
                WHERE
                    is_lead is FALSE
            ) as member_of_projects,
            jsonb_agg(
                jsonb_build_object('id', project_id, 'name', name)
            ) FILTER (
                WHERE
                    is_lead is TRUE
            ) as lead_of_projects,
            jsonb_agg(project_id) FILTER (
                WHERE
                    is_lead is FALSE
            ) as member_of_project_ids,
            jsonb_agg(project_id) FILTER (
                WHERE
                    is_lead is TRUE
            ) as lead_of_project_ids
        FROM
            internal.user_project_roles
            JOIN internal.projects USING (project_id)
        GROUP BY
            user_id
    ) AS user_project_roles_agg USING (user_id)
    LEFT JOIN (
        SELECT
            user_email as email,
            user_roles as roles
        FROM
            auth.get_user_roles ()
    ) AS roles_query USING (email)
    LEFT JOIN (
        SELECT
            lead_id as user_id,
            jsonb_agg(
                DISTINCT jsonb_build_object(
                    'id',
                    LPAD(aoe_id::text, 4, '0') || LPAD(lead_id::text, 4, '0'),
                    'name',
                    aoe.name
                )
            ) as lead_of_teams,
            jsonb_agg(
                DISTINCT LPAD(aoe_id::text, 4, '0') || LPAD(lead_id::text, 4, '0')
            ) as lead_of_team_ids
        FROM
            internal.aoe_hierarchies
            LEFT JOIN internal.areas_of_expertise AS aoe USING (aoe_id)
        GROUP BY
            lead_id
    ) AS lead_team_roles_agg USING (user_id)
    LEFT JOIN (
        SELECT
            member_id as user_id,
            jsonb_agg(
                jsonb_build_object(
                    'id',
                    LPAD(aoe_id::text, 4, '0') || LPAD(lead_id::text, 4, '0'),
                    'name',
                    aoe.name || ' (' || lead.username || ')'
                )
            ) as member_of_teams,
            jsonb_agg(
                LPAD(aoe_id::text, 4, '0') || LPAD(lead_id::text, 4, '0')
            ) as member_of_team_ids
        FROM
            internal.aoe_hierarchies
            LEFT JOIN internal.areas_of_expertise AS aoe USING (aoe_id)
            LEFT JOIN auth.users AS lead ON internal.aoe_hierarchies.lead_id = lead.user_id
        WHERE
            member_id != lead_id
        GROUP BY
            member_id
    ) AS member_team_roles_agg USING (user_id)
WHERE
    email ILIKE '%@%';

CREATE OR REPLACE VIEW
    api.current_employee
WITH
    (security_invoker = on) AS
SELECT
    *
FROM
    api.employees
WHERE
    email = CURRENT_USER;

CREATE OR REPLACE VIEW
    -- RLS is bypassed because view is executed as role of view definer
    api.all_employees AS
SELECT
    id,
    username
FROM
    api.employees;

REVOKE
SELECT
    ON api.all_employees
FROM
    basic;

GRANT
SELECT
    ON api.all_employees TO pm;

GRANT
SELECT
    ON api.all_employees TO lead;

CREATE OR REPLACE VIEW
    api.activities
WITH
    (security_invoker = on) AS
SELECT
    activities.activity_id as id,
    activities.name,
    activities.description,
    jsonb_agg(
        jsonb_build_object('id', projects.project_id, 'name', projects.name)
    ) FILTER (
        WHERE
            projects.project_id IS NOT NULL
    ) AS projects,
    COALESCE(
        jsonb_agg(projects.project_id) FILTER (
            WHERE
                projects.project_id IS NOT NULL
        ),
        '[]'::jsonb
    ) as project_ids
FROM
    internal.activities AS activities
    LEFT JOIN internal.project_activities USING (activity_id)
    LEFT JOIN internal.projects AS projects USING (project_id)
GROUP BY
    activities.activity_id;

CREATE OR REPLACE VIEW
    api.areas_of_work
WITH
    (security_invoker = on) AS
SELECT
    aow.aow_id as id,
    aow.name,
    jsonb_agg(
        jsonb_build_object('id', projects.project_id, 'name', projects.name)
    ) FILTER (
        WHERE
            projects.project_id IS NOT NULL
    ) AS projects,
    COALESCE(
        jsonb_agg(projects.project_id) FILTER (
            WHERE
                projects.project_id IS NOT NULL
        ),
        '[]'::jsonb
    ) as project_ids
FROM
    internal.areas_of_work AS aow
    LEFT JOIN internal.project_areas_of_work USING (aow_id)
    LEFT JOIN internal.projects AS projects USING (project_id)
GROUP BY
    aow.aow_id;

CREATE OR REPLACE VIEW
    api.projects
WITH
    (security_invoker = on) AS
SELECT
    projects.project_id as id,
    leads,
    COALESCE(lead_ids, '[]'::jsonb) as lead_ids,
    members,
    COALESCE(member_ids, '[]'::jsonb) as member_ids,
    projects.name,
    projects.description,
    projects.start_date,
    projects.end_date,
    activities,
    COALESCE(activity_ids, '[]'::jsonb) as activity_ids,
    areas_of_work,
    COALESCE(aow_ids, '[]'::jsonb) as aow_ids
FROM
    internal.projects as projects
    LEFT JOIN (
        SELECT
            project_id,
            jsonb_agg(
                jsonb_build_object('id', user_id, 'name', username)
            ) FILTER (
                WHERE
                    is_lead is TRUE
            ) as leads,
            jsonb_agg(user_id) FILTER (
                WHERE
                    is_lead is TRUE
            ) as lead_ids,
            jsonb_agg(
                jsonb_build_object('id', user_id, 'name', username)
            ) FILTER (
                WHERE
                    is_lead is FALSE
            ) as members,
            jsonb_agg(user_id) FILTER (
                WHERE
                    is_lead is FALSE
            ) as member_ids
        FROM
            internal.user_project_roles
            JOIN auth.users USING (user_id)
        GROUP BY
            project_id
    ) AS user_project_roles_agg USING (project_id)
    LEFT JOIN (
        SELECT
            project_id,
            jsonb_agg(
                jsonb_build_object('id', activity_id, 'name', name)
            ) as activities,
            jsonb_agg(activity_id) as activity_ids
        FROM
            internal.project_activities
            JOIN internal.activities USING (activity_id)
        GROUP BY
            project_id
    ) AS project_activities_agg USING (project_id)
    LEFT JOIN (
        SELECT
            project_id,
            jsonb_agg(jsonb_build_object('id', aow_id, 'name', name)) as areas_of_work,
            jsonb_agg(aow_id) as aow_ids
        FROM
            internal.project_areas_of_work
            JOIN internal.areas_of_work USING (aow_id)
        GROUP BY
            project_id
    ) AS project_aow_agg USING (project_id);

-- Create the internal.aoe_teams view to calculate team hierarchies based on
-- data in the internal.aoe_hierarchies table
CREATE OR REPLACE VIEW
    internal.aoe_teams
WITH
    (security_invoker = on) AS
SELECT
    aoe1.aoe_id,
    CASE
        WHEN aoe1.lead_id IN (
            SELECT
                member_id
            FROM
                internal.aoe_hierarchies
            WHERE
                aoe_id = aoe1.aoe_id
        ) THEN (
            SELECT
                lead_id
            FROM
                internal.aoe_hierarchies
            WHERE
                member_id = aoe1.lead_id
                AND aoe_id = aoe1.aoe_id
        )
        ELSE aoe1.lead_id
    END AS supervisor_id,
    aoe1.lead_id,
    array_agg(DISTINCT aoe2.member_id) FILTER (
        WHERE
            aoe2.member_id IS NOT NULL
            AND aoe2.member_id <> aoe2.lead_id
    ) as member_ids
FROM
    internal.aoe_hierarchies aoe1
    LEFT JOIN internal.aoe_hierarchies aoe2 ON aoe1.aoe_id = aoe2.aoe_id
    AND aoe1.lead_id = aoe2.lead_id
GROUP BY
    aoe1.aoe_id,
    aoe1.lead_id;

-- Create the api.aoe_teams view to expose information about team hierarchies
-- within areas of expertise to API users
CREATE OR REPLACE VIEW
    api.aoe_teams
WITH
    (security_invoker = on) AS
SELECT
    lpad((aoe ->> 'id')::text, 4, '0') || lpad((lead ->> 'id')::text, 4, '0') AS id,
    CASE
        WHEN (
            select
                roles
            from
                api.current_employee
        ) @> '["power"]'::jsonb THEN (aoe ->> 'name')::text || ' (' || (lead ->> 'name')::text || ')'
        ELSE (aoe ->> 'name')::text
    END as name,
    aoe,
    supervisor,
    lead,
    members,
    COALESCE(member_ids, '[]'::jsonb) as member_ids
FROM
    (
        SELECT
            (
                SELECT
                    jsonb_build_object('id', aoe_id, 'name', name)
                FROM
                    internal.areas_of_expertise
                WHERE
                    internal.aoe_teams.aoe_id = internal.areas_of_expertise.aoe_id
            ) AS aoe,
            (
                SELECT
                    jsonb_build_object('id', user_id, 'name', username)
                FROM
                    auth.users
                WHERE
                    internal.aoe_teams.supervisor_id = auth.users.user_id
            ) AS supervisor,
            (
                SELECT
                    jsonb_build_object('id', user_id, 'name', username)
                FROM
                    auth.users
                WHERE
                    internal.aoe_teams.lead_id = auth.users.user_id
            ) AS lead,
            (
                SELECT
                    jsonb_agg(
                        jsonb_build_object('id', user_id, 'name', username)
                    )
                FROM
                    auth.users
                WHERE
                    user_id = ANY (internal.aoe_teams.member_ids)
            ) AS members,
            to_jsonb(member_ids) as member_ids
        FROM
            internal.aoe_teams
    ) aoe_teams;

-- Create the api.areas_of_expertise view to expose information about areas of
-- expertise to API users
CREATE OR REPLACE VIEW
    api.areas_of_expertise
WITH
    (security_invoker = on) AS
WITH
    supervisors_cte AS (
        SELECT
            (aoe ->> 'id')::integer AS aoe_id,
            jsonb_agg(lead) AS supervisors,
            jsonb_agg(DISTINCT (lead ->> 'id')::integer) as supervisor_ids
        FROM
            api.aoe_teams
        WHERE
            supervisor = lead
        GROUP BY
            aoe_id
    )
SELECT
    internal.areas_of_expertise.aoe_id AS id,
    name,
    description,
    supervisors_cte.supervisors,
    COALESCE(supervisors_cte.supervisor_ids, '[]'::jsonb) as supervisor_ids
FROM
    internal.areas_of_expertise
    LEFT JOIN supervisors_cte ON internal.areas_of_expertise.aoe_id = supervisors_cte.aoe_id;

CREATE OR REPLACE VIEW
    api.time_trackings
WITH
    (security_invoker = on) AS
WITH
    teams_cte AS (
        SELECT
            aoe_hierarchies.member_id,
            aoe_hierarchies.lead_id,
            jsonb_agg(
                -- TODO: This is repeated from api.aoe_teams view, try make more DRY
                lpad((aoe_hierarchies.aoe_id)::text, 4, '0') || lpad((aoe_hierarchies.lead_id)::text, 4, '0')
            ) AS aoe_team_ids
        FROM
            internal.aoe_hierarchies AS aoe_hierarchies
        GROUP BY
            aoe_hierarchies.member_id,
            aoe_hierarchies.lead_id
    ),
    teams_union_cte AS (
        SELECT
            user_id,
            jsonb_agg(DISTINCT aoe_team_id) AS aoe_team_ids
        FROM
            (
                SELECT
                    teams_cte.member_id AS user_id,
                    jsonb_array_elements(teams_cte.aoe_team_ids) AS aoe_team_id
                FROM
                    teams_cte
                UNION ALL
                SELECT
                    teams_cte.lead_id AS user_id,
                    jsonb_array_elements(teams_cte.aoe_team_ids) AS aoe_team_id
                FROM
                    teams_cte
                WHERE
                    (
                        SELECT
                            roles
                        FROM
                            api.current_employee
                    ) @> '["power"]'::jsonb
            ) subq
        GROUP BY
            user_id
    ),
    time_trackings_cte AS (
        SELECT
            time_trackings.task_id as id,
            time_trackings.description,
            time_trackings.date,
            to_char(
                round(
                    (
                        extract(
                            epoch
                            FROM
                                time_trackings.duration
                        ) / 3600
                    )::numeric,
                    2
                ),
                'FM999999990.00'
            ) || ' hrs' as duration,
            jsonb_build_object('id', users.user_id, 'name', users.username) AS user,
            jsonb_build_object('id', projects.project_id, 'name', projects.name) AS project,
            jsonb_build_object(
                'id',
                activities.activity_id,
                'name',
                activities.name
            ) AS activity,
            jsonb_build_object('id', aows.aow_id, 'name', aows.name) AS aow,
            teams_union_cte.aoe_team_ids
        FROM
            internal.time_trackings AS time_trackings
            LEFT JOIN auth.users AS users USING (user_id)
            LEFT JOIN internal.projects AS projects USING (project_id)
            LEFT JOIN internal.activities AS activities USING (activity_id)
            LEFT JOIN internal.areas_of_work AS aows USING (aow_id)
            LEFT JOIN teams_union_cte USING (user_id)
    )
SELECT
    *
FROM
    time_trackings_cte;
