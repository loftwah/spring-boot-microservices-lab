# Story 5: Media Uploads

## Goal

Add RustFS/S3-backed avatar and banner uploads, media metadata, stable public media URLs, and profile media references.

## Why

Media is a core part of Linkarooie's identity. This story keeps binary objects out of Postgres while giving the API ownership of metadata, validation, and permissions.

## Where It Goes

```text
services/linkarooie-api/src/main/java/com/linkarooie/api/media/
services/linkarooie-api/src/main/resources/db/migration/
services/linkarooie-api/seed/assets/
```

## Build Steps

1. Add Flyway migration for `media_assets` and `media_variants`.
2. Add S3-compatible client configuration for RustFS.
3. Ensure bucket `linkarooie-media-local` exists during local startup or seed import.
4. Add media owner and profile ownership checks.
5. Add `POST /api/profiles/{profileId}/media/avatar`.
6. Add `POST /api/profiles/{profileId}/media/banner`.
7. Validate file size, content type, and decoded image dimensions.
8. Reject SVG uploads for user media.
9. Store original objects with the spec key convention.
10. Save media metadata in Postgres.
11. Add `GET /api/public/media/{mediaId}/{variant}` as a stable public API URL.
12. For this story, allow original or placeholder variants until the media worker story generates real derivatives.
13. Invalidate public profile cache after media changes.

## Verification

```bash
cd services/linkarooie-api
./gradlew test
./gradlew bootRun
```

Manual smoke:

```bash
curl -i -b /tmp/linkarooie.cookies \
  -F "file=@services/linkarooie-api/seed/assets/default_avatar.jpg;type=image/jpeg" \
  http://localhost:8080/api/profiles/<profileId>/media/avatar

curl -i http://localhost:8080/api/public/profiles/loftwah
```

Check RustFS object creation:

```bash
docker exec rustfs find /data -maxdepth 5 -type f | head
```

## Tangible Result

- Uploading an avatar or banner creates a RustFS object and a `media_assets` row.
- Public profile JSON returns stable application media URLs.
- Public media read works without exposing RustFS credentials.

## Test Coverage

- Unit tests for object key generation.
- Unit tests for content-type and extension handling.
- Integration tests against MinIO Testcontainers or RustFS-compatible S3.
- Component tests for upload authorization.
- Black-box test for upload then public profile media read.
