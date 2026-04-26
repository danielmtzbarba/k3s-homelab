#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
ENV_HELPER="${ROOT_DIR}/scripts/lib_env.sh"
WORKER_DIR="${ROOT_DIR}/infra/terraform/worker"
WORKER_SETUP_SCRIPT_LOCAL="${ROOT_DIR}/scripts/k3s_worker_setup.sh"
WORKER_SETUP_SCRIPT_REMOTE="~/k3s_worker_setup.sh"

usage() {
  cat <<'EOF'
Usage:
  sh scripts/worker.sh plan
  sh scripts/worker.sh apply
  sh scripts/worker.sh label-nodes
  sh scripts/worker.sh join [worker-name]
  sh scripts/worker.sh destroy
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

load_env() {
  if [ ! -f "${ENV_FILE}" ]; then
    require_file "${ENV_HELPER}"
  fi

  require_file "${ENV_HELPER}"
  # shellcheck disable=SC1090
  . "${ENV_HELPER}"
  load_infra_env

  : "${PROJECT_ID:?PROJECT_ID is required}"
  : "${ZONE:?ZONE is required}"
  : "${SERVER_NAME:?SERVER_NAME is required}"
  TAILSCALE_ENABLE="${TAILSCALE_ENABLE:-false}"
  TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
  TAILSCALE_ACCEPT_DNS="${TAILSCALE_ACCEPT_DNS:-false}"
}

worker_node_labels_json() {
  if [ -n "${WORKERS_JSON:-}" ]; then
    python3 - <<'PY'
import json
import os
import sys

workers = json.loads(os.environ["WORKERS_JSON"])
result = {}
for name, worker in workers.items():
    labels = worker.get("node_labels") or []
    if labels:
        result[name] = labels
print(json.dumps(result))
PY
    return
  fi

  if [ -n "${WORKER_NAME:-}" ] && [ -n "${WORKER_NODE_LABELS:-}" ]; then
    python3 - <<'PY'
import json
import os

labels = [item.strip() for item in os.environ["WORKER_NODE_LABELS"].split(",") if item.strip()]
print(json.dumps({os.environ["WORKER_NAME"]: labels} if labels else {}))
PY
    return
  fi

  printf '%s\n' '{}'
}

label_worker_nodes() {
  require_cmd kubectl

  WORKER_LABELS_JSON="$(worker_node_labels_json)"

  if [ "${WORKER_LABELS_JSON}" = "{}" ]; then
    echo "No worker node labels configured; skipping node label reconciliation."
    return
  fi

  WORKER_LABELS_JSON="${WORKER_LABELS_JSON}" python3 - <<'PY' | while IFS='|' read -r worker node_labels; do
import json
import os

data = json.loads(os.environ["WORKER_LABELS_JSON"])
for worker, labels in data.items():
    print(f"{worker}|{' '.join(labels)}")
PY
    if [ -z "${node_labels}" ]; then
      continue
    fi
    node_name="$(kubectl get nodes -o name | sed 's|^node/||' | grep "^${worker}\." | head -n 1 || true)"
    if [ -z "${node_name}" ]; then
      echo "Could not find Kubernetes node for worker ${worker}; skipping label reconciliation." >&2
      continue
    fi
    # shellcheck disable=SC2086
    kubectl label node "${node_name}" ${node_labels} --overwrite
  done
}

init_worker_stack() {
  cd "${WORKER_DIR}"
  sh ./generate_tf_files.sh
  terraform init -input=false -reconfigure -backend-config=backend.hcl
}

join_worker() {
  TARGET_WORKER_NAME="${1:-${WORKER_NAME:-}}"

  if [ -z "${TARGET_WORKER_NAME}" ]; then
    echo "WORKER_NAME is required for join, or pass the worker name explicitly." >&2
    exit 1
  fi

  TARGET_TAILSCALE_HOSTNAME="${TAILSCALE_WORKER_HOSTNAME:-${TARGET_WORKER_NAME}}"
  SERVER_PRIVATE_IP="$(gcloud compute instances describe "${SERVER_NAME}" --zone="${ZONE}" --format='value(networkInterfaces[0].networkIP)')"
  K3S_TOKEN="$(gcloud compute ssh "${SERVER_NAME}" --zone="${ZONE}" --command='sudo cat /var/lib/rancher/k3s/server/node-token' 2>/dev/null | tr -d '\r\n')"

  if [ -z "${SERVER_PRIVATE_IP}" ] || [ -z "${K3S_TOKEN}" ]; then
    echo "Could not determine server private IP or node token." >&2
    exit 1
  fi

  gcloud compute scp "${WORKER_SETUP_SCRIPT_LOCAL}" "${TARGET_WORKER_NAME}:${WORKER_SETUP_SCRIPT_REMOTE}" --zone="${ZONE}"
  gcloud compute ssh "${TARGET_WORKER_NAME}" --zone="${ZONE}" --command="chmod +x ${WORKER_SETUP_SCRIPT_REMOTE} && K3S_URL=https://${SERVER_PRIVATE_IP}:6443 K3S_TOKEN=${K3S_TOKEN} TAILSCALE_ENABLE=${TAILSCALE_ENABLE} TAILSCALE_AUTH_KEY=${TAILSCALE_AUTH_KEY} TAILSCALE_ACCEPT_DNS=${TAILSCALE_ACCEPT_DNS} TAILSCALE_HOSTNAME=${TARGET_TAILSCALE_HOSTNAME} sh ${WORKER_SETUP_SCRIPT_REMOTE}"
}

main() {
  if [ $# -lt 1 ] || [ $# -gt 2 ]; then
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
      label_worker_nodes
      ;;
    label-nodes)
      label_worker_nodes
      ;;
    join)
      join_worker "${2:-}"
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
