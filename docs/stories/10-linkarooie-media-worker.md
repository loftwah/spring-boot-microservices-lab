# Story 10: Generated Media Worker

## Goal

Add the Node.js media worker that consumes Kafka media events, generates image variants and Open Graph images, uploads outputs to RustFS/S3, and records completion through internal API endpoints.

## Why

Image generation has native dependencies and browser rendering needs that do not belong inside the Spring Boot API. This worker gives the app a real asynchronous media pipeline.

## Where It Goes

```text
services/linkarooie-media-worker/
  package.json
  src/
    worker.ts
    renderers/
    image/
services/linkarooie-api/src/main/java/com/linkarooie/api/internalmedia/
services/linkarooie-api/src/main/java/com/linkarooie/api/eventing/media/
services/linkarooie-media-worker/src/events/
```

## Build Steps

1. Add topic constant for `linkarooie.media.events.v1`.
2. Publish `MEDIA_VARIANTS_REQUESTED` after an avatar or banner original is accepted.
3. Publish `PROFILE_OG_IMAGE_STALE` after profile or media changes that affect OG output.
4. Add internal API authentication with a service token.
5. Add `POST /api/internal/media/generated`.
6. Add `POST /api/internal/media/{mediaId}/variants`.
7. Create media worker package with TypeScript, Kafka client, AWS SDK S3 client, Puppeteer, Sharp, and test tooling.
8. Consume media events idempotently.
9. Fetch current profile/media state from the API before rendering.
10. Generate avatar and banner variants with Sharp.
11. Generate OG images with Puppeteer-rendered HTML and Sharp final encoding.
12. Upload variants and generated images to RustFS/S3.
13. Call internal API completion endpoints.
14. Publish ready or failed media events for auditability.

## Verification

Create topics:

```bash
./supporting-services/scripts/create-linkarooie-topics.sh
```

Run services:

```bash
cd services/linkarooie-api
./gradlew bootRun
```

```bash
cd services/linkarooie-media-worker
bun install
bun run dev
```

Trigger work by uploading media or updating a profile:

```bash
curl -i -b /tmp/linkarooie.cookies \
  -F "file=@services/linkarooie-api/seed/assets/default_banner.jpg;type=image/jpeg" \
  http://localhost:8080/api/profiles/<profileId>/media/banner
```

## Tangible Result

- Media upload produces optimized variants.
- Profile update produces an OG image.
- RustFS contains generated objects.
- Public profile media uses generated variants.
- API ignores stale worker completions when profile versions no longer match.

## Test Coverage

- Unit tests for event parsing and stale-version handling.
- Unit tests for variant key generation.
- Image tests that verify output dimensions, content type, and metadata stripping.
- Integration tests against local S3-compatible storage.
- Black-box test for upload, wait for variants, then public profile render.
