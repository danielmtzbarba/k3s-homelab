#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
SERVER_SETUP_SCRIPT_LOCAL="${ROOT_DIR}/scripts/k3s_server_setup.sh"
SERVER_SETUP_SCRIPT_REMOTE="~/k3s_server_setup.sh"

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

DEST="${HOME}/.kube/config-k3s-lab"
TMP_FILE="$(mktemp)"

mkdir -p "${HOME}/.kube"

echo "Copying server setup script to VM..."
gcloud compute scp "${SERVER_SETUP_SCRIPT_LOCAL}" "${SERVER_NAME}:${SERVER_SETUP_SCRIPT_REMOTE}" --zone="${ZONE}"

echo "Running server setup script on VM..."
gcloud compute ssh "${SERVER_NAME}" --zone="${ZONE}" --command="chmod +x ${SERVER_SETUP_SCRIPT_REMOTE} && sh ${SERVER_SETUP_SCRIPT_REMOTE}"

echo "Fetching kubeconfig from VM..."
if ! gcloud compute ssh "${SERVER_NAME}" --zone="${ZONE}" --command="sudo cat /etc/rancher/k3s/k3s.yaml" > "${TMP_FILE}"; then
  echo "Could not read /etc/rancher/k3s/k3s.yaml from the server." >&2
  rm -f "${TMP_FILE}"
  exit 1
fi

SERVER_IP="$(gcloud compute instances describe "${SERVER_NAME}" --zone="${ZONE}" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"

if [ -z "${SERVER_IP}" ]; then
  echo "Could not determine public IP for ${SERVER_NAME}." >&2
  rm -f "${TMP_FILE}"
  exit 1
fi

sed "s#https://127.0.0.1:6443#https://${SERVER_IP}:6443#g" "${TMP_FILE}" > "${DEST}"
rm -f "${TMP_FILE}"

echo "Wrote kubeconfig to ${DEST}"
echo "Export it with:"
echo "  export KUBECONFIG=\"${DEST}\""
