# Postgres Runbook

Postgres is the lab's relational database. Treat it like a local stand-in for RDS.

## Connection Details

```text
host: localhost
port: 5432
database: app
username: app
password: app
```

From k3d pods:

```text
host: host.k3d.internal
port: 5432
```

## Connect With psql

```bash
docker exec -it postgres psql -U app -d app
```

Useful psql commands:

```sql
\l
\du
\dt
\dn
\d table_name
\conninfo
\q
```

## Connect With DBeaver

Create a new PostgreSQL connection:

```text
Host: localhost
Port: 5432
Database: app
Username: app
Password: app
```

If DBeaver asks for the driver, allow it to download the PostgreSQL driver.

## Create A User And Database

Connect as the `app` user:

```bash
docker exec -it postgres psql -U app -d app
```

Create a lab user and database:

```sql
CREATE USER document_app WITH PASSWORD 'document_app';
CREATE DATABASE document_app OWNER document_app;
GRANT ALL PRIVILEGES ON DATABASE document_app TO document_app;
```

Connect to the new database:

```bash
docker exec -it postgres psql -U document_app -d document_app
```

## Basic CRUD Drill

```sql
CREATE TABLE documents (
  id UUID PRIMARY KEY,
  title TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO documents (id, title, status)
VALUES (gen_random_uuid(), 'hello-postgres', 'DRAFT');

SELECT * FROM documents;

UPDATE documents
SET status = 'READY'
WHERE title = 'hello-postgres';

DELETE FROM documents
WHERE title = 'hello-postgres';
```

If `gen_random_uuid()` is unavailable:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

## Backups And Restore

Dump one database:

```bash
docker exec postgres pg_dump -U app app > app.sql
```

Restore:

```bash
docker exec -i postgres psql -U app -d app < app.sql
```

## Inspect Activity

```sql
SELECT pid, usename, datname, state, query
FROM pg_stat_activity
ORDER BY query_start DESC;
```

Database sizes:

```sql
SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database;
```

## What The Microservices Should Use

- Flyway migrations for schema changes.
- One schema or database owner per service if you want clean boundaries.
- Connection pool via HikariCP.
- Readiness checks that fail when DB connectivity fails.

## Things To Break And Fix

1. Stop Postgres and watch app readiness fail.
2. Create a bad password and confirm connection errors.
3. Lock a row in one session and observe blocking from another session.
4. Run a migration twice and make sure it is idempotent through Flyway.

## Know As A DevOps Engineer

- Users vs databases vs schemas.
- Migrations and rollback strategy.
- Connection pooling.
- Backups, restore, and point-in-time recovery concepts.
- Read replicas and failover concepts.
- Disk usage, slow queries, locks, and connection exhaustion.
