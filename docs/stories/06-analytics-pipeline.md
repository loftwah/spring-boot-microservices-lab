# Story 6: Analytics Pipeline

## Goal

Add Kafka-backed analytics event ingestion, link redirect tracking, immutable event storage, daily aggregates, Redis hot counters, and analytics API ranges.

## Why

Analytics proves the service-to-service architecture. The API publishes facts, the worker consumes them idempotently, and users can see behaviour change after visitors interact with profiles.

## Where It Goes

```text
services/linkarooie-api/src/main/java/com/linkarooie/api/analytics/
services/linkarooie-analytics-worker/src/main/java/com/linkarooie/analyticsworker/
services/linkarooie-api/src/main/java/com/linkarooie/api/eventing/
services/linkarooie-api/src/main/resources/db/migration/
services/linkarooie-analytics-worker/src/main/java/com/linkarooie/analyticsworker/eventing/
supporting-services/scripts/create-linkarooie-topics.sh
```

## Build Steps

1. Add topic constants for `linkarooie.analytics.events.v1`.
2. Add analytics event envelope types.
3. Add Flyway migration for `analytics_events`, `profile_analytics_daily`, `target_analytics_daily`, and `app_analytics_daily`.
4. Add `POST /api/analytics/events` for UI-only events such as tag opens.
5. Add `GET /r/{publicLinkId}` redirect flow for reliable link clicks.
6. Hash IP, user agent, visitor ID, and session ID before storage.
7. Publish analytics events from API to Kafka with `profileId` as partition key.
8. Build analytics worker with a Kafka listener.
9. Store immutable event rows idempotently by `eventId`.
10. Update daily aggregate tables.
11. Update Redis hot counters.
12. Add owner, public profile, and app-wide analytics endpoints with `7d`, `30d`, `90d`, and `all` ranges.

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
cd services/linkarooie-analytics-worker
./gradlew bootRun
```

Manual smoke:

```bash
curl -i http://localhost:8080/r/<publicLinkId>
curl -i http://localhost:8080/api/public/profiles/loftwah/analytics?range=7d
```

Inspect Kafka and Redis:

```bash
docker exec kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic linkarooie.analytics.events.v1 \
  --from-beginning \
  --max-messages 1

docker exec redis redis-cli keys 'analytics:*'
```

## Tangible Result

- Clicking a public redirect creates a Kafka event.
- Analytics worker stores the event once, even if the event is replayed.
- Public and owner analytics endpoints show updated counts.
- Redis contains hot counters.

## Test Coverage

- Unit tests for event mapping and hash handling.
- Unit tests for range parsing.
- Integration tests for Kafka publish/consume.
- Integration tests for duplicate `eventId` handling.
- Component tests for analytics endpoint visibility rules.
- Black-box test for redirect click then analytics count change.
