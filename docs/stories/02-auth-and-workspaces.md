# Story 2: Auth And Workspaces

## Goal

Add users, organisations, organisation memberships, signup, login, logout, Redis-backed sessions, CSRF handling, and `/api/me`.

## Why

Profiles can be owned by users or teams. Auth and workspace boundaries must exist before profile editing, media uploads, analytics, or dashboard screens are meaningful.

## Where It Goes

```text
services/linkarooie-api/src/main/java/com/linkarooie/api/auth/
services/linkarooie-api/src/main/java/com/linkarooie/api/me/
services/linkarooie-api/src/main/java/com/linkarooie/api/organisations/
services/linkarooie-api/src/main/java/com/linkarooie/api/identity/
services/linkarooie-api/src/main/resources/db/migration/
```

## Build Steps

1. Add Flyway migrations for `users`, `organisations`, and `organisation_members`.
2. Add domain rules for email normalization, user status, organisation roles, and last-owner protection.
3. Add password hashing with Spring Security's `PasswordEncoder`.
4. Configure Spring Security with HTTP-only session cookies and Redis session storage.
5. Add CSRF support for unsafe methods.
6. Add `POST /api/auth/signup`.
7. Add `POST /api/auth/login`.
8. Add `POST /api/auth/logout`.
9. Add `GET /api/me`.
10. Add organisation create, list, update, and membership endpoints.

## Verification

```bash
cd services/linkarooie-api
./gradlew test
./gradlew bootRun
```

Manual smoke:

```bash
curl -i -c /tmp/linkarooie.cookies \
  -H 'Content-Type: application/json' \
  -d '{"email":"dean@example.com","password":"correct horse battery staple","displayName":"Dean Lofts"}' \
  http://localhost:8080/api/auth/signup

curl -i -b /tmp/linkarooie.cookies http://localhost:8080/api/me
```

## Tangible Result

- A user can sign up.
- A browser-safe session is stored in Redis.
- `/api/me` returns the signed-in user, personal workspace, organisations, and memberships.
- Organisation owner rules are enforced.

## Test Coverage

- Unit tests for email normalization and role rules.
- Unit tests for last-owner protection.
- MVC tests for signup validation and duplicate email errors.
- Integration test proving session state is backed by Redis.
- Component tests for organisation membership authorization.
