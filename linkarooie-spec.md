# Linkarooie Spring Boot Microservices Lab Application Spec

Status: draft application specification

Target repo: [spring-boot-microservices-lab](https://github.com/loftwah/spring-boot-microservices-lab)

Source product: [Linkarooie Astro project](https://github.com/loftwah/linkarooie-3)

Primary goal: rebuild Linkarooie as a Java Spring Boot backend plus TanStack React frontend, designed for Kubernetes, GitHub Container Registry, and cloud-like supporting services.

## 1. Product Summary

Linkarooie is an open-source "link in bio" product with more personality and depth than a plain Linktree clone.

The existing project is a static Astro and Tailwind app where a profile is defined in TypeScript. A profile currently contains:

- Public profile identity: name, username, description, bio.
- Profile media: avatar, banner, Open Graph image.
- Social links: GitHub, X/Twitter, Bluesky, LinkedIn.
- Links: title, description, URL, icon, visibility.
- Achievements: title, description, date, URL, icon, visibility.
- Tags: name, description, citation, and related work.
- Directory inclusion flags.
- SEO and social sharing metadata.
- Dark and light theme support.
- Hidden links and achievements unlocked with a profile-specific Easter egg.
- Tracking hooks for link, social, and achievement interactions.

The new version should turn this into a multi-user hosted application:

- Users can sign up.
- Users can create and manage their own public Linkarooie profile.
- Public visitors can view profile pages without signing in.
- Public visitors can browse a directory of public profiles.
- Link clicks and profile views are captured as analytics events.
- Per-profile analytics can be displayed publicly.
- Application-wide public analytics can also be displayed.
- Uploaded media is stored in S3-compatible object storage.
- Kafka is used for event-driven analytics and future extensibility.
- Redis is used for caching, rate limiting, sessions or token state, and hot counters.
- PostgreSQL is the source of truth.

This spec intentionally ignores Vault, Jenkins, and full observability stack implementation for now. The code should still be ready for those later through structured logging, tracing IDs, metrics naming, and clean configuration.

## 2. Version 1 Decision

Version 1 should be a modular Spring Boot backend rather than many separate backend deployables from day one.

The recommended V1 deployment units are:

1. `linkarooie-api`
   - Spring Boot REST API.
   - Owns authentication, user management, profile CRUD, public profile reads, link management, achievement management, tag management, media metadata, and analytics event ingestion.
   - Publishes analytics events to Kafka.
   - Reads cached public profile data from Redis where appropriate.

2. `linkarooie-analytics-worker`
   - Spring Boot Kafka consumer.
   - Consumes analytics events.
   - Writes immutable event records and aggregate analytics into PostgreSQL.
   - Updates Redis hot counters for fast public display.
   - Can share domain libraries with `linkarooie-api`.

3. `linkarooie-web`
   - TanStack React application with Tailwind CSS v4.
   - Public profile pages, directory, sign-in/sign-up, dashboard, profile editor, link editor, achievement editor, analytics screens.

This gives the lab enough moving parts to practice application containers, Kafka, Redis, S3, Postgres, k3d, Kubernetes manifests, and GHCR without forcing premature distributed-system complexity.

The backend code should still be organized as if these modules could later become true microservices:

- Identity module.
- Profile module.
- Link module.
- Achievement module.
- Tag module.
- Media module.
- Analytics module.
- Eventing module.
- Shared observability and web API module.

The future extraction path is documented later in this spec.

## 3. Supporting Services

The lab already provides centralized services with Docker Compose. Treat these as cloud service stand-ins.

Important deployment boundary:

- PostgreSQL, Redis, Kafka, RustFS, Vault, and Jenkins are not application workloads. They are stood up using Docker Compose and are designed to simulate centralized and managed services locally that we can change in configuration.
- Do not deploy PostgreSQL, Redis, Kafka, or RustFS or other supporting services into the k3d cluster.
- The only workloads deployed into k3d are Linkarooie application workloads: API, analytics worker, frontend, and later any application-owned jobs.
- The application pods running inside k3d connect out to the Docker Compose services through host-reachable addresses.
- In a real AWS-style environment, the same application containers would stay mostly unchanged and only configuration would change to point at RDS, ElastiCache, S3, and managed Kafka/MSK or another Kafka provider.

This mirrors the common production pattern: Kubernetes runs your application; managed platform services run outside the cluster and are consumed over the network.

For local development there are two different network perspectives:

- Processes running directly on your Mac use `localhost` ports exposed by Docker Compose.
- Pods running inside k3d cannot use their own `localhost` to reach your Mac services, so they use a host bridge name such as `host.k3d.internal`.

That address is not saying the service is in Kubernetes. It is just the route from an application pod to a service running outside the cluster.

### PostgreSQL

Purpose:

- Primary application database.
- Users, profiles, links, achievements, tags, media metadata, analytics aggregates, event records, outbox records.

Local Compose:

- Host: `localhost`
- Port: `5432`
- Database: `app`
- User: `app`
- Password: `app`

When Linkarooie runs inside k3d:

- The app pod connects to the Docker Compose PostgreSQL port through `host.k3d.internal:5432`.
- Keep the JDBC URL configurable through environment variables and Kubernetes secrets/config maps.

Real-world config equivalent:

- Replace the local JDBC URL with an RDS PostgreSQL endpoint.
- Keep the application code unchanged.

Recommended libraries:

- Spring Data JPA for main CRUD.
- Flyway for migrations.
- PostgreSQL JSONB where flexible event payloads are useful, but avoid making core profile data schemaless.

### Redis

Purpose:

- Cache public profile responses.
- Cache directory pages.
- Store rate-limit counters.
- Store short-lived auth or refresh token state if needed.
- Store analytics hot counters for quick public dashboards.
- Optional distributed lock for idempotent analytics aggregation.

Local Compose:

- Host: `localhost`
- Port: `6379`

When Linkarooie runs inside k3d:

- The app pod connects to Docker Compose Redis through `host.k3d.internal:6379`.

Real-world config equivalent:

- Replace the host and port with an ElastiCache Redis endpoint.
- Keep the application code unchanged.

Recommended usage:

- Spring Cache abstraction for profile and directory cache.
- Direct Redis operations for counters and rate limits.
- Use explicit cache key prefixes: `profile:public:{username}`, `directory:page:{page}`, `analytics:profile:{profileId}:views`.

### Kafka

Purpose:

- Analytics event stream.
- Future async workflows such as OG image generation, media processing, audit logs, notification events, and search indexing.

Local Compose:

- Host clients: `localhost:9092`.
- App pods running in k3d: `host.k3d.internal:9094`.

The Compose file exposes a separate advertised listener for k3d because Kafka clients need broker addresses that are reachable from where the client runs. This does not mean Kafka is deployed in the k3d cluster.

Real-world config equivalent:

- Replace `KAFKA_BOOTSTRAP_SERVERS` with an MSK or managed Kafka bootstrap string.
- Keep the application code unchanged.

Initial topics:

- `linkarooie.analytics.events.v1`
- `linkarooie.audit.events.v1`
- `linkarooie.media.events.v1` later.
- `linkarooie.profile.events.v1` later.

For V1, only `linkarooie.analytics.events.v1` is required.

Kafka event principles:

- Events are facts, not commands.
- Events must include a stable `eventId`.
- Consumers must be idempotent.
- Keep event schemas versioned.
- Include `occurredAt`, `receivedAt`, `profileId`, optional `userId`, `anonymousVisitorId`, `requestId`, and event type.

### RustFS / S3-Compatible Storage

Purpose:

- Avatar uploads and resized avatar variants.
- Banner uploads and resized banner variants.
- Generated or uploaded OG images.
- Future exports.

Local Compose:

- API endpoint: `http://localhost:9000`
- Console: `http://localhost:9001`
- Access key: `rustfsadmin`
- Secret key: `rustfsadmin`

When Linkarooie runs inside k3d:

- The app pod connects to Docker Compose RustFS through `http://host.k3d.internal:9000`.

Real-world config equivalent:

- Replace endpoint and credentials with AWS S3 configuration.
- Keep bucket/key logic mostly unchanged.

Buckets:

- `linkarooie-media-local`

Object key convention:

- New user uploads: `profiles/{profileId}/{purpose}/{mediaId}/original.{ext}`
- Generated variants: `profiles/{profileId}/{purpose}/{mediaId}/{variant}.{ext}`
- Generated OG images: `profiles/{profileId}/og/{mediaId}/og.png`
- Seed assets may use deterministic human-readable keys such as `profiles/loftwah/avatar/loftwah_avatar.jpg` so the fixture is easy to inspect.

Public access decision:

- V1 should not rely on public bucket access.
- Store media privately and expose public media through API redirect or short-lived signed URL generation.
- The public API should return stable application media URLs, not raw RustFS URLs, for example `/api/public/media/{mediaId}/avatar-md`.
- The API can redirect stable media URLs to signed S3/RustFS URLs with cache headers.
- Later, when deploying for real, use CDN or object storage public-read rules if desired.

## 4. Product Scope

### V1 Must Have

- User sign-up.
- User sign-in.
- User-owned profile creation.
- Public username route.
- Profile edit dashboard.
- Avatar and banner upload.
- Link CRUD.
- Link ordering.
- Link visibility toggle.
- Achievement CRUD.
- Achievement ordering.
- Achievement visibility toggle.
- Tag CRUD with citation and related work.
- Public profile page.
- Public directory page.
- Public app-wide analytics page.
- Public per-profile analytics section.
- Internal dashboard analytics for the signed-in owner.
- Link click tracking.
- Profile view tracking.
- Social link click tracking.
- Achievement click tracking.
- Tag open tracking.
- Basic anti-abuse rate limiting.
- REST API with OpenAPI docs.
- Dockerfiles for API, analytics worker, and frontend.
- Kubernetes manifests or Helm chart later in the lab.

### V1 Should Have

- Email verification can be skipped locally, but design the database so it can be added.
- Password reset can be stubbed or deferred, but auth code should not make it difficult later.
- Theme preference at profile level.
- Public profile SEO metadata.
- User configurable public analytics visibility.
- Owner-only analytics with more detail than public analytics.
- Slug-safe username reservation.
- Basic moderation flags for public directory inclusion.
- Seed data for the original `loftwah` profile.

### V1 Could Have

- Generated OG image job.
- Hidden profile items with unlock code.
- Profile preview in editor.
- Import from the old TypeScript profile format.
- Export profile as JSON.
- Basic webhooks for events.

### Explicit Non-Goals For V1

- Vault integration.
- Jenkins pipelines.
- OpenSearch/Grafana/Loki/Tempo stack.
- Multi-region deployment.
- Payment/subscription system.
- Organization/team accounts.
- Full CMS.
- Custom domains.
- Real email sending.
- Advanced bot detection.
- Search engine indexing service.

## 5. User Roles

### Anonymous Visitor

Can:

- View public profiles.
- Browse the public directory.
- Click public links, achievements, social links, and tags.
- View public analytics if enabled.

Cannot:

- Edit anything.
- View private profiles.
- View owner-only analytics.

### Registered User

Can:

- Sign in.
- Create one or more profiles, if enabled.
- Edit profiles they own.
- Upload profile media.
- Manage links, achievements, tags, and related work.
- View owner analytics.
- Decide whether profile is public.
- Decide whether profile appears in directory.
- Decide whether public analytics appears on their profile.

Default V1 rule:

- One account can own multiple profiles, but the UI can initially optimize for one profile per user.

### Admin

V1 can keep admin minimal.

Can:

- Hide profiles from directory.
- Disable abusive profiles.
- View basic app-wide counters.

Admin UI can be deferred. Keep the role in the model.

## 6. Core User Journeys

### Visitor Views A Profile

1. Visitor opens `/{username}`.
2. Frontend calls `GET /api/public/profiles/{username}`.
3. API checks Redis cache.
4. Cache miss reads profile, links, achievements, tags, and media metadata from PostgreSQL.
5. API returns public profile response.
6. API or frontend records `PROFILE_VIEW`.
7. API publishes analytics event to Kafka.
8. Analytics worker consumes event and updates aggregates.
9. Public profile renders avatar, banner, identity, social links, tags, links, achievements, and public analytics if enabled.

### Visitor Clicks A Link

Preferred V1 flow:

1. Public link uses app redirect URL: `/r/{publicLinkId}` or `/api/public/links/{linkId}/redirect`.
2. API validates that the link is public and belongs to a public profile.
3. API records `LINK_CLICK`.
4. API publishes analytics event.
5. API redirects to the external URL.

Why use redirect:

- More reliable than client-side tracking.
- Works even with ad blockers that block analytics scripts.
- Lets the backend rate limit and deduplicate.

Frontend can still call event ingestion for tag opens and UI-only events.

### User Creates Profile

1. User signs up.
2. User lands in dashboard.
3. User chooses a username.
4. API validates username format, uniqueness, and reserved words.
5. API creates a profile draft.
6. User adds bio, avatar, banner, social links, links, achievements, and tags.
7. User toggles profile public.
8. Public route becomes available.

### User Uploads Avatar Or Banner

1. Frontend asks API for upload intent.
2. API validates owner and file metadata.
3. API either returns a presigned PUT URL or accepts multipart upload directly.
4. File lands in RustFS.
5. API stores media metadata in PostgreSQL.
6. API validates the stored object by reading metadata and, for images, decoding the file.
7. API strips EXIF/metadata where possible and creates web-safe variants.
8. API updates profile media reference to the ready media asset.
9. API invalidates public profile cache.

For a simple V1, direct multipart upload through the API is acceptable. For a more cloud-realistic V1, use presigned URLs.

Image handling requirements:

- Never trust file extension alone.
- Validate content type by decoding the image.
- Accept `image/jpeg`, `image/png`, and `image/webp` for uploaded avatars/banners.
- Reject SVG uploads for user profile media in V1 because SVG can contain active content and is not needed for avatars/banners.
- Strip EXIF metadata to avoid leaking camera/location data.
- Store the original object privately.
- Generate optimized variants for public rendering.
- Keep old media objects until the profile update succeeds; clean unreferenced media later with a maintenance job.

### User Views Analytics

1. User opens dashboard analytics.
2. Frontend calls owner analytics endpoints.
3. API returns aggregates by time range.
4. API may read hot counters from Redis and historical aggregates from PostgreSQL.
5. Owner sees profile views, unique visitors, top links, top referrers, social clicks, achievement clicks, tag opens, hidden unlocks, and trends.

## 7. Domain Model

Use UUID primary keys internally. Use stable public IDs where exposing IDs in URLs is necessary.

Use `createdAt`, `updatedAt`, and optimistic locking where edits can conflict.

### User

Represents an account that can own profiles.

Fields:

- `id`
- `email`
- `emailVerifiedAt`
- `passwordHash`
- `displayName`
- `role`: `USER`, `ADMIN`
- `status`: `ACTIVE`, `LOCKED`, `DELETED`
- `createdAt`
- `updatedAt`

Rules:

- Email is unique case-insensitively.
- Password hash only, never plaintext.
- Soft delete users if needed.

### Profile

Represents a public Linkarooie page.

Fields:

- `id`
- `ownerUserId`
- `username`
- `name`
- `description`
- `bio`
- `avatarMediaId`
- `bannerMediaId`
- `ogMediaId`
- `ogTitle`
- `ogDescription`
- `theme`: `SYSTEM`, `LIGHT`, `DARK`
- `accentColor`
- `isPublic`
- `showInDirectory`
- `showPublicAnalytics`
- `hiddenUnlockCodeHash`
- `createdAt`
- `updatedAt`

Rules:

- `username` is globally unique.
- `username` should be lowercase and URL-safe.
- Reserved usernames are blocked: `api`, `admin`, `dashboard`, `login`, `signup`, `settings`, `r`, `assets`, `static`, `health`.
- Public profile reads only include visible items.
- Hidden items are not returned unless explicitly unlocked.
- A profile can be private but still editable by its owner.

### SocialLink

Represents a social platform URL on a profile.

Fields:

- `id`
- `profileId`
- `platform`
- `url`
- `displayOrder`
- `isVisible`
- `createdAt`
- `updatedAt`

Initial platforms:

- `GITHUB`
- `X_TWITTER`
- `BLUESKY`
- `LINKEDIN`
- `WEBSITE`
- `YOUTUBE`
- `MASTODON`
- `INSTAGRAM`
- `TIKTOK`

Rules:

- Validate URL.
- Platform-specific validation can be added later.

### Link

Represents a primary link card.

Fields:

- `id`
- `profileId`
- `publicId`
- `title`
- `description`
- `url`
- `icon`
- `displayOrder`
- `isVisible`
- `isHidden`
- `createdAt`
- `updatedAt`

Rules:

- Public profile shows links where `isVisible = true` and `isHidden = false`.
- Hidden links are not shown until unlocked.
- Redirect endpoint records click analytics.
- External URL must use allowed schemes: `http`, `https`, `mailto` if explicitly allowed.

### Achievement

Represents a certification, milestone, or notable event.

Fields:

- `id`
- `profileId`
- `publicId`
- `title`
- `description`
- `url`
- `icon`
- `achievedOn`
- `displayDate`
- `showFullDate`
- `displayOrder`
- `isVisible`
- `isHidden`
- `createdAt`
- `updatedAt`

Rules:

- `achievedOn` is structured date where possible.
- `displayDate` allows legacy strings such as `19 Jul 2024`.
- Public profile shows visible non-hidden achievements.

### Tag

Represents a skill, topic, technology, or theme attached to a profile.

Fields:

- `id`
- `profileId`
- `name`
- `description`
- `citationTitle`
- `citationUrl`
- `displayOrder`
- `isVisible`
- `createdAt`
- `updatedAt`

Rules:

- Name is required.
- Citation URL requires citation title if a title is displayed.
- Tags can exist with only a name.

### RelatedWork

Represents work connected to a tag.

Fields:

- `id`
- `tagId`
- `title`
- `url`
- `description`
- `displayOrder`
- `createdAt`
- `updatedAt`

Rules:

- Related work only appears inside tag details.
- URL is required.

### MediaAsset

Represents an object stored in RustFS/S3.

Fields:

- `id`
- `ownerUserId`
- `profileId`
- `bucket`
- `objectKey`
- `originalFilename`
- `contentType`
- `byteSize`
- `checksum`
- `width`
- `height`
- `purpose`: `AVATAR`, `BANNER`, `OG_IMAGE`, `BRAND`, `BRAND_OG`, `OTHER`
- `visibility`: `PRIVATE`, `PUBLIC_READ`
- `status`: `PENDING`, `READY`, `FAILED`, `DELETED`
- `createdByUploadId`
- `createdAt`
- `updatedAt`

Rules:

- Profile media references `MediaAsset`.
- Do not store binary media in PostgreSQL.
- Use object key convention.
- Store image dimensions after decoding.
- Store checksums so duplicate uploads and seed drift can be detected.
- Keep media immutable. Replacing an avatar creates a new media asset and updates the profile reference.
- Do not overwrite existing object keys for normal user uploads.

### MediaVariant

Represents a derived object optimized for a specific UI use.

Fields:

- `id`
- `mediaAssetId`
- `variant`: `AVATAR_SM`, `AVATAR_MD`, `AVATAR_LG`, `BANNER_MD`, `BANNER_LG`, `OG_IMAGE`
- `bucket`
- `objectKey`
- `contentType`
- `byteSize`
- `checksum`
- `width`
- `height`
- `createdAt`

Recommended variants:

- Avatar small: 96x96 WebP.
- Avatar medium: 256x256 WebP.
- Avatar large: 512x512 WebP.
- Banner medium: 1200x400 WebP.
- Banner large: 1800x600 WebP.
- OG image: 1200x630 PNG or JPEG.

Rules:

- Public profile responses should prefer variants, not originals.
- Originals are for regeneration and audit, not normal page rendering.
- If a variant is missing, return the best available fallback and queue regeneration later.

### AnalyticsEvent

Immutable record of a visitor action.

Fields:

- `id`
- `eventId`
- `eventType`
- `profileId`
- `userId`
- `targetType`
- `targetId`
- `anonymousVisitorIdHash`
- `sessionIdHash`
- `requestId`
- `url`
- `referrer`
- `userAgentHash`
- `ipHash`
- `countryCode`
- `metadata`
- `occurredAt`
- `receivedAt`

Event types:

- `PROFILE_VIEW`
- `LINK_CLICK`
- `SOCIAL_CLICK`
- `ACHIEVEMENT_CLICK`
- `TAG_OPEN`
- `DIRECTORY_PROFILE_CLICK`
- `HIDDEN_ITEMS_UNLOCKED`
- `MEDIA_VIEW` later.

Privacy rules:

- Do not store raw IP addresses in V1 analytics tables.
- Hash IP and user agent with a server-side salt if uniqueness is needed.
- Keep public analytics aggregated only.
- Owner analytics can be more detailed but should still avoid exposing raw visitor identifiers.

### ProfileAnalyticsDaily

Daily aggregate for profile analytics.

Fields:

- `id`
- `profileId`
- `date`
- `views`
- `uniqueVisitors`
- `linkClicks`
- `socialClicks`
- `achievementClicks`
- `tagOpens`
- `hiddenUnlocks`
- `createdAt`
- `updatedAt`

Unique constraint:

- `(profileId, date)`

### TargetAnalyticsDaily

Daily aggregate for a specific link, social link, achievement, or tag.

Fields:

- `id`
- `profileId`
- `targetType`
- `targetId`
- `date`
- `events`
- `uniqueVisitors`
- `createdAt`
- `updatedAt`

Unique constraint:

- `(profileId, targetType, targetId, date)`

### AppAnalyticsDaily

Daily aggregate across the whole application.

Fields:

- `id`
- `date`
- `profileViews`
- `uniqueVisitors`
- `linkClicks`
- `signups`
- `activeProfiles`
- `publicProfiles`
- `createdAt`
- `updatedAt`

## 8. Backend Architecture

### Recommended Backend Repo Structure

Use a Gradle multi-project build:

```text
backend/
  settings.gradle.kts
  build.gradle.kts
  linkarooie-api/
    src/main/java/com/linkarooie/api/
    src/main/resources/
  linkarooie-analytics-worker/
    src/main/java/com/linkarooie/analyticsworker/
    src/main/resources/
  linkarooie-domain/
    src/main/java/com/linkarooie/domain/
  linkarooie-persistence/
    src/main/java/com/linkarooie/persistence/
    src/main/resources/db/migration/
  linkarooie-eventing/
    src/main/java/com/linkarooie/eventing/
  linkarooie-observability/
    src/main/java/com/linkarooie/observability/
  linkarooie-web-contracts/
    src/main/java/com/linkarooie/contracts/
```

Simpler alternative:

```text
backend/
  src/main/java/com/linkarooie/
    auth/
    users/
    profiles/
    links/
    achievements/
    tags/
    media/
    analytics/
    eventing/
    common/
```

For the lab, the multi-project build is better because it teaches service boundaries early.

### Module Responsibilities

#### `linkarooie-domain`

Contains:

- Domain models that are not tied to Spring MVC.
- Domain value objects.
- Domain exceptions.
- Domain event interfaces.
- Business rules that do not require infrastructure.

Avoid:

- Controllers.
- JPA annotations if you want stricter separation.
- HTTP-specific concepts.

#### `linkarooie-persistence`

Contains:

- JPA entities.
- Spring Data repositories.
- Flyway migrations.
- Persistence mappers.
- Query projections.

Rules:

- Database access stays here.
- Do not let controllers call repositories directly.

#### `linkarooie-api`

Contains:

- REST controllers.
- Request/response DTOs.
- Application services.
- Security configuration.
- Cache configuration.
- API-specific exception handlers.
- OpenAPI configuration.

#### `linkarooie-analytics-worker`

Contains:

- Kafka listeners.
- Analytics aggregation services.
- Idempotency handling.
- Worker health checks.

#### `linkarooie-eventing`

Contains:

- Event envelope types.
- Kafka producer.
- Kafka topic names.
- Event serializers/deserializers.
- Event publishing interface.

#### `linkarooie-observability`

Contains:

- Structured logging helpers.
- Request ID filter.
- MDC helpers.
- Common metric names.
- Audit logging helpers.

### Package Style

Prefer vertical feature packages rather than technical buckets.

Good:

```text
profiles/
  api/
  application/
  domain/
  persistence/
  dto/
```

Avoid large generic packages like:

```text
controllers/
services/
repositories/
models/
```

The code should make ownership obvious.

### Application Service Pattern

Use composable application services that do one job each.

Example service naming:

- `CreateProfileService`
- `UpdateProfileService`
- `PublishProfileService`
- `GetPublicProfileService`
- `CreateLinkService`
- `ReorderLinksService`
- `RecordAnalyticsEventService`
- `AggregateAnalyticsEventService`
- `CreateMediaUploadService`

Each application service should:

- Accept one command/query object.
- Return one result object.
- Own transaction boundaries where appropriate.
- Validate authorization at the application boundary.
- Call repositories through interfaces or focused repository classes.
- Publish domain/application events after state changes.
- Log structured success/failure context.

Example shape:

```java
public interface UseCase<C, R> {
    R handle(C command);
}
```

Commands should be explicit records:

```java
public record CreateLinkCommand(
    UUID actorUserId,
    UUID profileId,
    String title,
    String description,
    URI url,
    String icon
) {}
```

Results should be explicit records:

```java
public record CreateLinkResult(
    UUID linkId,
    String publicId,
    Instant createdAt
) {}
```

Do not build one huge `ProfileService` with every method. Small service classes are easier to test, compose, observe, and later extract.

### Controller Rules

Controllers should be thin.

They should:

- Validate request shape.
- Resolve authenticated actor.
- Call one application service.
- Return DTOs.

They should not:

- Contain business rules.
- Talk directly to JPA repositories.
- Build Kafka events directly.
- Know storage object key rules.

### Error Handling

Use Spring `ProblemDetail` responses.

Common error codes:

- `validation_failed`
- `unauthorized`
- `forbidden`
- `not_found`
- `username_unavailable`
- `profile_not_public`
- `rate_limited`
- `media_upload_failed`
- `analytics_event_rejected`

Response shape:

```json
{
  "type": "https://linkarooie.local/problems/username-unavailable",
  "title": "Username unavailable",
  "status": 409,
  "detail": "That username is already taken.",
  "instance": "/api/profiles",
  "code": "username_unavailable",
  "requestId": "..."
}
```

### Transactions

Rules:

- Commands that mutate PostgreSQL should run in transactions.
- Public read queries should be read-only transactions.
- Kafka publish after DB writes should use an outbox if the event is critical.
- Analytics ingestion can publish directly to Kafka for V1, because losing a click event is less severe than corrupting profile state.

Recommended V1 event reliability:

- Use outbox for profile mutation audit events later.
- Direct Kafka publish for analytics events now.
- Analytics worker uses idempotency on `eventId`.

## 9. API Specification

Base path: `/api`

Use JSON for request/response bodies.

### Health

`GET /api/health`

Returns API health.

`GET /api/ready`

Checks PostgreSQL, Redis, Kafka producer readiness, and S3 client readiness.

### Auth

`POST /api/auth/signup`

Request:

```json
{
  "email": "dean@example.com",
  "password": "correct horse battery staple",
  "displayName": "Dean Lofts"
}
```

Response:

```json
{
  "user": {
    "id": "...",
    "email": "dean@example.com",
    "displayName": "Dean Lofts"
  }
}
```

The response should also set an HTTP-only session cookie.

`POST /api/auth/login`

`POST /api/auth/refresh`

`POST /api/auth/logout`

V1 auth recommendation:

- Use secure HTTP-only cookies if frontend and backend share the same site.
- Prefer Spring Security sessions backed by Redis for V1.
- This avoids storing JWTs in browser storage and gives Redis a useful production-like role.
- Use `SameSite=Lax` locally and `SameSite=Strict` or `Lax` in production depending on custom-domain needs.
- Set `Secure=true` when using HTTPS.
- Bearer JWTs can be added later for external API clients, but they should not be the default browser auth mechanism.

### Current User

`GET /api/me`

Returns signed-in user and owned profiles.

### Profile Management

`POST /api/profiles`

Creates a profile.

`GET /api/profiles`

Lists profiles owned by current user.

`GET /api/profiles/{profileId}`

Gets owner view of a profile.

`PATCH /api/profiles/{profileId}`

Updates profile identity, copy, SEO, visibility, directory setting, public analytics setting, theme, and accent color.

`DELETE /api/profiles/{profileId}`

Soft deletes or archives profile.

`POST /api/profiles/{profileId}/publish`

Sets `isPublic = true`.

`POST /api/profiles/{profileId}/unpublish`

Sets `isPublic = false`.

### Public Profiles

`GET /api/public/profiles/{username}`

Returns public profile response.

Response:

```json
{
  "profile": {
    "username": "loftwah",
    "name": "Dean Lofts",
    "description": "I like building things and making them work.",
    "bio": "Creator of Linkarooie, Senior DevOps Engineer, and part-time beat maker.",
    "avatarUrl": "...",
    "bannerUrl": "...",
    "ogTitle": "Dean Lofts (Loftwah) - Single Dad and Senior DevOps Engineer",
    "ogDescription": "I create, ship, and connect ideas.",
    "theme": "SYSTEM",
    "accentColor": "#a5fd0e",
    "showPublicAnalytics": true
  },
  "socialLinks": [],
  "links": [],
  "achievements": [],
  "tags": [],
  "analytics": {
    "views": 1234,
    "linkClicks": 567,
    "topLinks": []
  }
}
```

`GET /api/public/directory`

Query params:

- `page`
- `size`
- `tag`
- `q`

Returns public profiles where `isPublic = true` and `showInDirectory = true`.

### Links

`POST /api/profiles/{profileId}/links`

`PATCH /api/profiles/{profileId}/links/{linkId}`

`DELETE /api/profiles/{profileId}/links/{linkId}`

`POST /api/profiles/{profileId}/links/reorder`

Request:

```json
{
  "orderedIds": ["...", "...", "..."]
}
```

Public redirect:

`GET /r/{publicLinkId}`

Behavior:

- Records click.
- Redirects to external URL.

### Social Links

`POST /api/profiles/{profileId}/social-links`

`PATCH /api/profiles/{profileId}/social-links/{socialLinkId}`

`DELETE /api/profiles/{profileId}/social-links/{socialLinkId}`

`POST /api/profiles/{profileId}/social-links/reorder`

Optional redirect:

`GET /s/{publicSocialLinkId}`

### Achievements

`POST /api/profiles/{profileId}/achievements`

`PATCH /api/profiles/{profileId}/achievements/{achievementId}`

`DELETE /api/profiles/{profileId}/achievements/{achievementId}`

`POST /api/profiles/{profileId}/achievements/reorder`

Optional redirect:

`GET /a/{publicAchievementId}`

### Tags And Related Work

`POST /api/profiles/{profileId}/tags`

`PATCH /api/profiles/{profileId}/tags/{tagId}`

`DELETE /api/profiles/{profileId}/tags/{tagId}`

`POST /api/profiles/{profileId}/tags/reorder`

Related work:

`POST /api/profiles/{profileId}/tags/{tagId}/related-work`

`PATCH /api/profiles/{profileId}/tags/{tagId}/related-work/{relatedWorkId}`

`DELETE /api/profiles/{profileId}/tags/{tagId}/related-work/{relatedWorkId}`

### Media

Recommended V1:

`POST /api/profiles/{profileId}/media/avatar`

Multipart upload through the API.

`POST /api/profiles/{profileId}/media/banner`

Multipart upload through the API.

Response:

```json
{
  "mediaId": "...",
  "status": "READY",
  "original": {
    "url": "/api/media/...",
    "width": 400,
    "height": 400,
    "contentType": "image/jpeg"
  },
  "variants": [
    {
      "variant": "AVATAR_MD",
      "url": "/api/public/media/.../avatar-md",
      "width": 256,
      "height": 256,
      "contentType": "image/webp"
    }
  ]
}
```

Public media read:

`GET /api/public/media/{mediaId}/{variant}`

Behavior:

- Validates the media belongs to a public profile or public brand asset.
- Redirects to a short-lived signed RustFS/S3 URL or streams the object.
- Adds cache headers.
- Does not expose RustFS credentials.

Owner media read:

`GET /api/media/{mediaId}`

Behavior:

- Requires ownership.
- Used for dashboard previews and originals.

Future cloud-like upload option:

`POST /api/profiles/{profileId}/media/upload-intents`

Request:

```json
{
  "purpose": "AVATAR",
  "contentType": "image/jpeg",
  "byteSize": 123456
}
```

Response:

```json
{
  "mediaId": "...",
  "uploadUrl": "http://localhost:9000/...",
  "objectKey": "profiles/.../avatar/....jpg",
  "expiresAt": "..."
}
```

`POST /api/profiles/{profileId}/media/{mediaId}/complete`

Marks upload complete after validating object exists.

### Analytics

Client event ingestion:

`POST /api/analytics/events`

Request:

```json
{
  "eventType": "TAG_OPEN",
  "profileUsername": "loftwah",
  "targetType": "TAG",
  "targetId": "...",
  "occurredAt": "2026-05-10T03:00:00Z",
  "metadata": {
    "tagName": "DevOps"
  }
}
```

Owner profile analytics:

`GET /api/profiles/{profileId}/analytics?range=30d`

Public profile analytics:

`GET /api/public/profiles/{username}/analytics?range=30d`

App-wide public analytics:

`GET /api/public/analytics?range=30d`

## 10. Kafka Event Schema

Topic: `linkarooie.analytics.events.v1`

Event envelope:

```json
{
  "eventId": "018f0d8d-...",
  "eventType": "LINK_CLICK",
  "schemaVersion": 1,
  "occurredAt": "2026-05-10T03:00:00Z",
  "receivedAt": "2026-05-10T03:00:01Z",
  "requestId": "req_...",
  "profileId": "...",
  "profileUsername": "loftwah",
  "targetType": "LINK",
  "targetId": "...",
  "anonymousVisitorIdHash": "...",
  "sessionIdHash": "...",
  "url": "https://linkarooie.local/loftwah",
  "referrer": "https://example.com",
  "userAgentHash": "...",
  "ipHash": "...",
  "metadata": {
    "linkTitle": "My Blog"
  }
}
```

Partition key:

- `profileId`

Reason:

- Keeps events for one profile ordered enough for simple aggregation.

Consumer group:

- `linkarooie-analytics-worker`

Idempotency:

- Worker stores `eventId` in `analytics_events`.
- Duplicate event ID is ignored.

## 11. Redis Strategy

### Cache Keys

Public profile:

```text
profile:public:{username}
```

TTL:

- 5 to 15 minutes.

Invalidation:

- On profile, links, achievements, tags, social links, or media change.

Directory:

```text
directory:v1:page:{page}:size:{size}:q:{hash}:tag:{tag}
```

TTL:

- 1 to 5 minutes.

Hot analytics:

```text
analytics:profile:{profileId}:views:total
analytics:profile:{profileId}:clicks:total
analytics:profile:{profileId}:target:{targetType}:{targetId}:events:total
analytics:app:views:total
analytics:app:clicks:total
```

Rate limits:

```text
rate:{scope}:{identifier}:{window}
```

Examples:

- `rate:signup:{ipHash}:2026051003`
- `rate:analytics:{ipHash}:202605100310`
- `rate:login:{emailHash}:2026051003`

### Cache Discipline

- Cache DTOs, not JPA entities.
- Use short TTLs for public reads.
- Explicitly evict on owner writes.
- Do not use Redis as the source of truth.

## 12. PostgreSQL Schema Outline

Initial tables:

- `users`
- `profiles`
- `social_links`
- `links`
- `achievements`
- `tags`
- `related_work`
- `media_assets`
- `media_variants`
- `analytics_events`
- `profile_analytics_daily`
- `target_analytics_daily`
- `app_analytics_daily`
- `outbox_events` later

Important indexes:

```sql
create unique index users_email_lower_idx on users (lower(email));
create unique index profiles_username_lower_idx on profiles (lower(username));
create index profiles_public_directory_idx on profiles (is_public, show_in_directory);
create index links_profile_order_idx on links (profile_id, display_order);
create index achievements_profile_order_idx on achievements (profile_id, display_order);
create index tags_profile_order_idx on tags (profile_id, display_order);
create unique index media_variants_asset_variant_idx on media_variants (media_asset_id, variant);
create unique index analytics_events_event_id_idx on analytics_events (event_id);
create unique index profile_analytics_daily_unique_idx on profile_analytics_daily (profile_id, date);
create unique index target_analytics_daily_unique_idx on target_analytics_daily (profile_id, target_type, target_id, date);
```

Use Flyway migrations:

```text
V001__create_users.sql
V002__create_profiles.sql
V003__create_profile_content.sql
V004__create_media_assets.sql
V005__create_analytics.sql
V006__create_seed_tracking.sql
```

Do not rely on Flyway alone to upload binary seed assets to RustFS/S3. Use Flyway for schema and a separate idempotent seed importer for data plus object storage.

## 13. Frontend Application

### Technology

- React.
- TanStack Router.
- TanStack Query.
- TanStack Form or React Hook Form. Prefer TanStack Form if staying all-in on TanStack.
- Tailwind CSS v4.
- Vite.
- TypeScript.

### Frontend Routes

Public routes:

- `/`
  - Product home and featured profiles.
  - Should feel like the actual app, not just marketing.
- `/directory`
  - Public profile directory.
- `/$username`
  - Public profile page.
- `/analytics`
  - Public app-wide analytics.
- `/login`
- `/signup`

Authenticated routes:

- `/dashboard`
  - Overview of owned profiles.
- `/dashboard/profiles/new`
- `/dashboard/profiles/$profileId`
  - Profile editor.
- `/dashboard/profiles/$profileId/links`
- `/dashboard/profiles/$profileId/achievements`
- `/dashboard/profiles/$profileId/tags`
- `/dashboard/profiles/$profileId/media`
- `/dashboard/profiles/$profileId/analytics`
- `/settings`

### Public Profile UI Requirements

Must include:

- Banner.
- Avatar.
- Name.
- Username.
- Description.
- Bio.
- Social icons.
- Tags.
- Link cards.
- Achievement cards.
- Public analytics if enabled.
- Theme toggle or profile theme handling.
- SEO metadata and Open Graph tags.

Image rendering requirements:

- Use avatar and banner variant URLs from the API response.
- Do not render the original upload on normal profile pages.
- Avatar should use fixed dimensions/aspect ratio to prevent layout shift.
- Banner should use fixed aspect ratio, normally 3:1.
- Use `srcset` or explicit variant selection for mobile and desktop banners.
- Set meaningful alt text: `{name}'s avatar`, `{name}'s banner`.
- If media is missing, show a deterministic generated fallback using initials and the profile accent color.
- Keep OG image URL stable and absolute in metadata.

Keep from original:

- Green/purple Linkarooie identity.
- Orange achievement accent.
- Tag modal/popup behavior.
- Hidden item unlock concept.
- Directory card concept.
- Rich tags with citation and related work.

Improve from original:

- Make hidden unlock code configurable per profile.
- Use server-driven content rather than TypeScript profile files.
- Use redirect tracking for reliable link analytics.
- Use accessible dialogs for tag details.
- Avoid inline script-heavy behavior.

### Dashboard UX Requirements

Dashboard should let a user manage the profile without thinking about database objects.

Recommended editor layout:

- Left or top navigation for sections: Profile, Links, Achievements, Tags, Media, Analytics, Settings.
- Main editor panel.
- Live preview panel on desktop.
- Save state visible: saved, saving, unsaved changes, failed.

Links editor:

- Add link.
- Edit title, description, URL, icon.
- Toggle visible.
- Toggle hidden.
- Drag reorder.
- Test open URL.

Achievements editor:

- Add achievement.
- Edit title, description, URL, icon, date.
- Toggle visible.
- Toggle hidden.
- Drag reorder.

Tags editor:

- Add tag.
- Edit name, description, citation title, citation URL.
- Add/edit/remove related work.
- Drag reorder.

Analytics UI:

- Time range selector: 7 days, 30 days, 90 days.
- Profile views.
- Unique visitors.
- Link clicks.
- Top links.
- Social clicks.
- Achievement clicks.
- Tag opens.
- Public analytics preview.

## 14. Observability And Structured Logging

Full logging stack comes later, but code should be ready now.

### Structured Logging

Every request should have:

- `requestId`
- `traceId` if available
- `method`
- `path`
- `status`
- `durationMs`
- `actorUserId` when signed in
- `profileId` when relevant

Application service logs should include:

- Service name.
- Command name.
- Actor user ID.
- Target IDs.
- Outcome.
- Duration.

Example log fields:

```json
{
  "level": "INFO",
  "message": "profile.updated",
  "service": "UpdateProfileService",
  "requestId": "req_123",
  "actorUserId": "...",
  "profileId": "...",
  "durationMs": 42
}
```

Avoid:

- Logging passwords.
- Logging raw tokens.
- Logging raw IP addresses.
- Logging full request bodies for auth or media.

### Metrics Names

Prepare Micrometer metrics:

- `linkarooie.http.requests`
- `linkarooie.profile.public.cache.hit`
- `linkarooie.profile.public.cache.miss`
- `linkarooie.analytics.events.accepted`
- `linkarooie.analytics.events.rejected`
- `linkarooie.analytics.worker.processed`
- `linkarooie.analytics.worker.duplicates`
- `linkarooie.media.upload.completed`
- `linkarooie.media.upload.failed`

### Tracing

Use OpenTelemetry-compatible tracing later.

For now:

- Generate request IDs.
- Propagate request ID into Kafka event headers.
- Include request ID in logs.

## 15. Security

### Authentication

V1 options:

- Spring Session with Redis-backed sessions.
- JWT access token plus refresh token.

Recommended for lab:

- Use Spring Security with HTTP-only session cookies backed by Redis.
- Keep frontend and API on the same local origin through ingress or dev proxy.
- Do not store access tokens in `localStorage`.
- Add CSRF protection for unsafe methods if cookie auth is used.
- Use a CSRF cookie/header pattern that works with the React frontend.
- Keep JWT support as a later optional API-client feature, not the default browser login path.

### Authorization

Rules:

- Only profile owner or admin can mutate a profile.
- Public profile reads require `isPublic = true`.
- Directory only shows `isPublic = true` and `showInDirectory = true`.
- Hidden items are excluded unless an unlock path is used.
- Owner analytics requires profile ownership.
- Public analytics requires `showPublicAnalytics = true`.

### Input Validation

Validate:

- Username format.
- Email format.
- URL schemes.
- Image content type.
- Image file size.
- Text lengths.
- Icon names against an allowlist if using icon class strings.

Text length examples:

- Profile name: 1 to 80 chars.
- Username: 3 to 32 chars.
- Description: 0 to 180 chars.
- Bio: 0 to 500 chars.
- Link title: 1 to 100 chars.
- Link description: 0 to 240 chars.
- Achievement title: 1 to 140 chars.
- Tag name: 1 to 40 chars.

### Rate Limiting

Use Redis-backed limits:

- Signup attempts per IP hash.
- Login attempts per email hash and IP hash.
- Analytics events per IP hash.
- Media uploads per user.
- Public redirect clicks per IP hash.

### Privacy

Public analytics should show:

- Total views.
- Total clicks.
- Top links by count.
- Recent trend counts.

Public analytics should not show:

- Raw referrers if they could reveal private URLs.
- IPs.
- Visitor IDs.
- Exact per-visitor paths.

Owner analytics can show more, but still avoid raw identifiers.

## 16. Kubernetes And Containers

The Kubernetes cluster runs only Linkarooie application workloads.

For this lab stage, k3d should contain:

- `linkarooie-api`
- `linkarooie-analytics-worker`
- `linkarooie-web`
- Later: application jobs such as migrations, image generation, or maintenance tasks.

For this lab stage, k3d should not contain:

- PostgreSQL
- Redis
- Kafka
- RustFS
- Vault
- Jenkins

Those services remain in Docker Compose as local stand-ins for managed cloud services.

The important design constraint is configuration portability:

- Local Compose service today: `host.k3d.internal:5432`
- Managed service later: `my-rds-instance.xxxxxx.ap-southeast-2.rds.amazonaws.com:5432`
- Same Spring Boot application image.
- Same Kubernetes Deployment shape.
- Different ConfigMap/Secret values.

### Images

Publish to GitHub Container Registry:

```text
ghcr.io/<owner>/linkarooie-api:<tag>
ghcr.io/<owner>/linkarooie-analytics-worker:<tag>
ghcr.io/<owner>/linkarooie-web:<tag>
```

Tags:

- Git SHA.
- Semver when releasing.
- `main` for latest main branch build if desired.

### Runtime Configuration

Use separate configuration profiles for the two local execution modes.

Mode 1: application process runs directly on your Mac.

- API/worker can reach Compose services on `localhost`.
- Useful during early backend development with `./gradlew bootRun`.

Mode 2: application runs as pods inside k3d.

- API/worker cannot use `localhost` for Compose services, because `localhost` means the pod itself.
- API/worker should use host bridge addresses such as `host.k3d.internal`.
- This is the mode used when testing Kubernetes manifests.

Mode 3: application runs in a real environment.

- API/worker uses managed service endpoints.
- No application code change should be needed.

Local process API environment variables:

```text
SPRING_PROFILES_ACTIVE=local
SERVER_PORT=8080
DATABASE_URL=jdbc:postgresql://localhost:5432/app
DATABASE_USERNAME=app
DATABASE_PASSWORD=app
REDIS_HOST=localhost
REDIS_PORT=6379
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
S3_ENDPOINT=http://localhost:9000
S3_BUCKET=linkarooie-media-local
S3_ACCESS_KEY=rustfsadmin
S3_SECRET_KEY=rustfsadmin
S3_REGION=us-east-1
APP_PUBLIC_BASE_URL=http://localhost:3000
SESSION_COOKIE_NAME=LINKAROOIE_SESSION
CSRF_COOKIE_NAME=XSRF-TOKEN
```

k3d API environment variables:

```text
SPRING_PROFILES_ACTIVE=k3d
SERVER_PORT=8080
DATABASE_URL=jdbc:postgresql://host.k3d.internal:5432/app
DATABASE_USERNAME=app
DATABASE_PASSWORD=app
REDIS_HOST=host.k3d.internal
REDIS_PORT=6379
KAFKA_BOOTSTRAP_SERVERS=host.k3d.internal:9094
S3_ENDPOINT=http://host.k3d.internal:9000
S3_BUCKET=linkarooie-media-local
S3_ACCESS_KEY=rustfsadmin
S3_SECRET_KEY=rustfsadmin
S3_REGION=us-east-1
APP_PUBLIC_BASE_URL=http://localhost:3000
SESSION_COOKIE_NAME=LINKAROOIE_SESSION
CSRF_COOKIE_NAME=XSRF-TOKEN
```

k3d worker environment variables:

```text
SPRING_PROFILES_ACTIVE=k3d
DATABASE_URL=jdbc:postgresql://host.k3d.internal:5432/app
DATABASE_USERNAME=app
DATABASE_PASSWORD=app
REDIS_HOST=host.k3d.internal
REDIS_PORT=6379
KAFKA_BOOTSTRAP_SERVERS=host.k3d.internal:9094
```

Frontend environment variables:

```text
VITE_API_BASE_URL=/api
VITE_PUBLIC_BASE_URL=http://localhost:3000
```

For Kubernetes, prefer routing browser traffic through the frontend/API ingress so the browser calls `/api` on the same local app origin. Do not make browser code call `host.k3d.internal`; that name is for pods reaching host services, not for users' browsers.

Real environment examples:

```text
DATABASE_URL=jdbc:postgresql://<rds-endpoint>:5432/linkarooie
REDIS_HOST=<elasticache-primary-endpoint>
KAFKA_BOOTSTRAP_SERVERS=<managed-kafka-bootstrap-servers>
S3_ENDPOINT=
S3_BUCKET=linkarooie-media-prod
S3_REGION=ap-southeast-2
```

When using AWS S3 directly, `S3_ENDPOINT` can be empty or omitted and the AWS SDK should use the standard regional endpoint.

### Kubernetes Resources

Initial manifests:

- Namespace: `linkarooie`
- Deployment: `linkarooie-api`
- Service: `linkarooie-api`
- Deployment: `linkarooie-analytics-worker`
- Deployment: `linkarooie-web`
- Service: `linkarooie-web`
- ConfigMap: non-secret config.
- Secret: database password, session signing/remember-me secret if used, S3 credentials.
- Ingress: frontend and API routing.

Do not add Kubernetes `StatefulSet` resources for PostgreSQL, Redis, Kafka, or RustFS in this V1 lab. Those are intentionally external dependencies.

Health probes:

- API liveness: `/api/health`
- API readiness: `/api/ready`
- Worker liveness: Spring actuator health.
- Worker readiness: Kafka and DB connectivity.
- Web readiness: HTTP root.

## 17. Local Development Workflow

Expected flow:

1. Start supporting services.

```bash
cd supporting-services
docker compose up -d
./verify-supporting-services.sh
```

2. Start backend API locally.

```bash
cd backend
./gradlew :linkarooie-api:bootRun
```

3. Start analytics worker locally.

```bash
cd backend
./gradlew :linkarooie-analytics-worker:bootRun
```

4. Start frontend locally.

```bash
cd frontend
npm install
npm run dev
```

5. Build images.

```bash
docker build -t ghcr.io/<owner>/linkarooie-api:local -f backend/linkarooie-api/Dockerfile backend
docker build -t ghcr.io/<owner>/linkarooie-analytics-worker:local -f backend/linkarooie-analytics-worker/Dockerfile backend
docker build -t ghcr.io/<owner>/linkarooie-web:local frontend
```

6. Deploy to k3d.

```bash
kubectl apply -f deploy/k8s/local
```

At this point:

- `linkarooie-api`, `linkarooie-analytics-worker`, and `linkarooie-web` run in k3d.
- PostgreSQL, Redis, Kafka, and RustFS still run in Docker Compose.
- The k3d pods reach those Compose services through the host bridge addresses from the Kubernetes ConfigMap/Secret.

This is intentionally close to production architecture. The app workloads are in Kubernetes, while backing services are external network dependencies.

## 18. Testing Strategy

### Backend Unit Tests

Test:

- Application services.
- Domain validation.
- Username rules.
- URL validation.
- Authorization checks.
- Analytics aggregation calculations.

### Backend Integration Tests

Use Testcontainers where practical:

- PostgreSQL.
- Redis.
- Kafka.
- S3-compatible storage can be tested with MinIO or mocked for V1.

Test:

- Flyway migrations.
- Repository queries.
- Public profile read endpoint.
- Link redirect tracking.
- Kafka publish/consume flow.
- Analytics aggregation idempotency.

### Frontend Tests

Use:

- Vitest for component/unit tests.
- Playwright for key flows.

Key flows:

- Public profile renders.
- Directory renders.
- Sign-up and profile creation.
- Add/edit/reorder link.
- Public link click redirects.
- Analytics screen loads.

### Contract Tests

Generate OpenAPI from Spring.

Frontend should use generated types or a typed API client where possible.

## 19. Seed Data

Seed the original `loftwah` profile so the rebuilt app visibly matches the old product.

Seeding should be idempotent and separate from schema migrations.

Recommended approach:

- Flyway creates tables and indexes only.
- A seed importer reads `seed-data/loftwah-profile.json`.
- The importer uploads required files from `seed-assets/linkarooie` to RustFS/S3 if the checksum/object is missing.
- The importer upserts the seed user, profile, media metadata, social links, links, achievements, tags, and related work.
- The importer records the applied seed version in a `seed_runs` table.

Suggested commands:

```bash
./gradlew :linkarooie-api:bootRun --args='--app.seed=loftwah'
```

or:

```bash
./gradlew :linkarooie-seed:run --args='--fixture seed-data/loftwah-profile.json'
```

The second option is cleaner if the backend grows a small `linkarooie-seed` module.

Seed profile:

- Name: `Dean Lofts`
- Username: `loftwah`
- Description: `I like building things and making them work.`
- Bio: `Creator of Linkarooie, Senior DevOps Engineer, and part-time beat maker. Always building, always learning.`
- Social links:
  - GitHub
  - X/Twitter
  - Bluesky
  - LinkedIn
- Links:
  - My Blog
  - Linux for Pirates! 1 & 2
  - TechDeck
  - Downscope
  - Loftwah The Beatsmiff Beats
  - Produced by Loftwah The Beatsmiff
  - LoftwahFM
  - GRABIT.SH
  - Must haves in DevOps and the road to AI
  - Linux for Pirates! daily.dev squad
  - Bogan Hustler
- Hidden links:
  - CV/Resume
  - Wikipedia candidate page
- Achievements:
  - Featured in Mashable
  - HashiCorp Certified: Terraform Associate
  - Crossed 1K followers on GitHub
  - AWS Certified Solutions Architect Professional
- Tags:
  - AI/ML
  - Astro
  - AWS
  - DevOps
  - Docker
  - GitHub
  - Linux
  - Postgres
  - Python (uv)
  - Ruby on Rails
  - Terraform
  - TypeScript

Media:

- Copy existing avatar, banner, OG image, and brand assets into RustFS during seed or store as static seed assets and import once.
- Generate or import image variants as part of the seed importer.
- Verify checksums against the manifest in this spec.

## 20. Future Microservice Split

Do not split too early. Split when module boundaries are stable and there is a real reason.

Future services:

### Identity Service

Owns:

- Users.
- Auth.
- Sessions/tokens.
- Roles.

Database:

- Own schema or own DB later.

### Profile Service

Owns:

- Profiles.
- Links.
- Achievements.
- Tags.
- Directory.

### Media Service

Owns:

- Upload intents.
- Media metadata.
- S3 interaction.
- Image validation.
- OG image generation.

### Analytics Service

Owns:

- Event ingestion.
- Kafka consumers.
- Aggregates.
- Public and owner analytics queries.

### API Gateway / BFF

Owns:

- Frontend-optimized API responses.
- Auth enforcement.
- Request routing.

For V1, keep this as a modular monolith plus worker. The extraction path should be visible in package boundaries, database ownership comments, event schemas, and DTO boundaries.

## 21. Implementation Milestones

### Milestone 1: Backend Foundation

- Create Gradle multi-project backend.
- Add Spring Boot API.
- Add PostgreSQL connection.
- Add Flyway.
- Add health endpoints.
- Add structured logging request ID filter.
- Add base exception handling with ProblemDetail.

### Milestone 2: Users And Auth

- User table.
- Sign-up.
- Login.
- Authenticated `/api/me`.
- Password hashing.
- Spring Security session auth backed by Redis.
- CSRF support for unsafe API methods.

### Milestone 3: Profiles

- Profile table.
- Profile CRUD.
- Username validation.
- Public profile endpoint.
- Directory endpoint.
- Seed `loftwah`.

### Milestone 4: Content Management

- Social links.
- Links.
- Achievements.
- Tags.
- Related work.
- Reordering.
- Visibility and hidden flags.

### Milestone 5: Media

- RustFS/S3 client.
- Avatar upload.
- Banner upload.
- Media metadata.
- Profile media rendering.

### Milestone 6: Analytics Pipeline

- Kafka topic.
- Analytics event DTO.
- API event ingestion.
- Link redirect tracking.
- Analytics worker.
- Daily aggregate tables.
- Redis hot counters.

### Milestone 7: Frontend Public App

- TanStack Router.
- Tailwind v4.
- Public home.
- Directory.
- Public profile page.
- Public analytics components.

### Milestone 8: Frontend Dashboard

- Sign-up/login.
- Dashboard shell.
- Profile editor.
- Links editor.
- Achievements editor.
- Tags editor.
- Media editor.
- Owner analytics page.

### Milestone 9: Containers And k3d

- Dockerfile for API.
- Dockerfile for worker.
- Dockerfile for frontend.
- Push to GHCR.
- Kubernetes namespace, deployments, services, config, secrets.
- Verify app can run in k3d while using Docker Compose supporting services.

## 22. Coding Standards

### General

- One primary responsibility per file.
- Keep controllers thin.
- Keep application services small.
- Prefer explicit command/result records.
- Prefer immutable DTOs.
- Prefer constructor injection.
- Avoid static utility dumping grounds.
- Avoid generic `Manager` classes.
- Avoid leaking JPA entities to API responses.

### Java

- Use modern Java supported by current Spring Boot baseline.
- Use records for DTOs and commands where suitable.
- Use `OffsetDateTime` or `Instant` for timestamps.
- Use `UUID` for internal IDs.
- Use Bean Validation annotations on request DTOs.
- Use `@Transactional` at application service boundary.

### Database

- Every schema change is a Flyway migration.
- Migrations should be deterministic.
- Avoid relying on Hibernate auto-DDL outside tests.
- Add indexes with the feature that needs them.

### Frontend

- Use generated API types where practical.
- Keep route components focused.
- Extract reusable editor components.
- Use TanStack Query for server state.
- Keep form state local to forms.
- Avoid duplicating API response shapes manually across the app.
- Use accessible dialogs, menus, and controls.

### Logging

- Log facts, not paragraphs.
- Include request ID.
- Include profile ID/user ID when relevant.
- Do not log secrets.

## 23. Open Questions

These can be decided during implementation:

- Should each user be limited to one profile in V1 UI, even if the backend supports many?
- Should public analytics be enabled by default or opt-in?
- Should the hidden unlock code be global per profile or per hidden item?
- Should owner analytics include referrer domains in V1?
- Should Open Graph images be uploaded manually first and generated later?
- Should custom domains be a future feature?

## 24. Recommended V1 Answer To Open Questions

- Backend supports multiple profiles per user; UI starts with one primary profile.
- Public analytics is opt-in per profile.
- Media upload uses API multipart first, then presigned URLs later if desired.
- Public media is returned as stable application URLs that redirect to short-lived signed RustFS/S3 URLs.
- Hidden unlock code is one profile-level code.
- Owner analytics includes normalized referrer domains, not full referrer URLs.
- OG image starts as uploaded media; generation becomes a Kafka-backed job later.
- Custom domains are future scope.

## 25. Definition Of Done For V1

V1 is done when:

- A new user can sign up.
- The user can create and publish a profile.
- The profile can include avatar, banner, social links, tags, links, achievements, and related work.
- A public visitor can view `/{username}`.
- A public visitor can click links through tracked redirects.
- Analytics events flow through Kafka.
- Analytics aggregates are visible to the owner.
- Public analytics can be enabled on the profile.
- Public directory lists eligible profiles.
- API, analytics worker, and frontend run locally.
- API, analytics worker, and frontend build as containers.
- Images can be pushed to GHCR.
- The app can run in k3d while using PostgreSQL, Redis, Kafka, and RustFS from Docker Compose.
- Logs include request IDs and useful structured fields.
- The old `loftwah` profile exists as seed/demo data.

## 26. Standalone Legacy Source Inventory

This section exists so the lab spec can be moved away from the original Astro repository and still preserve the original Linkarooie product details.

The original project is a static Astro app with this important source layout:

```text
src/
  pages/
    index.astro
    [username].astro
  data/
    index.ts
    profiles/
      loftwah.ts
  types/
    index.ts
  components/
    ProfileCard.astro
    LinkCard.astro
    AchievementCard.astro
    Directory.astro
  layouts/
    Layout.astro
  styles/
    global.css
  assets/
    background.svg
    astro.svg
    images/
      hero.png
      icon.png
      linkarooie-meme.jpg
      linkarooie.jpg
      linkarooie_og.jpg
      linkarooie_og_light.jpg
      loftwah_avatar.jpg
      loftwah_banner.jpg
      loftwah_og.jpg
public/
  fonts/
    Inter-Regular.ttf
    Inter-Bold.ttf
    Inter-Regular.woff2
    Inter-Bold.woff2
  favicon.ico
  favicon-16x16.png
  favicon-32x32.png
  android-chrome-192x192.png
  android-chrome-512x512.png
  apple-touch-icon.png
  site.webmanifest
scripts/
  generate-og-image.ts
  generate-main-og-image.ts
```

Original TypeScript model:

```ts
export interface SocialLink {
  platform: "github" | "twitter" | "x-twitter" | "bluesky" | "linkedin";
  url: string;
}

export interface Link {
  id: string;
  title: string;
  description: string;
  url: string;
  icon: string;
  hidden?: boolean;
}

export interface Achievement {
  id: string;
  title: string;
  description: string;
  date: string;
  url: string;
  icon: string;
  showFullDate?: boolean;
  hidden?: boolean;
}

export interface RelatedWork {
  title: string;
  url: string;
  description: string;
}

export interface Citation {
  title?: string;
  url: string;
}

export interface Tag {
  name: string;
  description?: string;
  citation?: Citation;
  related_work?: RelatedWork[];
}

export interface Profile {
  name: string;
  username: string;
  description: string;
  avatarUrl: string | ImageMetadata;
  bannerUrl: string | ImageMetadata;
  ogImageUrl: string | ImageMetadata;
  ogTitle: string;
  ogDescription: string;
  bio: string;
  tags: Tag[];
  isPublic: boolean;
  showInDirectory: boolean;
  socialLinks: SocialLink[];
  links: Link[];
  achievements: Achievement[];
}
```

Backend model mapping:

- `Profile.avatarUrl`, `Profile.bannerUrl`, and `Profile.ogImageUrl` become `MediaAsset` rows referenced by `profiles.avatar_media_id`, `profiles.banner_media_id`, and `profiles.og_media_id`.
- `Profile.tags[].citation` becomes nullable columns on `tags`: `citation_title`, `citation_url`.
- `Profile.tags[].related_work[]` becomes rows in `related_work`.
- `Link.hidden` becomes `links.is_hidden`.
- `Achievement.hidden` becomes `achievements.is_hidden`.
- `Achievement.date` should be stored as both a display string and, when parseable, a structured date.
- `Link.id` and `Achievement.id` from the static project become stable `legacy_key` or `public_slug` values. Keep them in the database so seed data is deterministic.
- FontAwesome icon class strings can be stored directly in V1 as `icon`. Add an allowlist later if abuse becomes a concern.

Original visual/product constants:

- Brand name: `Linkarooie`.
- Main dark accent: `#a5fd0e`.
- Main light accent / purple: `#9333ea`.
- OG generation light purple: `#9233ea`.
- Achievement accent: `#ff9500`.
- Dark page background family: gray 900 / gray 800.
- Light page background family: gray 100 / gray 200.
- Font family: Inter.
- Public profile route: `/{username}`.
- Directory source rule: `isPublic = true` and `showInDirectory = true`.
- Hidden item unlock code in the original app: `iddqd`.
- Hidden item unlock originally only triggers for the `loftwah` profile.

Original page behavior to preserve:

- The home page shows a hero, product framing, and featured public directory profiles.
- The public profile page shows banner, centered avatar, name, username, description, bio, social links, tags, links, achievements, and modals for rich tag details.
- Link cards and achievement cards are centered, stacked, and clickable.
- Hidden links and achievements are not rendered as normal public cards.
- Hidden items are revealed by typing the unlock code.
- Tag buttons open a modal containing tag description, citation link, and related work.
- Public links include tracking attributes in the old app; in the rebuild, they should route through tracked redirects.
- The layout includes a dark/light toggle with local preference persistence.
- Open Graph metadata should use profile-level title, description, and image when present.

## 27. Required Media And Static Asset Manifest

The Markdown spec cannot usefully embed large binary images. To rebuild the app 1-for-1, copy these assets from the old Linkarooie repo into the lab repo before the old repo is no longer available.

Recommended lab location:

```text
seed-assets/linkarooie/
  images/
    background.svg
    astro.svg
    hero.png
    icon.png
    linkarooie-meme.jpg
    linkarooie.jpg
    linkarooie_og.jpg
    linkarooie_og_light.jpg
    loftwah_avatar.jpg
    loftwah_banner.jpg
    loftwah_og.jpg
  favicons/
    favicon.ico
    favicon-16x16.png
    favicon-32x32.png
    android-chrome-192x192.png
    android-chrome-512x512.png
    apple-touch-icon.png
    site.webmanifest
  fonts/
    Inter-Regular.ttf
    Inter-Bold.ttf
    Inter-Regular.woff2
    Inter-Bold.woff2
```

Asset pack export command from the old repo:

```bash
mkdir -p seed-assets/linkarooie/images seed-assets/linkarooie/favicons seed-assets/linkarooie/fonts
cp src/assets/background.svg seed-assets/linkarooie/images/background.svg
cp src/assets/astro.svg seed-assets/linkarooie/images/astro.svg
cp src/assets/images/* seed-assets/linkarooie/images/
cp public/favicon.ico public/favicon-16x16.png public/favicon-32x32.png seed-assets/linkarooie/favicons/
cp public/android-chrome-192x192.png public/android-chrome-512x512.png public/apple-touch-icon.png public/site.webmanifest seed-assets/linkarooie/favicons/
cp public/fonts/* seed-assets/linkarooie/fonts/
tar -czf linkarooie-seed-assets.tgz seed-assets/linkarooie
```

The lab repo should commit `seed-assets/linkarooie` if the goal is fully reproducible local seeding. If you do not want binary seed assets in Git, store `linkarooie-seed-assets.tgz` in object storage or attach it to the lab release and keep the manifest below in Git.

Required media files:

| Source file                                 |                                              Purpose | Dimensions |                           Format | SHA-256                                                            |
| ------------------------------------------- | ---------------------------------------------------: | ---------: | -------------------------------: | ------------------------------------------------------------------ |
| `src/assets/background.svg`                 |                         Home hero background pattern |  1440x1024 |                              SVG | `a2c94dccaf7921a18dcacdbc39137955c827d60befc9490fdbc838fc090ecd84` |
| `src/assets/astro.svg`                      | Original Astro starter asset, not required for V1 UI |     115x48 |                              SVG | `f6acc666531071302a93230b4d36ada513eb3743e5550e136caffb3bb6c50105` |
| `src/assets/images/loftwah_avatar.jpg`      |                                  Seed profile avatar |    400x400 |                             JPEG | `4f4a75d01bf6c04bf55d04c515b2078b43977a9e6634c27b6eabd7d316e260b5` |
| `src/assets/images/loftwah_banner.jpg`      |                                  Seed profile banner |   1500x500 |                             JPEG | `f13b455fbaa31199094fcb77533a36f1068fcdefc098850325e7956c554798fa` |
| `src/assets/images/loftwah_og.jpg`          |                                Seed profile OG image |   1200x630 | PNG data despite `.jpg` filename | `928315b2398353c3dbb983dbeb5754d74e876a0b52766717c2563a167f326728` |
| `src/assets/images/icon.png`                |                                        App icon/logo |    192x192 |                              PNG | `14335e278295a9593f344ae8c1fb1ddb6f18723e2a4c1ebdd188a17f756eaebb` |
| `src/assets/images/hero.png`                |                                    Home hero preview |  1024x1024 |                              PNG | `8db366ca934a9f7bd99f3ce1517b14012d7c3c850e0afbd123e568868f4e31dc` |
| `src/assets/images/linkarooie.jpg`          |                            Main OG source/background |   1280x720 |                             JPEG | `56ae3d14d468fb4163b34035a73bfd5960c679759f3252926b1e361c7a65a360` |
| `src/assets/images/linkarooie_og.jpg`       |                                   Main dark OG image |   1200x630 |                             JPEG | `eb8deb14f097c24f0917d32ffedf040e148484782650d620220cd9da20c7bbbb` |
| `src/assets/images/linkarooie_og_light.jpg` |                                  Main light OG image |   1200x630 |                             JPEG | `f128622f4ac50141631d8288cea4cc70287c6c5d53e0dbff16b966399a3beb23` |
| `src/assets/images/linkarooie-meme.jpg`     |                                    Extra brand image |  1024x1024 |                             JPEG | `3d9b6ad3ea304a2702343bc0e4aefac1b1be97fa283495f91825227fdffff60c` |

Required favicon/static files:

| Source file                         |      Dimensions/type | SHA-256                                                            |
| ----------------------------------- | -------------------: | ------------------------------------------------------------------ |
| `public/favicon.ico`                | ICO, 16x16 and 32x32 | `6bfefa3b751d1af17ecb3cf5c6c2d7c5060dbd5b196515f3a831e2011523c377` |
| `public/favicon-16x16.png`          |            16x16 PNG | `3a882bdd4c16fc973933d22c7870e335a8374456b5d75f238b9cf3020d2b9c02` |
| `public/favicon-32x32.png`          |            32x32 PNG | `bad30402976a8022a39b952501576f5e1978a24034b5c1d475e0a4e5f118f67b` |
| `public/android-chrome-192x192.png` |          192x192 PNG | `14335e278295a9593f344ae8c1fb1ddb6f18723e2a4c1ebdd188a17f756eaebb` |
| `public/android-chrome-512x512.png` |          512x512 PNG | `87f4a88a792ff3dd728b038497e0bb67106ed8caba9d249de8292661458c4c67` |
| `public/apple-touch-icon.png`       |          180x180 PNG | `f5ab3fe20f14c2cbaa61973f644dad3c5239861b703ac846b55194ba723abe17` |
| `public/site.webmanifest`           |    Web manifest JSON | `7a9e07ce1f7386689917602ddc5a75750ad842e605ff764f67173529c181bf04` |

Required font files:

| Source file                        |     Type | SHA-256                                                            |
| ---------------------------------- | -------: | ------------------------------------------------------------------ |
| `public/fonts/Inter-Regular.ttf`   | TrueType | `40d692fce188e4471e2b3cba937be967878f631ad3ebbbdcd587687c7ebe0c82` |
| `public/fonts/Inter-Bold.ttf`      | TrueType | `288316099b1e0a47a4716d159098005eef7c0066921f34e3200393dbdb01947f` |
| `public/fonts/Inter-Regular.woff2` |    WOFF2 | `e06f6b1bc553aaea4e4668023ed0ab0a147129c3107f511bc7d03d361b0ae085` |
| `public/fonts/Inter-Bold.woff2`    |    WOFF2 | `fa888127b6da015b65569f0351f3b5c391ad928904951f1c20e9f8462a8d95ea` |

Original `site.webmanifest`:

```json
{
  "name": "",
  "short_name": "",
  "icons": [
    {
      "src": "/android-chrome-192x192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/android-chrome-512x512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ],
  "theme_color": "#ffffff",
  "background_color": "#ffffff",
  "display": "standalone"
}
```

### RustFS/S3 Storage Plan For Seed Assets

Create bucket:

```text
linkarooie-media-local
```

Upload profile media objects:

| Logical asset           | Source asset                                            | RustFS object key                            | DB `purpose` | Content type    |
| ----------------------- | ------------------------------------------------------- | -------------------------------------------- | ------------ | --------------- |
| Loftwah avatar          | `seed-assets/linkarooie/images/loftwah_avatar.jpg`      | `profiles/loftwah/avatar/loftwah_avatar.jpg` | `AVATAR`     | `image/jpeg`    |
| Loftwah banner          | `seed-assets/linkarooie/images/loftwah_banner.jpg`      | `profiles/loftwah/banner/loftwah_banner.jpg` | `BANNER`     | `image/jpeg`    |
| Loftwah OG image        | `seed-assets/linkarooie/images/loftwah_og.jpg`          | `profiles/loftwah/og/loftwah_og.png`         | `OG_IMAGE`   | `image/png`     |
| App icon                | `seed-assets/linkarooie/images/icon.png`                | `brand/icon.png`                             | `BRAND`      | `image/png`     |
| Home hero               | `seed-assets/linkarooie/images/hero.png`                | `brand/hero.png`                             | `BRAND`      | `image/png`     |
| Home background pattern | `seed-assets/linkarooie/images/background.svg`          | `brand/background.svg`                       | `BRAND`      | `image/svg+xml` |
| Main dark OG            | `seed-assets/linkarooie/images/linkarooie_og.jpg`       | `brand/og/linkarooie_og_dark.jpg`            | `BRAND_OG`   | `image/jpeg`    |
| Main light OG           | `seed-assets/linkarooie/images/linkarooie_og_light.jpg` | `brand/og/linkarooie_og_light.jpg`           | `BRAND_OG`   | `image/jpeg`    |

For V1, favicons and fonts can be bundled into the frontend image under `public/` rather than uploaded to RustFS.

Seed `media_assets` rows should preserve:

- Original filename.
- Bucket.
- Object key.
- Content type.
- Byte size if available at import time.
- SHA-256 checksum from the manifest above.
- Purpose.
- Owner user ID.
- Profile ID where applicable.

If the old binary assets are not available, create placeholder files with the same logical roles and dimensions. Do not block application development on exact images, but keep the same DB fields and object key structure.

## 28. Exact Loftwah Seed Profile Fixture

This JSON is the canonical V1 seed fixture. It should be enough to recreate the original public profile content without reading the old TypeScript file.

Implementation rule:

- Insert the user first.
- Insert the profile second.
- Insert media assets and update profile media references.
- Insert social links, links, achievements, tags, and related work in the order shown.
- Preserve each `legacyKey`.
- Set `displayOrder` using the array order starting at `0`.
- For hidden items, set `isHidden = true` and `isVisible = true`; the public profile endpoint should still omit them until unlocked.

```json
{
  "seedVersion": 1,
  "user": {
    "legacyKey": "loftwah-user",
    "email": "loftwah@example.local",
    "displayName": "Dean Lofts",
    "role": "USER",
    "status": "ACTIVE"
  },
  "profile": {
    "legacyKey": "loftwah-profile",
    "username": "loftwah",
    "name": "Dean Lofts",
    "description": "I like building things and making them work.",
    "bio": "Creator of Linkarooie, Senior DevOps Engineer, and part-time beat maker. Always building, always learning.",
    "ogTitle": "Dean Lofts (Loftwah) - Single Dad and Senior DevOps Engineer",
    "ogDescription": "I create, ship, and connect ideas. DevOps engineer, product builder, and music maker. All my projects and links in one place.",
    "theme": "SYSTEM",
    "accentColor": "#a5fd0e",
    "isPublic": true,
    "showInDirectory": true,
    "showPublicAnalytics": true,
    "hiddenUnlockCode": "iddqd",
    "media": {
      "avatar": {
        "sourceFile": "seed-assets/linkarooie/images/loftwah_avatar.jpg",
        "bucket": "linkarooie-media-local",
        "objectKey": "profiles/loftwah/avatar/loftwah_avatar.jpg",
        "contentType": "image/jpeg",
        "sha256": "4f4a75d01bf6c04bf55d04c515b2078b43977a9e6634c27b6eabd7d316e260b5"
      },
      "banner": {
        "sourceFile": "seed-assets/linkarooie/images/loftwah_banner.jpg",
        "bucket": "linkarooie-media-local",
        "objectKey": "profiles/loftwah/banner/loftwah_banner.jpg",
        "contentType": "image/jpeg",
        "sha256": "f13b455fbaa31199094fcb77533a36f1068fcdefc098850325e7956c554798fa"
      },
      "ogImage": {
        "sourceFile": "seed-assets/linkarooie/images/loftwah_og.jpg",
        "bucket": "linkarooie-media-local",
        "objectKey": "profiles/loftwah/og/loftwah_og.png",
        "contentType": "image/png",
        "sha256": "928315b2398353c3dbb983dbeb5754d74e876a0b52766717c2563a167f326728"
      }
    }
  },
  "socialLinks": [
    {
      "legacyKey": "github",
      "platform": "github",
      "url": "https://github.com/loftwah",
      "isVisible": true
    },
    {
      "legacyKey": "x-twitter",
      "platform": "x-twitter",
      "url": "https://twitter.com/loftwah",
      "isVisible": true
    },
    {
      "legacyKey": "bluesky",
      "platform": "bluesky",
      "url": "https://bsky.app/profile/loftwah.bsky.social",
      "isVisible": true
    },
    {
      "legacyKey": "linkedin",
      "platform": "linkedin",
      "url": "https://linkedin.com/in/deanlofts",
      "isVisible": true
    }
  ],
  "links": [
    {
      "legacyKey": "blog",
      "title": "My Blog",
      "description": "Posts, guides, and notes on what I am building.",
      "url": "https://blog.deanlofts.xyz",
      "icon": "fa-solid fa-blog",
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "lfp",
      "title": "Linux for Pirates! 1 & 2",
      "description": "Home of Linux for Pirates and Ruby on Whales.",
      "url": "https://linuxforpirates.deanlofts.xyz",
      "icon": "fa-solid fa-terminal",
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "techdeck",
      "title": "TechDeck",
      "description": "AI generated trading cards for tech profiles with stats and moves.",
      "url": "https://techdeck.life",
      "icon": "fa-solid fa-id-card",
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "downscope",
      "title": "Downscope",
      "description": "A short story about a chaotic couple of days at a SaaS company.",
      "url": "https://downscope.deanlofts.xyz",
      "icon": "fa-solid fa-book",
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "beats",
      "title": "Loftwah The Beatsmiff Beats",
      "description": "A big playlist of beats I have made over the years.",
      "url": "https://www.youtube.com/playlist?list=PLKBAUoCO_FtlACntcZqTOD4hckJ8IAWZ3",
      "icon": "fa-solid fa-music",
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "produced",
      "title": "Produced by Loftwah The Beatsmiff",
      "description": "Music I produced for other artists and projects.",
      "url": "https://www.youtube.com/playlist?list=PLKBAUoCO_FtkHiwRzyGzfhauIhNMBFw66",
      "icon": "fa-solid fa-music",
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "loftwahfm",
      "title": "LoftwahFM",
      "description": "My music hub. Originals, remixes, playlists, and AI experiments in one place.",
      "url": "https://fm.loftwah.com",
      "icon": "fa-solid fa-headphones",
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "grabit",
      "title": "GRABIT.SH",
      "description": "CLI that pulls key info from repos so you can summarise and prompt faster.",
      "url": "https://grabit.sh",
      "icon": "fa-solid fa-magnifying-glass",
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "must-haves",
      "title": "Must haves in DevOps and the road to AI",
      "description": "My running list of tools, practices, and AI ideas for modern DevOps.",
      "url": "https://www.makethelist.io/d/devops-must-haves",
      "icon": "fa-solid fa-list",
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "linux-pirates",
      "title": "Linux for Pirates! My daily.dev squad",
      "description": "Join the squad and learn Linux together on daily.dev.",
      "url": "https://dly.to/3R9tSuu9oHB",
      "icon": "fa-solid fa-code",
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "bogan-hustler",
      "title": "Bogan Hustler",
      "description": "Dope Wars reimagined for Straya.",
      "url": "https://boganhustler.deanlofts.xyz",
      "icon": "fa-solid fa-people-robbery",
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "cv",
      "title": "My CV/Resume",
      "description": "Full work history, skills, and achievements.",
      "url": "https://gist.github.com/loftwah/43d0d27be586ebe2c95df99657121a8b",
      "icon": "fa-solid fa-file-alt",
      "isVisible": true,
      "isHidden": true
    },
    {
      "legacyKey": "wikipedia",
      "title": "I'm in Wikipedia lol",
      "description": "I once ran in a state election in WA. They handled the logistics and I learned a lot. Now I am listed on the candidates page.",
      "url": "https://en.wikipedia.org/wiki/Candidates_of_the_2021_Western_Australian_state_election",
      "icon": "fa-solid fa-landmark",
      "isVisible": true,
      "isHidden": true
    }
  ],
  "achievements": [
    {
      "legacyKey": "mashable",
      "title": "Featured in Mashable",
      "description": "Quoted in a roundup on the CrowdStrike outage. A moment of internet chaos and memes.",
      "displayDate": "19 Jul 2024",
      "achievedOn": "2024-07-19",
      "url": "https://mashable.com/article/crowdstrike-outage-reactions",
      "icon": "fa-solid fa-lock",
      "showFullDate": false,
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "terraform",
      "title": "HashiCorp Certified: Terraform Associate (003)",
      "description": "Understands Terraform basics, workflows, and when to choose Enterprise for bigger teams.",
      "displayDate": "18 Apr 2024",
      "achievedOn": "2024-04-18",
      "url": "https://www.credly.com/badges/0e437888-1deb-4a2d-8b82-cefb6b87b35d/public_url",
      "icon": "fa-solid fa-cloud",
      "showFullDate": false,
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "github-followers",
      "title": "Crossed 1K followers on GitHub",
      "description": "Hit 1000 followers on GitHub.",
      "displayDate": "12 Jul 2023",
      "achievedOn": "2023-07-12",
      "url": "https://github.com/loftwah?tab=achievements",
      "icon": "fa-brands fa-github",
      "showFullDate": false,
      "isVisible": true,
      "isHidden": false
    },
    {
      "legacyKey": "aws-certified",
      "title": "AWS Certified Solutions Architect – Professional",
      "description": "Designs complex systems across services and providers and knows the trade offs that matter.",
      "displayDate": "12 Jul 2023",
      "achievedOn": "2023-07-12",
      "url": "https://www.credly.com/badges/c97a35fc-ba6b-427a-b521-19b9ab28cfdb/facebook",
      "icon": "fa-brands fa-aws",
      "showFullDate": false,
      "isVisible": true,
      "isHidden": false
    }
  ],
  "tags": [
    {
      "name": "AI/ML",
      "description": "Using AI to build tools, solve problems, and automate boring stuff. ML helps the models get better by learning from data.",
      "citation": {
        "title": "What is Artificial Intelligence?",
        "url": "https://www.ibm.com/topics/artificial-intelligence"
      },
      "relatedWork": [
        {
          "title": "Build a Powerful Product Catalog Explorer with LangChain, Ollama, and Gradio",
          "url": "https://blog.deanlofts.xyz/blog/rag-product-catalog/",
          "description": "A product catalog explorer powered by AI search and RAG."
        },
        {
          "title": "Auto Jira",
          "url": "https://github.com/loftwah/auto-jira",
          "description": "Automating Jira tasks with AI helpers."
        },
        {
          "title": "Unlocking the Power of GGUF Models Locally with Ollama",
          "url": "https://blog.deanlofts.xyz/blog/ollama/",
          "description": "Run local language models with Ollama and GGUF."
        },
        {
          "title": "English-Chinese Translator for Markdown",
          "url": "https://github.com/loftwah/eng-cn-translate",
          "description": "Translate Markdown between English and Simplified Chinese."
        },
        {
          "title": "Fantasy Basketball Tools",
          "url": "https://github.com/loftwah/langchain-csv/tree/main/nba",
          "description": "AI assisted fantasy basketball analysis."
        },
        {
          "title": "Hoops Hustler",
          "url": "https://github.com/loftwah/hoops-hustler",
          "description": "NBA team comparison with live stats and AI generated insights."
        }
      ]
    },
    {
      "name": "Astro",
      "description": "Fast sites with minimal client JavaScript. Great for content and works well with React or Vue when needed.",
      "citation": {
        "title": "Astro: Build Faster Websites",
        "url": "https://astro.build/"
      },
      "relatedWork": [
        {
          "title": "Linkarooie",
          "url": "https://linkarooie.com/",
          "description": "Open source link in bio built with Astro."
        },
        {
          "title": "My Blog",
          "url": "https://blog.deanlofts.xyz/",
          "description": "Personal blog powered by Astro."
        },
        {
          "title": "Building an Astro 5 App with Cloudflare Pages and D1",
          "url": "https://blog.deanlofts.xyz/guides/astro-cloudflare/",
          "description": "Guide to shipping Astro on Cloudflare Pages with D1."
        }
      ]
    },
    {
      "name": "AWS",
      "description": "My main cloud for hosting, scaling, storage, and data. I use it to run apps, queues, and automation at scale.",
      "citation": {
        "title": "What is AWS?",
        "url": "https://aws.amazon.com/what-is-aws/"
      },
      "relatedWork": [
        {
          "title": "Loftwah's Guide to Managing Terraform for AWS ECS Fargate Deployments with HTTPS",
          "url": "https://blog.deanlofts.xyz/guides/managing-terraform-ecs/",
          "description": "My process for deploying to ECS with Terraform and HTTPS."
        }
      ]
    },
    {
      "name": "DevOps",
      "description": "Build, test, ship, and observe. I automate releases and keep systems reliable so teams can move faster.",
      "citation": {
        "title": "What is DevOps?",
        "url": "https://aws.amazon.com/devops/what-is-devops/"
      },
      "relatedWork": [
        {
          "title": "Deploying FastAPI with UV, Nginx, and AWS ECS: A Step-by-Step Guide",
          "url": "https://blog.deanlofts.xyz/guides/uv-fastapi-ecs/",
          "description": "Deploying Python apps on AWS with a clean pipeline."
        }
      ]
    },
    {
      "name": "Docker",
      "description": "Portable containers so apps run the same everywhere. My default for local dev and production services.",
      "citation": {
        "title": "What is Docker?",
        "url": "https://www.docker.com/what-is-docker/"
      },
      "relatedWork": [
        {
          "title": "Mastering UV with Python and Docker: A Comprehensive Guide to Modern Python Development",
          "url": "https://blog.deanlofts.xyz/guides/uv-python-docker/",
          "description": "Modern Python workflow with Docker and UV."
        }
      ]
    },
    {
      "name": "GitHub",
      "description": "Code, issues, pull requests, and automation with Actions. Home base for my open source work.",
      "citation": {
        "title": "About GitHub",
        "url": "https://github.com/about"
      },
      "relatedWork": [
        {
          "title": "My GitHub profile",
          "url": "https://github.com/loftwah",
          "description": "All my repos in one place."
        }
      ]
    },
    {
      "name": "Linux",
      "description": "Daily driver for development and servers. Stable, secure, and customizable.",
      "citation": {
        "title": "What is Linux?",
        "url": "https://www.linux.org/pages/what-is-linux/"
      },
      "relatedWork": [
        {
          "title": "Linux for Pirates!",
          "url": "https://loftwah.github.io/linux-for-pirates/",
          "description": "A fun way to learn Linux basics and beyond."
        }
      ]
    },
    {
      "name": "Postgres",
      "description": "Solid relational database with great performance and features. My default choice for app data.",
      "citation": {
        "title": "About PostgreSQL",
        "url": "https://www.postgresql.org/about/"
      },
      "relatedWork": []
    },
    {
      "name": "Python (uv)",
      "description": "Python for scripts and backends. UV is a fast package manager that speeds up installs and builds.",
      "citation": {
        "title": "uv: Python Package Management",
        "url": "https://astral.sh/uv"
      },
      "relatedWork": [
        {
          "title": "Deploying FastAPI with UV, Nginx, and AWS ECS: A Step-by-Step Guide",
          "url": "https://blog.deanlofts.xyz/guides/uv-fastapi-ecs/",
          "description": "Using UV to speed up Python deployments."
        }
      ]
    },
    {
      "name": "Ruby on Rails",
      "description": "Framework that lets me build features fast. Strong conventions and a clean ecosystem.",
      "citation": {
        "title": "Ruby on Rails: A Web Framework",
        "url": "https://rubyonrails.org/"
      },
      "relatedWork": [
        {
          "title": "Linux for Pirates! 2 Ruby on Whales",
          "url": "https://linuxforpirates.deanlofts.xyz/ruby-on-whales/",
          "description": "Running Rails with Docker in a simple setup."
        }
      ]
    },
    {
      "name": "Terraform",
      "description": "Infrastructure as code so cloud resources live in version control and are easy to repeat.",
      "citation": {
        "title": "Introduction to Terraform",
        "url": "https://www.terraform.io/intro"
      },
      "relatedWork": [
        {
          "title": "A demo repo of using UV and FastAPI with Docker on AWS ECS",
          "url": "https://github.com/loftwah/uv-fastapi-ecs",
          "description": "Example Terraform for a FastAPI app on AWS."
        }
      ]
    },
    {
      "name": "TypeScript",
      "description": "JavaScript with types. Safer refactors and better tooling for bigger projects.",
      "citation": {
        "title": "TypeScript: JavaScript with Syntax for Types",
        "url": "https://www.typescriptlang.org/"
      },
      "relatedWork": [
        {
          "title": "🏴‍☠️ Buccaneer's Training Manual: TypeScript & Bun Exercises",
          "url": "https://blog.deanlofts.xyz/guides/typescript-exercises/",
          "description": "Hands on TypeScript practice using Bun."
        }
      ]
    }
  ]
}
```

## 29. Database Columns Needed To Preserve Legacy Data

The earlier domain model is the conceptual model. This section lists concrete columns needed so none of the old profile data gets lost.

### `users`

Required columns:

- `id uuid primary key`
- `legacy_key text unique`
- `email text not null`
- `email_verified_at timestamptz null`
- `password_hash text null`
- `display_name text not null`
- `role text not null`
- `status text not null`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

Seed notes:

- The seed user can use a disabled local password or a generated dev-only password.
- Do not ship a known production password.

### `profiles`

Required columns:

- `id uuid primary key`
- `legacy_key text unique`
- `owner_user_id uuid not null references users(id)`
- `username text not null`
- `name text not null`
- `description text not null`
- `bio text not null`
- `avatar_media_id uuid null references media_assets(id)`
- `banner_media_id uuid null references media_assets(id)`
- `og_media_id uuid null references media_assets(id)`
- `og_title text null`
- `og_description text null`
- `theme text not null default 'SYSTEM'`
- `accent_color text null`
- `is_public boolean not null default false`
- `show_in_directory boolean not null default false`
- `show_public_analytics boolean not null default false`
- `hidden_unlock_code_hash text null`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

### `media_assets`

Required columns:

- `id uuid primary key`
- `legacy_key text unique`
- `owner_user_id uuid not null references users(id)`
- `profile_id uuid null references profiles(id)`
- `bucket text not null`
- `object_key text not null`
- `original_filename text not null`
- `content_type text not null`
- `byte_size bigint null`
- `sha256 text null`
- `width integer null`
- `height integer null`
- `purpose text not null`
- `visibility text not null default 'PRIVATE'`
- `status text not null`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

### `media_variants`

Required columns:

- `id uuid primary key`
- `media_asset_id uuid not null references media_assets(id)`
- `variant text not null`
- `bucket text not null`
- `object_key text not null`
- `content_type text not null`
- `byte_size bigint null`
- `sha256 text null`
- `width integer not null`
- `height integer not null`
- `created_at timestamptz not null`

### `seed_runs`

Required columns:

- `id uuid primary key`
- `seed_name text not null`
- `seed_version integer not null`
- `fixture_sha256 text null`
- `applied_at timestamptz not null`
- `status text not null`
- `message text null`

Unique constraint:

- `(seed_name, seed_version)`

### `social_links`

Required columns:

- `id uuid primary key`
- `legacy_key text null`
- `profile_id uuid not null references profiles(id)`
- `platform text not null`
- `url text not null`
- `display_order integer not null`
- `is_visible boolean not null default true`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

### `links`

Required columns:

- `id uuid primary key`
- `legacy_key text null`
- `profile_id uuid not null references profiles(id)`
- `public_id text not null unique`
- `title text not null`
- `description text not null`
- `url text not null`
- `icon text not null`
- `display_order integer not null`
- `is_visible boolean not null default true`
- `is_hidden boolean not null default false`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

### `achievements`

Required columns:

- `id uuid primary key`
- `legacy_key text null`
- `profile_id uuid not null references profiles(id)`
- `public_id text not null unique`
- `title text not null`
- `description text not null`
- `url text not null`
- `icon text not null`
- `display_date text not null`
- `achieved_on date null`
- `show_full_date boolean not null default false`
- `display_order integer not null`
- `is_visible boolean not null default true`
- `is_hidden boolean not null default false`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

### `tags`

Required columns:

- `id uuid primary key`
- `profile_id uuid not null references profiles(id)`
- `name text not null`
- `description text null`
- `citation_title text null`
- `citation_url text null`
- `display_order integer not null`
- `is_visible boolean not null default true`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

### `related_work`

Required columns:

- `id uuid primary key`
- `tag_id uuid not null references tags(id)`
- `title text not null`
- `url text not null`
- `description text not null`
- `display_order integer not null`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

## 30. OG Image Generation Requirements

The old project has two OG generation scripts. The rebuild does not need full OG generation in V1, but the spec should preserve the behavior for a later Kafka-backed media job.

### Profile OG Image

Original script:

```text
scripts/generate-og-image.ts
```

Inputs:

- Profile name.
- Username.
- Description.
- Bio.
- Avatar image.
- Up to 16 tag names.
- Inter regular and bold fonts.
- Theme argument: `dark` or `light`.

Output:

- 1200x630 PNG.
- Written to the profile `ogImageUrl`.

Dark theme colors:

- Background: `#1b1d2d`
- Text: `white`
- Accent: `#a5fd0e`
- Secondary text: `#bdc3c7`
- Header text: `#e0e0e0`
- Tag background: `#2a3b0f`
- Tag text: `#a5fd0e`
- Gradient start: `rgba(165, 253, 14, 0.15)`
- Gradient end: `rgba(27, 29, 45, 0)`

Light theme colors:

- Background: `#ffffff`
- Text: `#333333`
- Accent: `#9233ea`
- Secondary text: `#555555`
- Header text: `#444444`
- Tag background: `#f0e6fa`
- Tag text: `#9233ea`
- Gradient start: `rgba(146, 51, 234, 0.15)`
- Gradient end: `rgba(255, 255, 255, 0)`

Layout:

- Canvas: 1200x630.
- Outer padding: 60px.
- Avatar: 180x180, circular, 4px accent border, shadow.
- Name: 62px bold.
- Username: 34px regular, accent color.
- Description: 26px medium.
- Bio: 24px, line height 1.6, max width 800px.
- Tags: flex wrap, max 16 tags, 20px font, rounded pill.
- Footer: `linkarooie.com` in accent color.

Future implementation:

- API publishes `OG_IMAGE_REQUESTED` to Kafka when a profile changes.
- Media worker generates the image and uploads it to RustFS/S3.
- `profiles.og_media_id` is updated when ready.

### Main App OG Image

Original script:

```text
scripts/generate-main-og-image.ts
```

Inputs:

- Background image: `linkarooie.jpg`.
- Title: `Linkarooie`.
- Subtitle: `Simplify your online presence`.
- Description: `A Linktree-style app to showcase your profile, links, and achievements`.
- URL text: `linkarooie.com`.
- Inter regular and bold fonts.
- Theme argument: `dark` or `light`.

Output:

- 1200x630 JPEG.
- Writes to `src/assets/images/linkarooie_og.jpg`.

Dark colors:

- Accent: `#a5fd0e`
- Text: `white`
- Secondary text: `#e0e0e0`
- Overlay: `rgba(0, 0, 0, 0.6)`
- Text shadow: `rgba(0, 0, 0, 0.5)`

Light colors:

- Accent: `#9233ea`
- Text: `#333333`
- Secondary text: `#555555`
- Overlay: `rgba(255, 255, 255, 0.85)`
- Text shadow: `rgba(0, 0, 0, 0.2)`

Layout:

- Canvas: 1200x630.
- Full background image with object fit cover.
- Centered overlay.
- Title: 80px bold accent.
- Subtitle: 40px.
- Description: 28px, centered, max width 800px.
- URL: 32px bold accent.

## 31. Review Pass Decisions

These are the main design decisions after reviewing the spec for implementation risk.

### Keep V1 As Modular Monolith Plus Worker

Do not start with five Spring Boot services.

Use:

- One API application.
- One analytics worker.
- One frontend application.
- Shared backend modules for domain, persistence, eventing, contracts, and observability.

Reason:

- You still learn Kubernetes, Kafka, Redis, Postgres, S3, container builds, and GHCR.
- You avoid distributed transaction and service-discovery problems before the product model is stable.
- The package boundaries still prepare the system for later extraction.

### Use Redis-Backed Sessions For Browser Auth

Use HTTP-only cookies and Spring Session with Redis for V1 browser authentication.

Reason:

- Safer than putting JWTs in browser storage.
- Easier to reason about for a same-origin React plus Spring Boot app.
- Gives Redis a real production-like role.
- JWT can still be added later for external API clients.

### Treat Media As A First-Class Domain

Do not store only one image URL on the profile.

Use:

- `media_assets` for originals.
- `media_variants` for optimized public renderings.
- Stable app media URLs in API responses.
- RustFS/S3 object keys hidden behind API URLs or signed redirects.

Reason:

- The old app imported images statically, but the new app has user uploads.
- Serving original uploads directly is slow and can leak metadata.
- Variants prevent layout shift and reduce bandwidth.
- The same model works later with S3 and a CDN.

### Keep Seed Import Separate From Flyway

Flyway should create schema. A seed importer should upload assets and upsert the example profile.

Reason:

- SQL migrations are bad at managing binary object storage.
- Seed imports need checksum validation.
- The seed can be rerun safely in local labs.
- Production can choose not to run demo seed data.

### Use Redirects For Tracked External Clicks

Links, social links, and achievements should use app redirect URLs.

Reason:

- Client-side analytics is often blocked.
- Redirects give reliable click capture.
- Redirects keep analytics consistent across browsers.

### Keep Public Analytics Aggregated

Public analytics should never expose visitor-level records.

Reason:

- It preserves privacy.
- It keeps the product simple.
- Owner analytics can still show useful aggregate breakdowns.

### Defer OG Generation Until After Core CRUD

Start with uploaded/imported OG images. Add Kafka-backed OG generation after profiles, media, and analytics work.

Reason:

- OG generation is valuable but not necessary for the first usable app.
- It becomes a good later async job once Kafka and media storage are already working.
