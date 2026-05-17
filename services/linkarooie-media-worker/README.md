# linkarooie-media-worker

Node.js worker for image variants and generated Open Graph images.

## Runtime

- Bun for local install and development commands.
- Node.js LTS in containers.
- TypeScript.
- Kafka client.
- AWS SDK S3 client.
- Puppeteer for browser rendering.
- Sharp for metadata stripping, resizing, encoding, and dimension checks.

## Owns

- Consuming `linkarooie.media.events.v1`.
- Generating avatar and banner variants.
- Rendering profile Open Graph images.
- Uploading generated assets to RustFS/S3.
- Calling internal API media completion endpoints.
- Idempotent handling of stale or repeated media work.

## Does Not Own

- Profile source-of-truth data.
- User auth.
- Public media authorization.
- Profile media metadata schema.

Those stay in the Spring Boot API and persistence modules.

## First Useful Build

1. Consume one media event.
2. Download one source image from RustFS/S3.
3. Generate one WebP variant with Sharp.
4. Upload it to RustFS/S3.
5. Call the internal API completion endpoint.

## Verification

```bash
./supporting-services/scripts/create-linkarooie-topics.sh
cd services/linkarooie-media-worker
bun install
bun run test
bun run dev
```
