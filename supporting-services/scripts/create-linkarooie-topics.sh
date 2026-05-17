#!/usr/bin/env bash
set -Eeuo pipefail

KAFKA_CONTAINER="${KAFKA_CONTAINER:-kafka}"
BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"
PARTITIONS="${KAFKA_TOPIC_PARTITIONS:-3}"
REPLICATION_FACTOR="${KAFKA_TOPIC_REPLICATION_FACTOR:-1}"

topics=(
  "linkarooie.analytics.events.v1"
  "linkarooie.media.events.v1"
  "linkarooie.audit.events.v1"
  "linkarooie.profile.events.v1"
  "linkarooie.dead-letter.v1"
)

fail() {
  printf 'error - %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

main() {
  require_command docker

  docker inspect "$KAFKA_CONTAINER" >/dev/null 2>&1 || fail "Kafka container '$KAFKA_CONTAINER' is not running"

  for topic in "${topics[@]}"; do
    printf 'creating topic if missing: %s\n' "$topic"
    docker exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-topics.sh \
      --bootstrap-server "$BOOTSTRAP_SERVER" \
      --create \
      --if-not-exists \
      --topic "$topic" \
      --partitions "$PARTITIONS" \
      --replication-factor "$REPLICATION_FACTOR" >/dev/null
  done

  printf '\nCurrent Linkarooie topics:\n'
  docker exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --list | grep '^linkarooie\.' | sort
}

main "$@"
