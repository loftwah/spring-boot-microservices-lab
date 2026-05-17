# linkarooie-analytics-worker

Spring Boot Kafka consumer for analytics aggregation.

## Owns

- Consuming `linkarooie.analytics.events.v1`.
- Storing immutable analytics events.
- Ignoring duplicate event IDs.
- Updating profile, target, and app daily aggregates.
- Updating Redis hot counters.
- Worker health and readiness.

## Does Not Own

- Public HTTP event ingestion.
- Redirect tracking.
- Profile ownership or auth.
- Web chart rendering.

Those stay in `linkarooie-api` and `linkarooie-web`.

## First Useful Build

1. Add a Spring Boot worker application.
2. Subscribe to `linkarooie.analytics.events.v1`.
3. Log consumed events with request ID and event ID.
4. Store events idempotently in Postgres.
5. Update one daily profile aggregate.

## Verification

```bash
./supporting-services/scripts/create-linkarooie-topics.sh
cd services/linkarooie-analytics-worker
./gradlew test
./gradlew bootRun
```

Publish a test event:

```bash
docker exec -i kafka /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic linkarooie.analytics.events.v1
```

## Testing Expectations

- Unit tests for aggregation calculations.
- Integration tests for Kafka consume and duplicate handling.
- Integration tests for daily aggregate upserts.
- Component tests that publish events and inspect analytics API results through `linkarooie-api`.
