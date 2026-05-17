# Linkarooie Implementation Plan

This repo is a lab for building Linkarooie as application workloads that run locally first, then as containers in k3d, while Postgres, Redis, Kafka, RustFS, Vault, and Jenkins remain supporting services.

The sensible order is:

1. Build the application services locally against Docker Compose supporting services.
2. Prove each service with unit, integration, component, and black-box tests.
3. Build container images and publish them to GitHub Container Registry.
4. Deploy only the Linkarooie application workloads into k3d.
5. Add CI/CD, observability, and harder platform concerns after the application behaviour is real.

## Application Workloads

| Directory | Workload | Runtime | Purpose |
| --- | --- | --- | --- |
| `services/linkarooie-api` | `linkarooie-api` | Java 21 / Spring Boot | REST API, auth, profiles, content, media metadata, public reads, analytics event ingestion |
| `services/linkarooie-analytics-worker` | `linkarooie-analytics-worker` | Java 21 / Spring Boot | Kafka consumer that stores analytics events, updates aggregates, and maintains Redis hot counters |
| `services/linkarooie-web` | `linkarooie-web` | React / TanStack / Vite | Public app, dashboard, profile editor, media editor, analytics screens |
| `services/linkarooie-media-worker` | `linkarooie-media-worker` | Node.js LTS for containers, Bun locally | Kafka consumer that generates image variants and Open Graph images with Puppeteer and Sharp |

## Service Rule

Each service is self-contained. If you open `services/linkarooie-api`, everything needed to build, test, seed, and containerize that service should be in that directory, apart from root docs and supporting-service setup.

Do not add a shared code folder for V1. A little duplication is acceptable in a learning lab because it keeps service boundaries visible. Extract shared code only later, after two services repeatedly need the same non-trivial code and the tradeoff is obvious.

## Local Runtime Modes

### Mode 1: Local Processes

Use this first while building behaviour.

```text
Spring Boot API          -> localhost:5432, localhost:6379, localhost:9092, localhost:9000
Analytics worker         -> localhost:5432, localhost:6379, localhost:9092
Media worker             -> localhost:9092, localhost:9000, API on localhost
Web dev server           -> API through local proxy
Supporting services      -> Docker Compose
```

### Mode 2: k3d App Workloads

Use this after local behaviour is proven.

```text
Linkarooie pods          -> host.k3d.internal:5432, :6379, :9094, :9000
Supporting services      -> Docker Compose on the host
Browser                  -> k3d ingress/load balancer
```

Postgres, Redis, Kafka, RustFS, Vault, and Jenkins stay outside k3d. They represent managed services or shared tooling.

## Definition Of Done For A Story

Every story should leave the repo in a state that can be verified.

Minimum bar:

- There is a runnable command.
- Tests prove the main behaviour.
- A human can see the new capability through HTTP, Kafka, a database row, Redis key, generated media, or a browser screen.
- The docs say how to build it, why it exists, and how to verify it.
- The change does not require jumping ahead to later platform work.

## Main Story Index

Follow the stories in order:

1. [API Foundation](stories/01-api-foundation.md)
2. [Auth And Workspaces](stories/02-auth-and-workspaces.md)
3. [Profiles And Public Reads](stories/03-profiles-and-public-reads.md)
4. [Profile Content](stories/04-profile-content.md)
5. [Media Uploads](stories/05-media-uploads.md)
6. [Analytics Pipeline](stories/06-analytics-pipeline.md)
7. [Linkarooie Web Public App](stories/07-linkarooie-web-public.md)
8. [Linkarooie Web Dashboard](stories/08-linkarooie-web-dashboard.md)
9. [Containers And k3d](stories/09-containers-and-k3d.md)
10. [Linkarooie Media Worker](stories/10-linkarooie-media-worker.md)

## Verification Scripts

Run these from the repo root:

```bash
./scripts/verify-repo-layout.sh
./scripts/doctor.sh
./supporting-services/scripts/prepare-linkarooie-supporting-services.sh
```

`doctor.sh` checks local tooling and supporting-service reachability. It is intentionally separate from implementation tests so you can quickly distinguish platform setup problems from application bugs.
