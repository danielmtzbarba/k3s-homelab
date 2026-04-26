#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
ENV_HELPER="${ROOT_DIR}/scripts/lib_env.sh"
REMOTE_LIB="${ROOT_DIR}/scripts/lib_remote_access.sh"

if [ ! -f "${ENV_HELPER}" ]; then
  echo "Env helper not found at ${ENV_HELPER}" >&2
  exit 1
fi

if [ ! -f "${REMOTE_LIB}" ]; then
  echo "Remote access helper not found at ${REMOTE_LIB}" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "${REMOTE_LIB}"
# shellcheck disable=SC1090
. "${ENV_HELPER}"

load_infra_env

: "${SERVER_NAME:?SERVER_NAME is required in infra env}"
: "${ZONE:?ZONE is required in infra env}"

KUBECONFIG_ENDPOINT_MODE="${KUBECONFIG_ENDPOINT_MODE:-public}"
REMOTE_MODE="$(remote_access_mode)"

remote_require_mode_prereqs

DEST="${HOME}/.kube/config-k3s-lab"
TMP_FILE="$(mktemp)"
TMP_OUTPUT_FILE="$(mktemp)"
REMOTE_FETCH_CMD="echo '__CODEX_TAILSCALE_IP_START__' && tailscale ip -4 2>/dev/null | head -n 1 && echo '__CODEX_TAILSCALE_IP_END__' && echo '__CODEX_KUBECONFIG_START__' && sudo cat /etc/rancher/k3s/k3s.yaml && echo '__CODEX_KUBECONFIG_END__'"

mkdir -p "${HOME}/.kube"

echo "Fetching kubeconfig from server..."
if [ "${REMOTE_MODE}" = "tailscale" ]; then
  ssh-keygen -R "${TAILSCALE_HOSTNAME:-${SERVER_NAME}}" >/dev/null 2>&1 || true
fi
ATTEMPTS=0
MAX_ATTEMPTS=30
SLEEP_SECONDS=5

while ! remote_run "${REMOTE_FETCH_CMD}" > "${TMP_OUTPUT_FILE}"; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "${ATTEMPTS}" -ge "${MAX_ATTEMPTS}" ]; then
    break
  fi

  if [ "${REMOTE_MODE}" = "tailscale" ]; then
    echo "Server is not reachable over the tailnet yet; waiting ${SLEEP_SECONDS}s before retry ${ATTEMPTS}/${MAX_ATTEMPTS}..."
  else
    echo "Server SSH is not reachable yet; waiting ${SLEEP_SECONDS}s before retry ${ATTEMPTS}/${MAX_ATTEMPTS}..."
  fi
  sleep "${SLEEP_SECONDS}"
done

if [ ! -s "${TMP_OUTPUT_FILE}" ]; then
  echo "Could not retrieve kubeconfig from the server." >&2
  rm -f "${TMP_OUTPUT_FILE}"
  rm -f "${TMP_FILE}"
  exit 1
fi

if [ "${KUBECONFIG_ENDPOINT_MODE}" = "tailscale" ]; then
  SERVER_IP="$(awk '
    /__CODEX_TAILSCALE_IP_START__/ {capture=1; next}
    /__CODEX_TAILSCALE_IP_END__/ {capture=0; exit}
    capture && $0 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print; exit}
  ' "${TMP_OUTPUT_FILE}" | tr -d '\r')"
else
  SERVER_IP="$(gcloud compute instances describe "${SERVER_NAME}" --zone="${ZONE}" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
fi

if [ -z "${SERVER_IP}" ]; then
  echo "Could not determine ${KUBECONFIG_ENDPOINT_MODE} IP for ${SERVER_NAME}." >&2
  rm -f "${TMP_OUTPUT_FILE}"
  rm -f "${TMP_FILE}"
  exit 1
fi

awk '
  /__CODEX_KUBECONFIG_START__/ {capture=1; next}
  /__CODEX_KUBECONFIG_END__/ {capture=0; exit}
  capture {print}
' "${TMP_OUTPUT_FILE}" > "${TMP_FILE}"

if [ ! -s "${TMP_FILE}" ]; then
  echo "Could not extract kubeconfig content from the server output." >&2
  rm -f "${TMP_OUTPUT_FILE}"
  rm -f "${TMP_FILE}"
  exit 1
fi

sed "s#https://127.0.0.1:6443#https://${SERVER_IP}:6443#g" "${TMP_FILE}" > "${DEST}"
rm -f "${TMP_OUTPUT_FILE}"
rm -f "${TMP_FILE}"

echo "Wrote kubeconfig to ${DEST}"
echo "Export it with:"
echo "  export KUBECONFIG=\"${DEST}\""
