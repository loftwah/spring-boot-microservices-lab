# Kafka Runbook

Kafka is the lab event streaming platform. Treat it like a local stand-in for MSK or another managed Kafka provider.

## Connection Details

Host clients:

```text
localhost:9092
```

k3d pods:

```text
host.k3d.internal:9094
```

Compose containers:

```text
kafka:9093
```

## Create Linkarooie Topics

From the repo root:

```bash
./supporting-services/scripts/create-linkarooie-topics.sh
```

Topics:

```text
linkarooie.analytics.events.v1
linkarooie.media.events.v1
linkarooie.audit.events.v1
linkarooie.profile.events.v1
linkarooie.dead-letter.v1
```

## List Topics

```bash
docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list
```

## Describe Topic

```bash
docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --topic linkarooie.analytics.events.v1
```

## Produce An Analytics Event

```bash
docker exec -i kafka /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic linkarooie.analytics.events.v1
```

Paste one JSON line:

```json
{"eventId":"00000000-0000-0000-0000-000000000001","eventType":"PROFILE_VIEW","schemaVersion":1,"occurredAt":"2026-05-17T00:00:00Z","receivedAt":"2026-05-17T00:00:01Z","requestId":"req_local_smoke","profileId":"00000000-0000-0000-0000-000000000100","profileUsername":"loftwah","targetType":"PROFILE","targetId":"00000000-0000-0000-0000-000000000100","metadata":{"source":"manual-smoke"}}
```

Press `Ctrl-D` to finish.

## Consume Events

```bash
docker exec kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic linkarooie.analytics.events.v1 \
  --from-beginning \
  --max-messages 5
```

## Consumer Groups

List groups:

```bash
docker exec kafka /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --list
```

Describe the analytics worker group:

```bash
docker exec kafka /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --group linkarooie-analytics-worker
```

Describe the media worker group:

```bash
docker exec kafka /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --group linkarooie-media-worker
```

## What The Application Uses

API:

```text
produces -> linkarooie.analytics.events.v1
produces -> linkarooie.media.events.v1
```

Analytics worker:

```text
consumes -> linkarooie.analytics.events.v1
```

Media worker:

```text
consumes -> linkarooie.media.events.v1
produces -> linkarooie.media.events.v1
```

Dead letters:

```text
linkarooie.dead-letter.v1
```

## Event Rules

- Events are facts, not commands.
- Every event has a stable `eventId`.
- Consumers must be idempotent.
- Schemas are versioned.
- Use `profileId` as the partition key when available.
- Propagate request IDs in event headers and event payloads.

## Things To Break And Fix

1. Produce invalid JSON and make the consumer send it to the dead-letter topic.
2. Stop the analytics worker and watch consumer lag grow.
3. Restart the analytics worker and watch it catch up.
4. Replay the same event ID and verify the worker ignores the duplicate.

## Know As A DevOps Engineer

- Topics, partitions, offsets, and consumer groups.
- Ordering is per partition, not across the whole topic.
- Consumer lag is a key operational signal.
- Retention is not the same as queue deletion.
- Replication factor is `1` in this lab only because it is local.
- Advertised listeners are usually where local Kafka labs fail.
