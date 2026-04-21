#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  sh scripts/set_website_image_tag.sh [prod|dev] <image-tag>

Example:
  sh scripts/set_website_image_tag.sh prod 3b4c2f1
  sh scripts/set_website_image_tag.sh dev d99d19cbe8fbc017ca244cff9f587fcb54b7e521
EOF
}

require_file() {
  if [ ! -f "$1" ]; then
    echo "Required file not found: $1" >&2
    exit 1
  fi
}

resolve_kustomization() {
  case "$1" in
    prod)
      echo "${ROOT_DIR}/kubernetes/apps/danielmtz-website-prod-tls/kustomization.yaml"
      ;;
    dev)
      echo "${ROOT_DIR}/kubernetes/apps/danielmtz-website-dev-tls/kustomization.yaml"
      ;;
    *)
      echo "Unknown environment: $1" >&2
      exit 1
      ;;
  esac
}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  usage
  exit 1
fi

if [ $# -eq 1 ]; then
  APP_ENV="prod"
  IMAGE_TAG="$1"
else
  APP_ENV="$1"
  IMAGE_TAG="$2"
fi

KUSTOMIZATION_FILE="$(resolve_kustomization "${APP_ENV}")"

case "${IMAGE_TAG}" in
  *[!A-Za-z0-9._-]*|'')
    echo "Invalid image tag: ${IMAGE_TAG}" >&2
    exit 1
    ;;
esac

require_file "${KUSTOMIZATION_FILE}"

TMP_FILE="$(mktemp)"
awk -v tag="${IMAGE_TAG}" '
  /^    newTag:/ {
    print "    newTag: " tag
    next
  }
  { print }
' "${KUSTOMIZATION_FILE}" > "${TMP_FILE}"

mv "${TMP_FILE}" "${KUSTOMIZATION_FILE}"

echo "Updated ${APP_ENV} website image tag to: ${IMAGE_TAG}"
echo "Changed file: ${KUSTOMIZATION_FILE}"
