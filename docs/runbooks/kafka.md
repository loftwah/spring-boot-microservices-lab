# Kafka Runbook

Kafka is the lab event streaming platform. Treat it like a local stand-in for MSK.

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

## List Topics

```bash
docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list
```

## Create Topics

```bash
docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --if-not-exists \
  --topic documents.v1.events \
  --partitions 3 \
  --replication-factor 1
```

Repeat for:

```text
audits.v1.events
workflows.v1.events
lab.v1.dead-letter
```

## Describe Topic

```bash
docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --topic documents.v1.events
```

## Produce Messages

```bash
docker exec -i kafka /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic documents.v1.events
```

Paste JSON lines:

```json
{
  "eventId": "1",
  "eventType": "document-created",
  "payload": { "documentId": "doc-1" }
}
```

Press `Ctrl-D` to finish.

## Consume Messages

```bash
docker exec kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic documents.v1.events \
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

Describe a group:

```bash
docker exec kafka /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --group audit-service
```

## What The Microservices Should Use

Document Service:

```text
produces -> documents.v1.events
```

Audit Service:

```text
consumes -> documents.v1.events
produces -> audits.v1.events
```

Workflow Service:

```text
consumes -> audits.v1.events
produces -> workflows.v1.events
```

All services should send failed events to:

```text
lab.v1.dead-letter
```

## Event Envelope

```json
{
  "eventId": "uuid",
  "eventType": "document-created",
  "version": 1,
  "occurredAt": "2026-04-22T00:00:00Z",
  "source": "document-service",
  "correlationId": "uuid",
  "payload": {}
}
```

## Things To Break And Fix

1. Produce invalid JSON and make the consumer send it to the dead-letter topic.
2. Stop the Audit Service and watch consumer lag grow.
3. Restart the Audit Service and watch it catch up.
4. Create a topic with one partition, then compare ordering with three partitions.

## Know As A DevOps Engineer

- Topics, partitions, offsets, and consumer groups.
- Ordering is per partition, not across the whole topic.
- Consumer lag is a key operational signal.
- Retention is not the same as queue deletion.
- Replication factor is `1` in this lab only because it is local.
- Advertised listeners are usually where local Kafka labs fail.
