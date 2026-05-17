#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/supporting-services/docker-compose.yml}"

POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-postgres}"
REDIS_CONTAINER="${REDIS_CONTAINER:-redis}"
KAFKA_CONTAINER="${KAFKA_CONTAINER:-kafka}"
RUSTFS_CONTAINER="${RUSTFS_CONTAINER:-rustfs}"
VAULT_CONTAINER="${VAULT_CONTAINER:-vault}"
JENKINS_CONTAINER="${JENKINS_CONTAINER:-jenkins}"

log() {
  printf '\n==> %s\n' "$*"
}

pass() {
  printf 'ok - %s\n' "$*"
}

warn() {
  printf 'warn - %s\n' "$*" >&2
}

fail() {
  printf 'error - %s\n' "$*" >&2
  exit 1
}

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "found $1"
  else
    fail "missing required command: $1"
  fi
}

optional_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "found $1"
  else
    warn "missing optional command: $1"
  fi
}

container_status() {
  docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$1" 2>/dev/null || true
}

require_container_healthy() {
  local container="$1"
  local status
  status="$(container_status "$container")"
  case "$status" in
    healthy|running)
      pass "$container is $status"
      ;;
    "")
      fail "$container is not running. Start supporting services with: cd supporting-services && docker compose up -d"
      ;;
    *)
      fail "$container is $status"
      ;;
  esac
}

check_tcp() {
  local host="$1"
  local port="$2"
  local label="$3"

  if command -v nc >/dev/null 2>&1; then
    nc -z -w 3 "$host" "$port" >/dev/null 2>&1 || fail "$label is not reachable at $host:$port"
    pass "$label is reachable at $host:$port"
  else
    warn "nc is missing; skipping TCP check for $label"
  fi
}

check_http() {
  local url="$1"
  local label="$2"
  local code

  code="$(curl -sS -o /dev/null -w '%{http_code}' "$url" || true)"
  [[ "$code" =~ ^(2|3|4)[0-9][0-9]$ ]] || fail "$label returned HTTP $code at $url"
  pass "$label returned HTTP $code at $url"
}

check_kafka_topic_tool() {
  docker exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --list >/dev/null
  pass "Kafka topic tooling works"
}

check_layout() {
  "$ROOT_DIR/scripts/verify-repo-layout.sh" >/dev/null
  pass "Linkarooie repo layout is present"
}

main() {
  log "Checking required local tools"
  require_command docker
  require_command curl
  optional_command java
  optional_command gradle
  optional_command bun
  optional_command node
  optional_command kubectl
  optional_command k3d
  optional_command helm

  log "Checking repo layout"
  check_layout

  log "Checking supporting-service containers"
  [[ -f "$COMPOSE_FILE" ]] || fail "missing Compose file: $COMPOSE_FILE"
  require_container_healthy "$POSTGRES_CONTAINER"
  require_container_healthy "$REDIS_CONTAINER"
  require_container_healthy "$KAFKA_CONTAINER"
  require_container_healthy "$RUSTFS_CONTAINER"
  require_container_healthy "$VAULT_CONTAINER"
  require_container_healthy "$JENKINS_CONTAINER"

  log "Checking host reachability"
  check_tcp localhost 5432 "Postgres"
  check_tcp localhost 6379 "Redis"
  check_tcp localhost 9092 "Kafka host listener"
  check_tcp localhost 9094 "Kafka k3d listener"
  check_tcp localhost 9000 "RustFS S3 API"
  check_tcp localhost 8200 "Vault"
  check_http http://localhost:9000/ "RustFS S3 API"
  check_http http://localhost:8200/v1/sys/health "Vault health"
  check_http http://localhost:8080/login "Jenkins login"

  log "Checking Kafka"
  check_kafka_topic_tool

  printf '\nDoctor passed. The local platform is ready for the Linkarooie build stories.\n'
}

main "$@"
