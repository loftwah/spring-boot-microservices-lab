# linkarooie-api

Spring Boot REST API for Linkarooie.

## Owns

- Authentication and sessions.
- Users.
- Organisations and memberships.
- Profile CRUD.
- Public profile reads.
- Directory reads.
- Social links, links, achievements, tags, and related work.
- Media metadata and upload endpoints.
- Stable public media URLs.
- Analytics event ingestion and redirect tracking.
- Internal media completion endpoints used by `linkarooie-media-worker`.

## Depends On

- Postgres for source-of-truth data.
- Redis for sessions, public read cache, rate limits, and hot counters.
- Kafka for analytics and media events.
- RustFS/S3 for profile media.
- Seed image assets in `services/linkarooie-api/seed/assets/`.

## First Useful Build

1. Add a Spring Boot application class.
2. Add `/api/health`.
3. Add `/api/ready`.
4. Connect to Postgres and run Flyway.
5. Return `ProblemDetail` errors.

That is enough to prove the service can run before auth and profile work starts.

## Verification

```bash
cd services/linkarooie-api
./gradlew test
./gradlew bootRun
curl -i http://localhost:8080/api/health
curl -i http://localhost:8080/api/ready
```

## Testing Expectations

- Controller tests for request/response shape.
- Application service unit tests for each command.
- Integration tests for repository and Flyway behaviour.
- Component tests for auth, profile, content, media, and analytics flows.
- Black-box tests through HTTP for signup, profile creation, public reads, media upload, and tracked redirects.
