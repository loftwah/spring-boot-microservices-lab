# Spring Boot Microservices Lab

This repo is a build plan for rebuilding Linkarooie as a set of application services, with local supporting services that simulate managed platform dependencies.

The point of the lab is to learn the full application and platform loop without pretending every backing service belongs inside Kubernetes.

## The Path

1. Run supporting services locally with Docker Compose.
2. Build Linkarooie application workloads locally against those services.
3. Prove behaviour with unit, integration, component, and black-box tests.
4. Build container images.
5. Publish images to GitHub Container Registry.
6. Deploy only the application workloads into k3d.
7. Add CI/CD and observability after the application works.

Yes, it makes sense to build the application locally first. That is the right first move.

## Current Supporting Stack

This Docker Compose stack is complete for standalone backing services. Treat it like the local version of managed platform services:

```text
Postgres -> RDS-like relational database
Redis    -> ElastiCache-like cache and session store
Kafka    -> MSK-like event streaming
RustFS   -> S3-like object storage
Vault    -> secrets/encryption lab dependency, excluded from Linkarooie V1 app scope
Jenkins  -> centralized CI/CD control plane, excluded from Linkarooie V1 app scope
```

Start the backing services:

```bash
cd supporting-services
docker compose up -d
./verify-supporting-services.sh
```

From the repo root, run the local doctor:

```bash
./scripts/doctor.sh
```

## Supporting Service Endpoints

| Service | Local URL / Port | k3d Pod Address | Purpose |
| --- | --- | --- | --- |
| Postgres | `localhost:5432` | `host.k3d.internal:5432` | Source-of-truth database |
| Redis | `localhost:6379` | `host.k3d.internal:6379` | Sessions, cache, rate limits, hot counters |
| Kafka | `localhost:9092` | `host.k3d.internal:9094` | Analytics and media events |
| RustFS | `http://localhost:9000` | `http://host.k3d.internal:9000` | S3-compatible media storage |
| RustFS Console | `http://localhost:9001` | n/a | Object storage GUI |
| Vault | `http://localhost:8200` | `http://host.k3d.internal:8200` | Platform lab dependency |
| Jenkins | `http://localhost:8080` | n/a | Platform lab dependency |

Development credentials:

| Service | Username / Token | Password |
| --- | --- | --- |
| Postgres | `app` | `app` |
| RustFS | `rustfsadmin` | `rustfsadmin` |
| Vault | `root` | token auth |
| Jenkins | created during setup | created during setup |

## Application Workloads

| Directory | Workload | Runtime | Purpose |
| --- | --- | --- | --- |
| `services/linkarooie-api` | `linkarooie-api` | Java 21 / Spring Boot | REST API, auth, profiles, content, media metadata, public reads, analytics ingestion |
| `services/linkarooie-analytics-worker` | `linkarooie-analytics-worker` | Java 21 / Spring Boot | Kafka consumer for analytics storage, aggregates, and Redis hot counters |
| `services/linkarooie-web` | `linkarooie-web` | React / TanStack / Vite | Public app and dashboard |
| `services/linkarooie-media-worker` | `linkarooie-media-worker` | Node.js LTS in containers, Bun locally | Kafka worker for image variants and generated Open Graph media |

Each service should be self-contained. Do not add a shared code folder for V1.

## What k3d Runs

k3d runs application workloads only:

- `linkarooie-api`
- `linkarooie-analytics-worker`
- `linkarooie-web`
- `linkarooie-media-worker` after generated media is added

k3d does not run:

- Postgres
- Redis
- Kafka
- RustFS
- Vault
- Jenkins

Those remain Docker Compose services. This mirrors a production pattern where Kubernetes runs your app and managed services run outside the cluster.

## Build Documentation

Start here:

- [Application spec](linkarooie-spec.md)
- [Implementation plan](docs/implementation-plan.md)
- [Story index](docs/stories/README.md)
- [Runbook index](docs/runbooks/README.md)
- [Linear local runbook](docs/runme.md)

## Useful Commands

Verify the documentation scaffold:

```bash
./scripts/verify-repo-layout.sh
```

Start and verify supporting services:

```bash
cd supporting-services
./verify-supporting-services.sh
```

Create Linkarooie Kafka topics:

```bash
./supporting-services/scripts/create-linkarooie-topics.sh
```

Prepare Linkarooie supporting-service state, including topics and the RustFS bucket:

```bash
./supporting-services/scripts/prepare-linkarooie-supporting-services.sh
```

Run the local doctor:

```bash
./scripts/doctor.sh
```

Stop supporting services without deleting data:

```bash
cd supporting-services
docker compose down
```

Only wipe data when you intentionally want a clean slate:

```bash
cd supporting-services
docker compose down -v
```
