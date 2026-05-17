# API Seed Data

The API owns the Linkarooie application schema, so the `loftwah` profile seed belongs here.

Media files for that seed live in this service:

```text
services/linkarooie-api/seed/assets/default_avatar.jpg
services/linkarooie-api/seed/assets/default_banner.jpg
services/linkarooie-api/seed/assets/hero.png
services/linkarooie-api/seed/assets/icon.png
services/linkarooie-api/seed/assets/linkarooie.jpg
services/linkarooie-api/seed/assets/linkarooie_og.jpg
services/linkarooie-api/seed/assets/linkarooie_og_light.jpg
services/linkarooie-api/seed/assets/loftwah_og.jpg
```

## What The Seed Runner Should Do

When `linkarooie-api` exists, add a seed command that:

1. Creates or updates the seed user.
2. Creates or updates the `loftwah` profile.
3. Creates or updates social links, links, achievements, tags, and related work.
4. Uploads the existing image assets to RustFS if missing.
5. Writes `media_assets` and `media_variants` rows.
6. Records a seed version so the command is idempotent.

## Why This Is Not In `supporting-services`

`supporting-services` starts and verifies platform dependencies. It should not need to know the API database schema.

Platform setup such as Kafka topics and RustFS buckets belongs in `supporting-services`. Application records belong to the service that owns the schema.
