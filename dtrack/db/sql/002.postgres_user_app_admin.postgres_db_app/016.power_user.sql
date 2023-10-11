-- TODO: Work out how to manage initial power user, so it does not clash with database restore
-- It should be either this for a new system, or a restore of existing system
SELECT
    auth.create_user ('$POSTGRES_USER_APP_POWER');

SELECT
    auth.grant_power ('$POSTGRES_USER_APP_POWER');
