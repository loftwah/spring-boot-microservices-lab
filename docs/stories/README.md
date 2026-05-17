# Build Stories

These stories turn `linkarooie-spec.md` into a human build path.

The sequence starts with the smallest useful API service and finishes with Kubernetes and generated media. Each story should produce a visible or testable result before the next one begins.

## Story Format

Each story explains:

- What to build.
- Why it matters.
- Where it goes.
- How to build it.
- How to test it.
- What tangible result proves it worked.

## Recommended Commit Shape

Use one story, or one small group of related sub-stories, per commit.

Good commits:

- `Add Linkarooie API foundation`
- `Add signup and Redis-backed sessions`
- `Add public profile read cache`
- `Add analytics event consumer idempotency`

Avoid commits that mix unrelated layers, such as auth, media, web charts, and Kubernetes manifests all at once.

## Build Order

1. API foundation.
2. Auth, users, organisations, and sessions.
3. Profiles and public reads.
4. Links, achievements, tags, and related work.
5. Media metadata and uploads.
6. Kafka analytics pipeline.
7. Public web app.
8. Dashboard web app.
9. Containers and k3d.
10. Generated media worker.
