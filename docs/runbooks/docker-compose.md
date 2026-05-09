# Docker Compose Runbook

Docker Compose runs the standalone backing services for this lab: Postgres, Redis, Kafka, RustFS, Vault, and Jenkins.

Jenkins is deliberately here, not in k3d. Treat it as a centralized CI/CD controller outside the application cluster, similar to a shared Jenkins service in a tooling account.

## What To Know

- Compose is acting like the local managed-service layer.
- Jenkins in Compose acts like external shared CI/CD, not an app workload.
- Containers are disposable.
- Named volumes hold persistent data.
- `docker compose down` removes containers and the network, but keeps volumes.
- `docker compose down -v` deletes volumes and data.

## Start And Verify

From the repo root:

```bash
docker compose up -d
docker compose ps
./verify-supporting-services.sh
```

## Stop Without Losing Data

```bash
docker compose down
```

## Clean Slate

Use this only when you intentionally want to reset all local data:

```bash
docker compose down -v
```

## Inspect Services

```bash
docker compose ps
docker compose logs postgres
docker compose logs redis
docker compose logs kafka
docker compose logs rustfs
docker compose logs vault
docker compose logs jenkins
```

Follow logs:

```bash
docker compose logs -f kafka
```

## Inspect Containers, Networks, Volumes

```bash
docker ps
docker inspect postgres
docker network ls
docker network inspect enterprise-lab_default
docker volume ls
docker volume inspect enterprise-lab_postgres_data
```

## Common DevOps Tasks

- Check health status with `docker compose ps`.
- Read logs for failing service startup.
- Confirm ports are not already used.
- Recreate one service after config changes:

```bash
docker compose up -d --force-recreate vault
```

- Restart one service:

```bash
docker compose restart kafka
```

## Things To Break And Fix

1. Stop Redis and watch the verifier fail:

```bash
docker compose stop redis
./verify-supporting-services.sh
docker compose start redis
```

2. Restart Kafka and list topics again.
3. Run `docker compose down`, then `up -d`, and confirm persisted data remains.

## Know As A DevOps Engineer

- Difference between image, container, volume, network, and port mapping.
- Difference between container health and application readiness.
- Why named volumes matter.
- How container DNS works inside a Compose network.
- Why host clients use `localhost`, while containers use service names like `kafka`.
