#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_APP_ROOT="/home/danielmtz/Projects/algotrading/mt5-quant-server"
APP_ROOT="${DEFAULT_APP_ROOT}"
BASE_GCP_ENV_FILE=""
ENV_HELPER="${ROOT_DIR}/scripts/lib_env.sh"
ENVIRONMENT=""
RECREATE_EXISTING="false"

usage() {
  cat <<'EOF'
Usage:
  sh scripts/sync_quant_engine_envs_to_gcp.sh --environment <dev|prod> [options]

Options:
  --environment <dev|prod>  Target quant-engine environment to populate.
  --app-root <path>         Path to the mt5-quant-server repo.
  --base-gcp-env <path>     Path to an env source with PROJECT_ID and optional GCP_SECRET_ACCESSORS.
  --delete-existing         Delete and recreate matching GCP secrets before syncing.
  -h, --help                Show this help.

Reads:
  <app-root>/infra/envs/core.env
  <app-root>/infra/envs/messaging.env
  <app-root>/infra/envs/sync.env
  <app-root>/infra/envs/mt5.env

Bundles sensitive variables into:
  k3s-quant-engine-<env>-core-env
  k3s-quant-engine-<env>-messaging-env
  k3s-quant-engine-<env>-sync-env
  k3s-quant-engine-mt5-env

Then uploads them through scripts/sync_gcp_secrets.sh.
EOF
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

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --environment)
        shift
        ENVIRONMENT="${1:-}"
        ;;
      --app-root)
        shift
        APP_ROOT="${1:-}"
        ;;
      --base-gcp-env)
        shift
        BASE_GCP_ENV_FILE="${1:-}"
        ;;
      --delete-existing)
        RECREATE_EXISTING="true"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done
}

load_env_file() {
  set -a
  . "$1"
  set +a
}

json_bundle_from_env() {
  python3 - "$@" <<'PY'
import json
import os
import sys

keys = sys.argv[1:]
payload = {}
missing = []
for key in keys:
    value = os.environ.get(key)
    if value is None or value == "":
        missing.append(key)
    else:
        payload[key] = value

if missing:
    sys.stderr.write("Missing required env values: " + ", ".join(missing) + "\n")
    sys.exit(1)

print(json.dumps(payload, separators=(",", ":")))
PY
}

write_temp_env() {
  env_key_prefix="$1"
  core_json="$2"
  messaging_json="$3"
  sync_json="$4"
  mt5_json="$5"
  output_file="$6"

  {
    printf 'PROJECT_ID="%s"\n' "${PROJECT_ID}"
    if [ -n "${GCP_SECRET_ACCESSORS:-}" ]; then
      printf 'GCP_SECRET_ACCESSORS="%s"\n' "${GCP_SECRET_ACCESSORS}"
    fi
    printf 'GCP_SECRET_%s_CORE_ENV="k3s-quant-engine-%s-core-env"\n' "${env_key_prefix}" "${ENVIRONMENT}"
    printf "%s_CORE_ENV='%s'\n" "${env_key_prefix}" "${core_json}"
    printf 'GCP_SECRET_%s_MESSAGING_ENV="k3s-quant-engine-%s-messaging-env"\n' "${env_key_prefix}" "${ENVIRONMENT}"
    printf "%s_MESSAGING_ENV='%s'\n" "${env_key_prefix}" "${messaging_json}"
    printf 'GCP_SECRET_%s_SYNC_ENV="k3s-quant-engine-%s-sync-env"\n' "${env_key_prefix}" "${ENVIRONMENT}"
    printf "%s_SYNC_ENV='%s'\n" "${env_key_prefix}" "${sync_json}"
    printf 'GCP_SECRET_QUANT_ENGINE_MT5_ENV="k3s-quant-engine-mt5-env"\n'
    printf "QUANT_ENGINE_MT5_ENV='%s'\n" "${mt5_json}"
  } > "${output_file}"
}

parse_args "$@"

if [ -z "${ENVIRONMENT}" ]; then
  echo "--environment is required." >&2
  usage >&2
  exit 1
fi

case "${ENVIRONMENT}" in
  dev|prod)
    ;;
  *)
    echo "Unsupported environment: ${ENVIRONMENT}. Use dev or prod." >&2
    exit 1
    ;;
esac

require_cmd python3
require_file "${ENV_HELPER}"
require_file "${APP_ROOT}/infra/envs/core.env"
require_file "${APP_ROOT}/infra/envs/messaging.env"
require_file "${APP_ROOT}/infra/envs/sync.env"
require_file "${APP_ROOT}/infra/envs/mt5.env"

# shellcheck disable=SC1090
. "${ENV_HELPER}"
load_gcp_secrets_env "${BASE_GCP_ENV_FILE:-}"

if [ -z "${PROJECT_ID:-}" ]; then
  echo "PROJECT_ID must be set in ${BASE_GCP_ENV_FILE}" >&2
  exit 1
fi

load_env_file "${APP_ROOT}/infra/envs/core.env"
CORE_JSON="$(json_bundle_from_env CORE_DATABASE_URL CORE_ADMIN_TOKEN CORE_SHARED_BROKER_ACCOUNT_NUMBER CORE_SHARED_BROKER_MT5_LOGIN CORE_SHARED_BROKER_SERVER_NAME)"

load_env_file "${APP_ROOT}/infra/envs/messaging.env"
MESSAGING_JSON="$(json_bundle_from_env MSG_WHATSAPP_URL MSG_WHATSAPP_API_TOKEN MSG_WHATSAPP_AUTH_TOKEN MSG_OPENAI_API_KEY)"

load_env_file "${APP_ROOT}/infra/envs/sync.env"
SYNC_JSON="$(json_bundle_from_env SYNC_CORE_ADMIN_TOKEN SYNC_MT5_LOGIN SYNC_INFLUX_TOKEN)"

load_env_file "${APP_ROOT}/infra/envs/mt5.env"
MT5_JSON="$(json_bundle_from_env MT5_LOGIN MT5_PASSWORD MT5_SERVER)"

ENV_KEY_PREFIX="QUANT_ENGINE_$(printf '%s' "${ENVIRONMENT}" | tr '[:lower:]' '[:upper:]')"
TMP_ENV_FILE="$(mktemp)"
trap 'rm -f "${TMP_ENV_FILE}"' EXIT INT TERM

write_temp_env "${ENV_KEY_PREFIX}" "${CORE_JSON}" "${MESSAGING_JSON}" "${SYNC_JSON}" "${MT5_JSON}" "${TMP_ENV_FILE}"

echo "Generated bundled quant-engine secrets for ${ENVIRONMENT} from:"
echo "  ${APP_ROOT}/infra/envs/core.env"
echo "  ${APP_ROOT}/infra/envs/messaging.env"
echo "  ${APP_ROOT}/infra/envs/sync.env"
echo "  ${APP_ROOT}/infra/envs/mt5.env"

if [ "${RECREATE_EXISTING}" = "true" ]; then
  sh "${ROOT_DIR}/scripts/sync_gcp_secrets.sh" --delete-existing "${TMP_ENV_FILE}"
else
  sh "${ROOT_DIR}/scripts/sync_gcp_secrets.sh" "${TMP_ENV_FILE}"
fi
