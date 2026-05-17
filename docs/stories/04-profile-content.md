# Story 4: Profile Content

## Goal

Add social links, primary links, achievements, tags, related work, ordering, visibility, and hidden item unlock behaviour.

## Why

Profiles become useful when owners can manage the content visitors actually click and read.

## Where It Goes

```text
services/linkarooie-api/src/main/java/com/linkarooie/api/sociallinks/
services/linkarooie-api/src/main/java/com/linkarooie/api/links/
services/linkarooie-api/src/main/java/com/linkarooie/api/achievements/
services/linkarooie-api/src/main/java/com/linkarooie/api/tags/
services/linkarooie-api/src/main/java/com/linkarooie/api/profilecontent/
services/linkarooie-api/src/main/resources/db/migration/
```

## Build Steps

1. Add Flyway migration for `social_links`, `links`, `achievements`, `tags`, and `related_work`.
2. Add URL validation with allowed schemes.
3. Add platform-specific social URL validation for known platforms.
4. Add CRUD endpoints for social links.
5. Add CRUD and reorder endpoints for links.
6. Add CRUD and reorder endpoints for achievements.
7. Add CRUD and reorder endpoints for tags and related work.
8. Add `isVisible` and `isHidden` handling.
9. Add hidden unlock endpoint or request mode that returns hidden items only after a valid unlock code.
10. Invalidate `profile:public:{username}` after every content mutation.

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
  -d '{"title":"My Blog","description":"Writing and projects","url":"https://example.com","icon":"book-open"}' \
  http://localhost:8080/api/profiles/<profileId>/links

curl -i http://localhost:8080/api/public/profiles/loftwah
```

## Tangible Result

- Public profile responses include visible social links, links, achievements, tags, and related work.
- Owners can reorder content and see that order reflected publicly.
- Hidden content is excluded until unlocked.

## Test Coverage

- Unit tests for URL and platform validation.
- Unit tests for reorder operations.
- Authorization tests for content mutation.
- Integration tests for public profile DTO assembly.
- Black-box tests for visible, hidden, and reordered content.
