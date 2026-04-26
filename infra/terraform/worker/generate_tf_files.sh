#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_HELPER="${ROOT_DIR}/scripts/lib_env.sh"

if [[ ! -f "${ENV_HELPER}" ]]; then
  echo "Env helper not found at ${ENV_HELPER}" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_HELPER}"
load_infra_env

if [[ -z "${SSH_PUBLIC_KEY_PATH:-}" || ! -f "${SSH_PUBLIC_KEY_PATH}" ]]; then
  echo "SSH_PUBLIC_KEY_PATH is missing or points to a non-existent file." >&2
  exit 1
fi

SSH_PUBLIC_KEY="$(tr -d '\n' < "${SSH_PUBLIC_KEY_PATH}")"
WORKER_PREFIX="${TF_STATE_WORKER_PREFIX:-worker}"
CLUSTER_NODE_TAG="${CLUSTER_TAG:-${SERVER_TAG}}"
DEFAULT_WORKER_TAG="${WORKER_TAG:-k3s-worker}"
DEFAULT_MACHINE_TYPE="${WORKER_MACHINE_TYPE:-e2-standard-2}"
DEFAULT_BOOT_DISK_SIZE_GB="${BOOT_DISK_SIZE_GB:-40}"
DEFAULT_WORKER_NAME="${WORKER_NAME:-k3s-worker-1}"
DEFAULT_WORKER_INTERNAL_IP="${WORKER_INTERNAL_IP:-10.10.0.3}"
DEFAULT_TAILSCALE_HOSTNAME="${TAILSCALE_WORKER_HOSTNAME:-${DEFAULT_WORKER_NAME}}"
DEFAULT_TAILSCALE_AUTH_KEY="${TAILSCALE_WORKER_AUTH_KEY:-${TAILSCALE_AUTH_KEY:-}}"

normalize_k3s_cluster_token() {
  local token="${1:-}"

  if [[ "${token}" == *"::"* ]]; then
    printf '%s' "${token##*::}"
    return
  fi

  printf '%s' "${token}"
}

K3S_CLUSTER_TOKEN_NORMALIZED="$(normalize_k3s_cluster_token "${K3S_CLUSTER_TOKEN:-}")"

render_workers_hcl() {
  if [[ -n "${WORKERS_TFVARS_PATH:-}" ]]; then
    if [[ ! -f "${WORKERS_TFVARS_PATH}" ]]; then
      echo "WORKERS_TFVARS_PATH points to a non-existent file: ${WORKERS_TFVARS_PATH}" >&2
      exit 1
    fi
    cat "${WORKERS_TFVARS_PATH}"
    return
  fi

  if [[ -n "${WORKERS_JSON:-}" ]]; then
    python3 - <<'PY'
import json
import os
import sys

raw = os.environ["WORKERS_JSON"]

try:
    workers = json.loads(raw)
except json.JSONDecodeError as exc:
    stripped = raw.strip()
    if stripped.startswith("{") and "=" in stripped:
        print(stripped)
        raise SystemExit(0)
    raise SystemExit(
        "WORKERS_JSON is not valid JSON. "
        "Use real JSON, or provide an HCL-style object literal in WORKERS_JSON/WORKERS_TFVARS_PATH. "
        f"JSON error: {exc}"
    )

if not isinstance(workers, dict) or not workers:
    raise SystemExit("WORKERS_JSON must decode to a non-empty object keyed by worker name.")

print("{")
for name, worker in workers.items():
    if not isinstance(worker, dict):
        raise SystemExit(f"Worker {name!r} must be an object.")
    if "internal_ip" not in worker or not worker["internal_ip"]:
        raise SystemExit(f"Worker {name!r} is missing required field internal_ip.")
    print(f"  {json.dumps(name)} = {{")
    print(f"    internal_ip = {json.dumps(worker['internal_ip'])}")
    if worker.get("worker_tag"):
        print(f"    worker_tag = {json.dumps(worker['worker_tag'])}")
    if worker.get("machine_type"):
        print(f"    machine_type = {json.dumps(worker['machine_type'])}")
    if worker.get("boot_disk_size_gb") is not None:
        print(f'    boot_disk_size_gb = {worker["boot_disk_size_gb"]}')
    if worker.get("tailscale_auth_key"):
        print(f"    tailscale_auth_key = {json.dumps(worker['tailscale_auth_key'])}")
    if worker.get("tailscale_hostname"):
        print(f"    tailscale_hostname = {json.dumps(worker['tailscale_hostname'])}")
    print("  }")
print("}")
PY
    return
  fi

  cat <<EOF
{
  "${DEFAULT_WORKER_NAME}" = {
    internal_ip = "${DEFAULT_WORKER_INTERNAL_IP}"
    worker_tag = "${DEFAULT_WORKER_TAG}"
    machine_type = "${DEFAULT_MACHINE_TYPE}"
    boot_disk_size_gb = ${DEFAULT_BOOT_DISK_SIZE_GB}
    tailscale_auth_key = "${DEFAULT_TAILSCALE_AUTH_KEY}"
    tailscale_hostname = "${DEFAULT_TAILSCALE_HOSTNAME}"
  }
}
EOF
}

WORKERS_HCL="$(render_workers_hcl)"

cat > terraform.auto.tfvars <<EOF
project_id         = "${PROJECT_ID}"
region             = "${REGION}"
zone               = "${ZONE}"
network_name       = "${NETWORK_NAME}"
subnet_name        = "${SUBNET_NAME}"
cluster_tag        = "${CLUSTER_NODE_TAG}"
server_name        = "${SERVER_NAME}"
workers            = ${WORKERS_HCL}
worker_tag         = "${DEFAULT_WORKER_TAG}"
machine_type       = "${DEFAULT_MACHINE_TYPE}"
image_family       = "${IMAGE_FAMILY}"
image_project      = "${IMAGE_PROJECT}"
ssh_user           = "${SSH_USER}"
ssh_public_key     = "${SSH_PUBLIC_KEY}"
boot_disk_size_gb  = ${DEFAULT_BOOT_DISK_SIZE_GB}
tailscale_enable   = ${TAILSCALE_ENABLE:-false}
tailscale_auth_key = "${DEFAULT_TAILSCALE_AUTH_KEY}"
tailscale_accept_dns = ${TAILSCALE_ACCEPT_DNS:-false}
k3s_cluster_token  = "${K3S_CLUSTER_TOKEN_NORMALIZED}"
EOF

cat > backend.hcl <<EOF
bucket = "${TF_STATE_BUCKET}"
prefix = "${WORKER_PREFIX}"
EOF

echo "Generated terraform.auto.tfvars and backend.hcl in $(pwd)"
