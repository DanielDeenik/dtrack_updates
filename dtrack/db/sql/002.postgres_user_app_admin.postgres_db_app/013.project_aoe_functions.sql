-- Note: Don't include in other functions, especially where security   definer
CREATE
OR REPLACE FUNCTION auth.get_current_user_id () RETURNS integer LANGUAGE sql AS $$
    SELECT user_id FROM auth.users WHERE email = current_user;
$$;

GRANT
EXECUTE ON FUNCTION auth.get_current_user_id () TO basic;

-- The auth.is_project_member function takes in a user_id, project_id, and an optional is_lead parameter.
-- It returns a boolean value indicating whether the specified user is either a regular member or lead member of the specified project.
-- If the is_lead parameter is provided as true, the function will only return true if the user is a lead member.
-- Id the is_lead parameter is provided as false, the function will only return true if the user is a regular member.
-- The function constructs and executes a dynamic query to check for the existence of a row in the internal.user_project_roles table matching the provided parameters.
CREATE
OR REPLACE FUNCTION auth.is_project_member (
    user_id integer,
    project_id integer,
    is_lead boolean default null
) RETURNS boolean LANGUAGE plpgsql SECURITY definer AS $$
DECLARE
    query text;
    result boolean;
BEGIN
    query := 'SELECT 1 FROM internal.user_project_roles WHERE user_id = $1 AND project_id::integer = $2';
    IF is_lead IS NOT NULL THEN
        query := query || ' AND is_lead = $3';
    END IF;
    query := 'SELECT EXISTS (' || query || ')';
    EXECUTE query INTO result USING user_id, project_id::integer, is_lead;
    RETURN result;
END;
$$;

GRANT
EXECUTE ON FUNCTION auth.is_project_member (
    user_id integer,
    project_id integer,
    is_lead boolean
) TO basic;

-- Note: Can now get this information if 'pm' is part of auth.users.roles
CREATE
OR REPLACE FUNCTION auth.is_manager (p_user_id integer) RETURNS boolean LANGUAGE sql SECURITY definer AS $$
    SELECT EXISTS (
        SELECT 1
        FROM internal.user_project_roles as upr
        WHERE upr.user_id = p_user_id AND upr.is_lead = true
    );
$$;

GRANT
EXECUTE ON FUNCTION auth.is_manager (p_user_id integer) TO basic;

-- This function checks if a given user is a supervisor.
-- It returns true if the user is a supervisor and false otherwise.
-- A user is considered a supervisor if their ID appears in the lead_id column
-- of the internal.aoe_teams table where the supervisor_id column is equal to the lead_id column.
-- Note this IS a priveleged function, SECURITY   definer
CREATE
OR REPLACE FUNCTION auth.is_supervisor (given_user_id integer) RETURNS boolean LANGUAGE sql SECURITY definer AS $$
    SELECT EXISTS (
        SELECT 1
        FROM internal.aoe_teams
        WHERE supervisor_id = lead_id
        AND lead_id = given_user_id
    );
$$;

GRANT
EXECUTE ON FUNCTION auth.is_supervisor (given_user_id integer) TO basic;

-- This function checks if the first given user id (lead) is a lead of second given user id (member).
-- It returns true if the first user is a lead of the second and false otherwise.
CREATE
OR REPLACE FUNCTION auth.is_lead_of (given_lead_id integer, given_member_id integer) RETURNS boolean LANGUAGE sql SECURITY definer AS $$
    SELECT EXISTS (
        SELECT 1
        FROM internal.aoe_hierarchies
        WHERE lead_id = given_lead_id
        AND member_id = given_member_id
    );
$$;

GRANT
EXECUTE ON FUNCTION auth.is_lead_of (given_lead_id integer, given_member_id integer) TO basic;

-- This function checks if the first given user id (pm) is a pm of second given user id (member).
-- It returns true if the first user is a pm of the second and false otherwise.
-- Note that there can be multiple pms of a project, this also answers true in
-- the case that the second given user id is on the same pm team as the first
-- TODO: Review the usage here, does the fact that the function is true for pm colleagues have impact?
CREATE
OR REPLACE FUNCTION auth.is_pm_of (given_pm_id integer, given_member_id integer) RETURNS boolean LANGUAGE sql SECURITY definer AS $$
  SELECT bool_or(is_lead)
  FROM internal.user_project_roles
  WHERE user_id = given_pm_id AND project_id IN (
    SELECT project_id
    FROM internal.user_project_roles
    WHERE user_id = given_member_id
  )
$$;

GRANT
EXECUTE ON FUNCTION auth.is_pm_of (given_pm_id integer, given_member_id integer) TO basic;

CREATE
OR REPLACE FUNCTION auth.is_supervisor_of_aoe (given_aoe_id integer, given_lead_id integer) RETURNS bool LANGUAGE sql SECURITY definer AS $$
    SELECT EXISTS (
        SELECT 1
        FROM internal.aoe_teams
        WHERE aoe_id = given_aoe_id
        AND lead_id = given_lead_id
        AND supervisor_id = lead_id
    );
$$;

GRANT
EXECUTE ON FUNCTION auth.is_supervisor_of_aoe (integer, integer) TO basic;

CREATE
OR REPLACE FUNCTION internal.aoe_teams_grant_or_revoke_privs (given_lead_id integer) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    user_email text;
BEGIN
    SELECT email INTO user_email FROM auth.users WHERE user_id = given_lead_id;
    IF auth.is_supervisor(given_lead_id) THEN
        IF NOT pg_has_role(user_email, 'lead', 'MEMBER') THEN
            PERFORM auth.grant_priv(
                user_email,
                'lead'
            );
        END IF;
    ELSE
        IF pg_has_role(user_email, 'lead', 'MEMBER') THEN
            PERFORM auth.revoke_priv(
                user_email,
                'lead'
            );
        END IF;
    END IF;
END;
$$;

-- TODO: This is potentially insecure, fix
GRANT
EXECUTE ON FUNCTION internal.aoe_teams_grant_or_revoke_privs (integer) TO basic;
