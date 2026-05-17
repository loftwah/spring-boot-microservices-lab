#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUSTFS_ENDPOINT="${RUSTFS_ENDPOINT:-http://localhost:9000}"
RUSTFS_ACCESS_KEY="${RUSTFS_ACCESS_KEY:-rustfsadmin}"
RUSTFS_SECRET_KEY="${RUSTFS_SECRET_KEY:-rustfsadmin}"
S3_BUCKET="${S3_BUCKET:-linkarooie-media-local}"

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

create_bucket() {
  python3 - "$RUSTFS_ENDPOINT" "$RUSTFS_ACCESS_KEY" "$RUSTFS_SECRET_KEY" "$S3_BUCKET" <<'PY'
import datetime
import hashlib
import hmac
import http.client
import sys
from urllib.parse import quote, urlsplit

endpoint, access_key, secret_key, bucket = sys.argv[1:5]
region = "us-east-1"
service = "s3"
parsed = urlsplit(endpoint)
host = parsed.netloc

def sign(key_bytes, msg):
    return hmac.new(key_bytes, msg.encode("utf-8"), hashlib.sha256).digest()

def request(method, path, payload=b""):
    now = datetime.datetime.utcnow()
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    payload_hash = hashlib.sha256(payload).hexdigest()
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_headers = (
        f"host:{host}\n"
        f"x-amz-content-sha256:{payload_hash}\n"
        f"x-amz-date:{amz_date}\n"
    )
    canonical_request = "\n".join([
        method,
        quote(path, safe="/~"),
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

status, data = request("PUT", f"/{bucket}")
if status not in (200, 409):
    raise SystemExit(f"PUT /{bucket} returned HTTP {status}: {data[:300]!r}")
print(bucket)
PY
}

main() {
  require_command docker
  require_command python3

  log "Creating Linkarooie Kafka topics"
  "$SCRIPT_DIR/create-linkarooie-topics.sh"

  log "Creating RustFS bucket"
  bucket="$(create_bucket)"
  pass "RustFS bucket exists: $bucket"

  log "Supporting services are prepared for Linkarooie"
}

main "$@"
