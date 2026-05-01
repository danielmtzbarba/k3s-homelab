#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_ENV_FILE=""
RECREATE_EXISTING="false"
ENV_HELPER="${ROOT_DIR}/scripts/lib_env.sh"

usage() {
  cat <<'EOF'
Usage:
  sh scripts/sync_gcp_secrets.sh [--delete-existing] [path-to-env-file]

Behavior:
  - default: create missing secrets only, skip secrets that already exist
  - --delete-existing: delete and recreate existing secrets before syncing

Value resolution:
  - prefer <NAME> when it is set
  - otherwise use <NAME>_FILE and upload that file's contents
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --delete-existing)
        RECREATE_EXISTING="true"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
      *)
        if [ -n "${SECRETS_ENV_FILE}" ]; then
          echo "Only one env file path may be provided." >&2
          usage >&2
          exit 1
        fi
        SECRETS_ENV_FILE="$1"
        ;;
    esac
    shift
  done
}

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
  require_file "${ENV_HELPER}"
  # shellcheck disable=SC1090
  . "${ENV_HELPER}"
  load_gcp_secrets_env "${SECRETS_ENV_FILE:-}"
}

mapping_vars_from_env_file() {
  ENV_PATH="$1"
  awk -F= '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
      line = $0
      sub(/^[[:space:]]*export[[:space:]]+/, "", line)
      split(line, parts, "=")
      key = parts[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (key ~ /^GCP_SECRET_[A-Z0-9_]+$/ && key != "GCP_SECRET_ACCESSORS") {
        print key
      }
    }
  ' "${ENV_PATH}" | sort -u
}

sync_secret() {
  MAPPING_VAR="$1"
  SECRET_ID="$(printenv "${MAPPING_VAR}")"
  VALUE_VAR="${MAPPING_VAR#GCP_SECRET_}"
  VALUE_FILE_VAR="${VALUE_VAR}_FILE"

  if [ -z "${SECRET_ID}" ]; then
    echo "Skipping ${MAPPING_VAR}: empty secret ID." >&2
    return
  fi

  SECRET_VALUE="$(printenv "${VALUE_VAR}" || true)"
  SECRET_VALUE_FILE="$(printenv "${VALUE_FILE_VAR}" || true)"

  if [ -z "${SECRET_VALUE}" ] && [ -n "${SECRET_VALUE_FILE}" ]; then
    require_file "${SECRET_VALUE_FILE}"
    SECRET_VALUE="$(cat "${SECRET_VALUE_FILE}")"
  fi

  if [ -z "${SECRET_VALUE}" ]; then
    echo "Missing value variable for ${MAPPING_VAR}: set ${VALUE_VAR} or ${VALUE_FILE_VAR}" >&2
    exit 1
  fi

  if [ -n "${SECRET_VALUE_FILE}" ] && [ -z "$(printenv "${VALUE_VAR}" || true)" ]; then
    echo "Syncing ${SECRET_ID} from ${VALUE_FILE_VAR}..."
  else
    echo "Syncing ${SECRET_ID} from ${VALUE_VAR}..."
  fi

  if gcloud secrets describe "${SECRET_ID}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    if [ "${RECREATE_EXISTING}" = "true" ]; then
      echo "  deleting existing secret ${SECRET_ID} before recreation..."
      gcloud secrets delete "${SECRET_ID}" --project="${PROJECT_ID}" --quiet
    else
      echo "  secret ${SECRET_ID} already exists, skipping."
      return
    fi
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
parse_args "$@"
load_env
require_env PROJECT_ID "${PROJECT_ID:-}"

if [ -n "${SECRETS_ENV_FILE}" ]; then
  require_file "${SECRETS_ENV_FILE}"
  MAPPING_VARS="$(mapping_vars_from_env_file "${SECRETS_ENV_FILE}")"
else
  MAPPING_VARS="$(env | awk -F= '/^GCP_SECRET_[A-Z0-9_]+=/{print $1}' | grep -v '^GCP_SECRET_ACCESSORS$' | sort)"
fi

if [ -z "${MAPPING_VARS}" ]; then
  echo "No GCP_SECRET_* mappings found in ${SECRETS_ENV_FILE}" >&2
  exit 1
fi

for MAPPING_VAR in ${MAPPING_VARS}; do
  sync_secret "${MAPPING_VAR}"
done

echo
if [ "${RECREATE_EXISTING}" = "true" ]; then
  echo "Synced secrets to GCP Secret Manager for project ${PROJECT_ID} using delete/recreate mode."
else
  echo "Synced missing secrets to GCP Secret Manager for project ${PROJECT_ID}; existing secrets were skipped."
fi
