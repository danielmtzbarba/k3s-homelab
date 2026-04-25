#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_ENV_FILE="${1:-${ROOT_DIR}/.gcp-secrets.env}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_file() {
  if [ ! -f "$1" ]; then
    echo "Required file not found: $1" >&2
    exit 1
  fi
}

require_env() {
  if [ -z "${2:-}" ]; then
    echo "Required environment variable not set: $1" >&2
    exit 1
  fi
}

load_env() {
  set -a
  . "${SECRETS_ENV_FILE}"
  set +a
}

sync_secret() {
  MAPPING_VAR="$1"
  SECRET_ID="$(printenv "${MAPPING_VAR}")"
  VALUE_VAR="${MAPPING_VAR#GCP_SECRET_}"

  if [ -z "${SECRET_ID}" ]; then
    echo "Skipping ${MAPPING_VAR}: empty secret ID." >&2
    return
  fi

  SECRET_VALUE="$(printenv "${VALUE_VAR}" || true)"
  if [ -z "${SECRET_VALUE}" ]; then
    echo "Missing value variable for ${MAPPING_VAR}: ${VALUE_VAR}" >&2
    exit 1
  fi

  echo "Syncing ${SECRET_ID} from ${VALUE_VAR}..."

  if gcloud secrets describe "${SECRET_ID}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "  deleting existing secret ${SECRET_ID} to avoid version buildup..."
    gcloud secrets delete "${SECRET_ID}" --project="${PROJECT_ID}" --quiet
  fi

  printf '%s' "${SECRET_VALUE}" | \
    gcloud secrets create "${SECRET_ID}" \
      --project="${PROJECT_ID}" \
      --replication-policy="automatic" \
      --data-file=-

  if [ -n "${GCP_SECRET_ACCESSORS:-}" ]; then
    for MEMBER in ${GCP_SECRET_ACCESSORS}; do
      echo "  re-applying roles/secretmanager.secretAccessor for ${MEMBER}..."
      gcloud secrets add-iam-policy-binding "${SECRET_ID}" \
        --project="${PROJECT_ID}" \
        --role="roles/secretmanager.secretAccessor" \
        --member="${MEMBER}" >/dev/null
    done
  fi
}

require_cmd gcloud
require_cmd printenv
require_file "${SECRETS_ENV_FILE}"
load_env
require_env PROJECT_ID "${PROJECT_ID:-}"

MAPPING_VARS="$(env | awk -F= '/^GCP_SECRET_[A-Z0-9_]+=/{print $1}' | grep -v '^GCP_SECRET_ACCESSORS$' | sort)"

if [ -z "${MAPPING_VARS}" ]; then
  echo "No GCP_SECRET_* mappings found in ${SECRETS_ENV_FILE}" >&2
  exit 1
fi

for MAPPING_VAR in ${MAPPING_VARS}; do
  sync_secret "${MAPPING_VAR}"
done

echo
echo "Synced secrets to GCP Secret Manager for project ${PROJECT_ID}."
