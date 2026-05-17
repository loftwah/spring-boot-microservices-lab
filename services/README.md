# Services

Each deployable application workload gets one directory here.

```text
services/
  linkarooie-api/
  linkarooie-analytics-worker/
  linkarooie-media-worker/
  linkarooie-web/
```

This is intentionally service-first. A human working through the lab should be able to pick a service directory, build it, run it, containerize it, and later publish it.

## Service Boundaries

| Directory | Deploys As | Runtime | Purpose |
| --- | --- | --- | --- |
| `linkarooie-api` | `linkarooie-api` | Java 21 / Spring Boot | Auth, profiles, content, media metadata, public reads, analytics ingestion |
| `linkarooie-analytics-worker` | `linkarooie-analytics-worker` | Java 21 / Spring Boot | Kafka analytics consumer, immutable event storage, aggregates, Redis hot counters |
| `linkarooie-media-worker` | `linkarooie-media-worker` | Node.js LTS in containers, Bun locally | Kafka media consumer, image variants, generated Open Graph images |
| `linkarooie-web` | `linkarooie-web` | React / TanStack / Vite | Public app and dashboard |

## Local Build Order

1. `linkarooie-api`
2. `linkarooie-analytics-worker`
3. `linkarooie-web`
4. `linkarooie-media-worker`

The media worker is server-side application infrastructure, but it gets its own service directory because it is a separate deployable with a different runtime and native image-processing dependencies.

## Rule

Keep each service self-contained:

- Its own build file.
- Its own tests.
- Its own Dockerfile.
- Its own service-specific seed/import scripts if it owns application data.

Do not create a shared code folder in V1. If two services need the same event shape, write down the JSON contract in docs and keep the implementation local until a real extraction need appears.
