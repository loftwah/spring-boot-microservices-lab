#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$SCRIPT_DIR/docker-compose.yml}"
PROJECT_NAME="${PROJECT_NAME:-enterprise-lab}"

POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-postgres}"
REDIS_CONTAINER="${REDIS_CONTAINER:-redis}"
KAFKA_CONTAINER="${KAFKA_CONTAINER:-kafka}"
RUSTFS_CONTAINER="${RUSTFS_CONTAINER:-rustfs}"
VAULT_CONTAINER="${VAULT_CONTAINER:-vault}"
JENKINS_CONTAINER="${JENKINS_CONTAINER:-jenkins}"

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
RUSTFS_ENDPOINT="${RUSTFS_ENDPOINT:-http://localhost:9000}"
RUSTFS_ACCESS_KEY="${RUSTFS_ACCESS_KEY:-rustfsadmin}"
RUSTFS_SECRET_KEY="${RUSTFS_SECRET_KEY:-rustfsadmin}"
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"

log() {
  printf '\n==> %s\n' "$*"
}

pass() {
  printf 'ok - %s\n' "$*"
}

fail() {
  printf 'error - %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

compose_exec() {
  compose exec -T "$@"
}

wait_for_health() {
  local container="$1"
  local timeout_seconds="${2:-240}"
  local start
  local status

  start="$(date +%s)"
  while true; do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container" 2>/dev/null || true)"

    case "$status" in
      healthy|running)
        pass "$container is $status"
        return 0
        ;;
      unhealthy|exited|dead)
        docker inspect --format '{{.State.Status}} {{.State.ExitCode}} {{.State.Error}}' "$container" 2>/dev/null || true
        fail "$container reached status: $status"
        ;;
    esac

    if (( "$(date +%s)" - start >= timeout_seconds )); then
      compose ps
      fail "timed out waiting for $container to become healthy"
    fi

    sleep 3
  done
}

http_code() {
  curl -sS -o /dev/null -w '%{http_code}' "$@"
}

assert_http_2xx() {
  local url="$1"
  local code

  code="$(http_code "$url")"
  [[ "$code" =~ ^2[0-9][0-9]$ ]] || fail "$url returned HTTP $code"
}

test_postgres() {
  log "Testing Postgres CRUD"
  compose_exec "$POSTGRES_CONTAINER" psql -U app -d app -v ON_ERROR_STOP=1 >/dev/null <<'SQL'
CREATE TABLE IF NOT EXISTS smoke_test (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL
);
INSERT INTO smoke_test (name, value)
VALUES ('compose-check', 'created')
ON CONFLICT (name) DO UPDATE SET value = EXCLUDED.value;
UPDATE smoke_test SET value = 'updated' WHERE name = 'compose-check';
DO $$
BEGIN
  IF (SELECT value FROM smoke_test WHERE name = 'compose-check') <> 'updated' THEN
    RAISE EXCEPTION 'Postgres smoke row was not updated';
  END IF;
END $$;
DELETE FROM smoke_test WHERE name = 'compose-check';
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM smoke_test WHERE name = 'compose-check') THEN
    RAISE EXCEPTION 'Postgres smoke row was not deleted';
  END IF;
END $$;
SQL
  pass "Postgres create/read/update/delete succeeded"
}

test_redis() {
  log "Testing Redis key CRUD"
  local key="lab:compose-check"
  local value

  [[ "$(compose_exec "$REDIS_CONTAINER" redis-cli SET "$key" created | tr -d '\r')" == "OK" ]] || fail "Redis SET failed"
  [[ "$(compose_exec "$REDIS_CONTAINER" redis-cli GET "$key" | tr -d '\r')" == "created" ]] || fail "Redis GET after SET failed"
  [[ "$(compose_exec "$REDIS_CONTAINER" redis-cli SET "$key" updated | tr -d '\r')" == "OK" ]] || fail "Redis update SET failed"
  value="$(compose_exec "$REDIS_CONTAINER" redis-cli GET "$key" | tr -d '\r')"
  [[ "$value" == "updated" ]] || fail "Redis GET after update returned: $value"
  [[ "$(compose_exec "$REDIS_CONTAINER" redis-cli DEL "$key" | tr -d '\r')" == "1" ]] || fail "Redis DEL failed"
  pass "Redis set/get/update/delete succeeded"
}

test_kafka() {
  log "Testing Kafka topic publish/consume"
  local topic="lab-smoke-$(date +%s)-$$"
  local message="message-$topic"
  local consumed

  compose_exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --create \
    --if-not-exists \
    --topic "$topic" \
    --partitions 1 \
    --replication-factor 1 >/dev/null

  printf '%s\n' "$message" | compose_exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server localhost:9092 \
    --topic "$topic" >/dev/null

  consumed="$(compose_exec "$KAFKA_CONTAINER" /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic "$topic" \
    --from-beginning \
    --max-messages 1 \
    --timeout-ms 10000 2>/dev/null | tr -d '\r')"

  [[ "$consumed" == "$message" ]] || fail "Kafka consumed '$consumed', expected '$message'"
  pass "Kafka topic create, publish, and consume succeeded"
}

test_rustfs() {
  log "Testing RustFS S3 CRUD"
  require_command python3

  python3 - "$RUSTFS_ENDPOINT" "$RUSTFS_ACCESS_KEY" "$RUSTFS_SECRET_KEY" <<'PY'
import datetime
import hashlib
import hmac
import http.client
import os
import sys
import time
from urllib.parse import quote, urlsplit

endpoint, access_key, secret_key = sys.argv[1:4]
region = "us-east-1"
service = "s3"
bucket = f"lab-smoke-{int(time.time())}-{os.getpid()}"
key = "object.txt"
body = b"rustfs smoke payload"
parsed = urlsplit(endpoint)
host = parsed.netloc

def sign(key_bytes, msg):
    return hmac.new(key_bytes, msg.encode("utf-8"), hashlib.sha256).digest()

def request(method, path, payload=b""):
    now = datetime.datetime.utcnow()
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    payload_hash = hashlib.sha256(payload).hexdigest()
    canonical_uri = quote(path, safe="/~")
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_headers = (
        f"host:{host}\n"
        f"x-amz-content-sha256:{payload_hash}\n"
        f"x-amz-date:{amz_date}\n"
    )
    canonical_request = "\n".join([
        method,
        canonical_uri,
        "",
        canonical_headers,
        signed_headers,
        payload_hash,
    ])
    credential_scope = f"{date_stamp}/{region}/{service}/aws4_request"
    string_to_sign = "\n".join([
        "AWS4-HMAC-SHA256",
        amz_date,
        credential_scope,
        hashlib.sha256(canonical_request.encode("utf-8")).hexdigest(),
    ])
    signing_key = sign(sign(sign(sign(("AWS4" + secret_key).encode("utf-8"), date_stamp), region), service), "aws4_request")
    signature = hmac.new(signing_key, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()
    headers = {
        "Authorization": (
            f"AWS4-HMAC-SHA256 Credential={access_key}/{credential_scope}, "
            f"SignedHeaders={signed_headers}, Signature={signature}"
        ),
        "Host": host,
        "x-amz-content-sha256": payload_hash,
        "x-amz-date": amz_date,
    }
    if payload:
        headers["Content-Type"] = "application/octet-stream"
    conn_cls = http.client.HTTPSConnection if parsed.scheme == "https" else http.client.HTTPConnection
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    conn = conn_cls(parsed.hostname, port, timeout=10)
    try:
        conn.request(method, path, body=payload, headers=headers)
        response = conn.getresponse()
        data = response.read()
        return response.status, data
    finally:
        conn.close()

def expect(statuses, method, path, payload=b""):
    status, data = request(method, path, payload)
    if status not in statuses:
        raise SystemExit(f"{method} {path} returned HTTP {status}: {data[:300]!r}")
    return data

expect({200}, "PUT", f"/{bucket}")
expect({200}, "PUT", f"/{bucket}/{key}", body)
read_back = expect({200}, "GET", f"/{bucket}/{key}")
if read_back != body:
    raise SystemExit(f"GET returned {read_back!r}, expected {body!r}")
expect({204}, "DELETE", f"/{bucket}/{key}")
expect({204}, "DELETE", f"/{bucket}")
PY

  pass "RustFS bucket and object create/read/delete succeeded"
}

test_vault() {
  log "Testing Vault KV secret CRUD"
  local path="$VAULT_ADDR/v1/secret/data/lab-smoke"
  local code
  local value

  assert_http_2xx "$VAULT_ADDR/v1/sys/health"
  curl -fsS \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST \
    --data '{"data":{"value":"created"}}' \
    "$path" >/dev/null

  value="$(curl -fsS -H "X-Vault-Token: $VAULT_TOKEN" "$path" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["data"]["value"])')"
  [[ "$value" == "created" ]] || fail "Vault read returned: $value"

  curl -fsS \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST \
    --data '{"data":{"value":"updated"}}' \
    "$path" >/dev/null

  value="$(curl -fsS -H "X-Vault-Token: $VAULT_TOKEN" "$path" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["data"]["value"])')"
  [[ "$value" == "updated" ]] || fail "Vault update returned: $value"

  curl -fsS -H "X-Vault-Token: $VAULT_TOKEN" -X DELETE "$path" >/dev/null
  code="$(http_code -H "X-Vault-Token: $VAULT_TOKEN" "$path")"
  [[ "$code" == "404" ]] || fail "Vault secret should be deleted, got HTTP $code"
  pass "Vault secret create/read/update/delete succeeded"
}

test_jenkins() {
  log "Testing Jenkins HTTP endpoints"
  assert_http_2xx "$JENKINS_URL/login"

  local code
  code="$(http_code "$JENKINS_URL/whoAmI/api/json")"
  [[ "$code" =~ ^(200|403)$ ]] || fail "Jenkins whoAmI returned HTTP $code"
  pass "Jenkins login endpoint is reachable"
}

main() {
  require_command docker
  require_command curl

  log "Starting Compose stack ($PROJECT_NAME)"
  COMPOSE_PROJECT_NAME="$PROJECT_NAME" compose up -d

  log "Waiting for container health"
  wait_for_health "$POSTGRES_CONTAINER" 180
  wait_for_health "$REDIS_CONTAINER" 180
  wait_for_health "$KAFKA_CONTAINER" 240
  wait_for_health "$RUSTFS_CONTAINER" 240
  wait_for_health "$VAULT_CONTAINER" 180
  wait_for_health "$JENKINS_CONTAINER" 300

  test_postgres
  test_redis
  test_kafka
  test_rustfs
  test_vault
  test_jenkins

  log "All supporting services passed"
  compose ps
}

main "$@"
