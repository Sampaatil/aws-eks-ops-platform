\getenv app_password APP_PASSWORD
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', 'opsflow_app', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'opsflow_app')
\gexec
GRANT CONNECT ON DATABASE opsflow TO opsflow_app;
GRANT USAGE, CREATE ON SCHEMA public TO opsflow_app;
