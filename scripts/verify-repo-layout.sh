#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass() {
  printf 'ok - %s\n' "$*"
}

fail() {
  printf 'error - %s\n' "$*" >&2
  exit 1
}

require_path() {
  local path="$1"
  [[ -e "$ROOT_DIR/$path" ]] || fail "missing $path"
  pass "$path exists"
}

main() {
  require_path "linkarooie-spec.md"
  require_path "docs/implementation-plan.md"
  require_path "docs/stories/README.md"
  require_path "services/README.md"
  require_path "README.md"
  require_path "services/linkarooie-api/README.md"
  require_path "services/linkarooie-analytics-worker/README.md"
  require_path "services/linkarooie-media-worker/README.md"
  require_path "services/linkarooie-web/README.md"
  require_path "deploy/k8s/local/README.md"
  require_path "services/linkarooie-api/seed/README.md"
  require_path "services/linkarooie-api/seed/assets/default_avatar.jpg"
  require_path "services/linkarooie-api/seed/assets/default_banner.jpg"
  require_path "services/linkarooie-api/seed/assets/linkarooie_og.jpg"
  require_path "supporting-services/scripts/create-linkarooie-topics.sh"
  require_path "supporting-services/scripts/prepare-linkarooie-supporting-services.sh"
  require_path "supporting-services/docker-compose.yml"
  require_path "supporting-services/verify-supporting-services.sh"

  for story in \
    01-api-foundation \
    02-auth-and-workspaces \
    03-profiles-and-public-reads \
    04-profile-content \
    05-media-uploads \
    06-analytics-pipeline \
    07-linkarooie-web-public \
    08-linkarooie-web-dashboard \
    09-containers-and-k3d \
    10-linkarooie-media-worker
  do
    require_path "docs/stories/${story}.md"
  done

  printf '\nRepo layout is ready for the Linkarooie build path.\n'
}

main "$@"
