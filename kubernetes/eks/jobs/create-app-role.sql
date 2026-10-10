\getenv app_password APP_PASSWORD

-- Create the application role only if missing.
SELECT format(
    'CREATE ROLE %I LOGIN PASSWORD %L',
    'opsflow_app',
    :'app_password'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = 'opsflow_app'
)
\gexec

-- Synchronize the database password with the Kubernetes Secret.
SELECT format(
    'ALTER ROLE %I WITH LOGIN PASSWORD %L',
    'opsflow_app',
    :'app_password'
)
\gexec

GRANT CONNECT ON DATABASE opsflow TO opsflow_app;
GRANT USAGE, CREATE ON SCHEMA public TO opsflow_app;