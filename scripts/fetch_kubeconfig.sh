#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
SERVER_SETUP_SCRIPT_LOCAL="${ROOT_DIR}/scripts/k3s_server_setup.sh"
SERVER_SETUP_SCRIPT_REMOTE="~/k3s_server_setup.sh"
SERVER_SETUP_ENV_REMOTE="~/k3s_server_setup.env"

if [ ! -f "${ENV_FILE}" ]; then
  echo ".env not found at ${ENV_FILE}" >&2
  exit 1
fi

if [ ! -f "${SERVER_SETUP_SCRIPT_LOCAL}" ]; then
  echo "Server setup script not found at ${SERVER_SETUP_SCRIPT_LOCAL}" >&2
  exit 1
fi

set -a
. "${ENV_FILE}"
set +a

: "${SERVER_NAME:?SERVER_NAME is required in .env}"
: "${ZONE:?ZONE is required in .env}"

TAILSCALE_ENABLE="${TAILSCALE_ENABLE:-false}"
TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-${SERVER_NAME}}"
TAILSCALE_ACCEPT_DNS="${TAILSCALE_ACCEPT_DNS:-false}"
KUBECONFIG_ENDPOINT_MODE="${KUBECONFIG_ENDPOINT_MODE:-public}"

DEST="${HOME}/.kube/config-k3s-lab"
TMP_FILE="$(mktemp)"
TMP_ENV_FILE="$(mktemp)"
TMP_OUTPUT_FILE="$(mktemp)"

mkdir -p "${HOME}/.kube"

cat > "${TMP_ENV_FILE}" <<EOF
TAILSCALE_ENABLE="${TAILSCALE_ENABLE}"
TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME}"
TAILSCALE_ACCEPT_DNS="${TAILSCALE_ACCEPT_DNS}"
EOF

echo "Copying server setup script to VM..."
gcloud compute scp "${SERVER_SETUP_SCRIPT_LOCAL}" "${SERVER_NAME}:${SERVER_SETUP_SCRIPT_REMOTE}" --zone="${ZONE}"
gcloud compute scp "${TMP_ENV_FILE}" "${SERVER_NAME}:${SERVER_SETUP_ENV_REMOTE}" --zone="${ZONE}"

echo "Running server setup script on VM..."
if ! gcloud compute ssh "${SERVER_NAME}" --zone="${ZONE}" --command="set -a && . ${SERVER_SETUP_ENV_REMOTE} && set +a && chmod +x ${SERVER_SETUP_SCRIPT_REMOTE} && sh ${SERVER_SETUP_SCRIPT_REMOTE} && rm -f ${SERVER_SETUP_ENV_REMOTE} && echo '__CODEX_TAILSCALE_IP_START__' && tailscale ip -4 2>/dev/null | head -n 1 && echo '__CODEX_TAILSCALE_IP_END__' && echo '__CODEX_KUBECONFIG_START__' && sudo cat /etc/rancher/k3s/k3s.yaml && echo '__CODEX_KUBECONFIG_END__'" > "${TMP_OUTPUT_FILE}"; then
  echo "Could not complete server setup and kubeconfig retrieval from the server." >&2
  rm -f "${TMP_ENV_FILE}"
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
  rm -f "${TMP_ENV_FILE}"
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
  rm -f "${TMP_ENV_FILE}"
  rm -f "${TMP_OUTPUT_FILE}"
  rm -f "${TMP_FILE}"
  exit 1
fi

sed "s#https://127.0.0.1:6443#https://${SERVER_IP}:6443#g" "${TMP_FILE}" > "${DEST}"
rm -f "${TMP_ENV_FILE}"
rm -f "${TMP_OUTPUT_FILE}"
rm -f "${TMP_FILE}"

echo "Wrote kubeconfig to ${DEST}"
echo "Export it with:"
echo "  export KUBECONFIG=\"${DEST}\""
