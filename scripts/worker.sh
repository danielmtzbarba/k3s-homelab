#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
WORKER_DIR="${ROOT_DIR}/infra/terraform/worker"
WORKER_SETUP_SCRIPT_LOCAL="${ROOT_DIR}/scripts/k3s_worker_setup.sh"
WORKER_SETUP_SCRIPT_REMOTE="~/k3s_worker_setup.sh"

usage() {
  cat <<'EOF'
Usage:
  sh scripts/worker.sh plan
  sh scripts/worker.sh apply
  sh scripts/worker.sh join
  sh scripts/worker.sh destroy
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

load_env() {
  if [ ! -f "${ENV_FILE}" ]; then
    echo ".env not found at ${ENV_FILE}" >&2
    exit 1
  fi

  set -a
  . "${ENV_FILE}"
  set +a

  : "${PROJECT_ID:?PROJECT_ID is required}"
  : "${ZONE:?ZONE is required}"
  : "${SERVER_NAME:?SERVER_NAME is required}"
  : "${WORKER_NAME:?WORKER_NAME is required}"
  TAILSCALE_ENABLE="${TAILSCALE_ENABLE:-false}"
  TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
  TAILSCALE_ACCEPT_DNS="${TAILSCALE_ACCEPT_DNS:-false}"
  TAILSCALE_WORKER_HOSTNAME="${TAILSCALE_WORKER_HOSTNAME:-${WORKER_NAME}}"
}

init_worker_stack() {
  cd "${WORKER_DIR}"
  sh ./generate_tf_files.sh
  terraform init -input=false -reconfigure -backend-config=backend.hcl
}

join_worker() {
  SERVER_PRIVATE_IP="$(gcloud compute instances describe "${SERVER_NAME}" --zone="${ZONE}" --format='value(networkInterfaces[0].networkIP)')"
  K3S_TOKEN="$(gcloud compute ssh "${SERVER_NAME}" --zone="${ZONE}" --command='sudo cat /var/lib/rancher/k3s/server/node-token' 2>/dev/null | tr -d '\r\n')"

  if [ -z "${SERVER_PRIVATE_IP}" ] || [ -z "${K3S_TOKEN}" ]; then
    echo "Could not determine server private IP or node token." >&2
    exit 1
  fi

  gcloud compute scp "${WORKER_SETUP_SCRIPT_LOCAL}" "${WORKER_NAME}:${WORKER_SETUP_SCRIPT_REMOTE}" --zone="${ZONE}"
  gcloud compute ssh "${WORKER_NAME}" --zone="${ZONE}" --command="chmod +x ${WORKER_SETUP_SCRIPT_REMOTE} && K3S_URL=https://${SERVER_PRIVATE_IP}:6443 K3S_TOKEN=${K3S_TOKEN} TAILSCALE_ENABLE=${TAILSCALE_ENABLE} TAILSCALE_AUTH_KEY=${TAILSCALE_AUTH_KEY} TAILSCALE_ACCEPT_DNS=${TAILSCALE_ACCEPT_DNS} TAILSCALE_HOSTNAME=${TAILSCALE_WORKER_HOSTNAME} sh ${WORKER_SETUP_SCRIPT_REMOTE}"
}

main() {
  if [ $# -ne 1 ]; then
    usage
    exit 1
  fi

  require_cmd gcloud
  require_cmd terraform
  load_env
  gcloud config set project "${PROJECT_ID}" >/dev/null

  case "$1" in
    plan)
      init_worker_stack
      terraform plan
      ;;
    apply)
      init_worker_stack
      terraform apply
      ;;
    join)
      join_worker
      ;;
    destroy)
      init_worker_stack
      terraform destroy
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
