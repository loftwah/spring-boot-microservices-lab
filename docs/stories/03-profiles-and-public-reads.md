# Story 3: Profiles And Public Reads

## Goal

Add profile ownership, username reservation, profile CRUD, public profile reads, directory reads, Redis caching, and the first `loftwah` seed data.

## Why

This is the first moment the application resembles Linkarooie. A user can create a profile, publish it, and an anonymous visitor can read it.

## Where It Goes

```text
services/linkarooie-api/src/main/java/com/linkarooie/api/profiles/
services/linkarooie-api/src/main/java/com/linkarooie/api/publicprofiles/
services/linkarooie-api/src/main/java/com/linkarooie/api/profiles/domain/
services/linkarooie-api/src/main/resources/db/migration/
services/linkarooie-api/seed/
services/linkarooie-api/seed/assets/
```

## Build Steps

1. Add Flyway migration for `profiles`.
2. Add username normalization, reserved username checks, and uniqueness checks.
3. Add profile ownership rules for `USER` and `ORGANISATION`.
4. Add `POST /api/profiles`.
5. Add owner read/update/list endpoints.
6. Add publish and unpublish endpoints.
7. Add `GET /api/public/profiles/{username}`.
8. Add `GET /api/public/directory`.
9. Cache public profile DTOs in Redis under `profile:public:{username}`.
10. Evict public profile cache when owner-facing profile changes.
11. Add a seed importer or temporary seed command for the original `loftwah` profile.

## Verification

```bash
cd services/linkarooie-api
./gradlew test
./gradlew bootRun
```

Manual smoke:

```bash
curl -i -b /tmp/linkarooie.cookies \
  -H 'Content-Type: application/json' \
  -d '{"ownerType":"USER","username":"loftwah"}' \
  http://localhost:8080/api/profiles

curl -i http://localhost:8080/api/public/profiles/loftwah
curl -i http://localhost:8080/api/public/directory
```

Check Redis:

```bash
docker exec redis redis-cli keys 'profile:public:*'
```

## Tangible Result

- A signed-in user can create and publish a profile.
- Anonymous visitors can fetch the public profile by username.
- Directory reads return public directory-enabled profiles.
- Redis contains cached public profile responses.

## Test Coverage

- Unit tests for username rules and reserved words.
- Authorization tests for personal and organisation-owned profiles.
- Integration tests for profile persistence and uniqueness.
- Component tests for public read caching and cache eviction.
- Black-box test for create, publish, and public read.
