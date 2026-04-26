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

cat > terraform.auto.tfvars <<EOF
project_id       = "${PROJECT_ID}"
region           = "${REGION}"
zone             = "${ZONE}"
network_name     = "${NETWORK_NAME}"
subnet_name      = "${SUBNET_NAME}"
subnet_cidr      = "${SUBNET_CIDR}"
cluster_tag      = "${CLUSTER_TAG:-$SERVER_TAG}"
server_name      = "${SERVER_NAME}"
server_tag       = "${SERVER_TAG}"
address_name     = "${ADDRESS_NAME}"
machine_type     = "${MACHINE_TYPE}"
image_family     = "${IMAGE_FAMILY}"
image_project    = "${IMAGE_PROJECT}"
ssh_source_range = "${SSH_SOURCE_RANGE}"
public_ssh_enable = ${PUBLIC_SSH_ENABLE:-true}
ssh_user         = "${SSH_USER}"
ssh_public_key   = "${SSH_PUBLIC_KEY}"
boot_disk_size_gb = ${BOOT_DISK_SIZE_GB}
tailscale_enable = ${TAILSCALE_ENABLE:-false}
tailscale_auth_key = "${TAILSCALE_AUTH_KEY:-}"
tailscale_accept_dns = ${TAILSCALE_ACCEPT_DNS:-false}
tailscale_hostname = "${TAILSCALE_HOSTNAME:-$SERVER_NAME}"
k3s_cluster_token = "${K3S_CLUSTER_TOKEN:-}"
k8s_service_account_issuer_enable = ${K8S_SERVICE_ACCOUNT_ISSUER_ENABLE:-false}
k8s_service_account_issuer_url = "${K8S_SERVICE_ACCOUNT_ISSUER_URL:-}"
k8s_service_account_jwks_uri = "${K8S_SERVICE_ACCOUNT_JWKS_URI:-}"
EOF

cat > backend.hcl <<EOF
bucket = "${TF_STATE_BUCKET}"
prefix = "${TF_STATE_PREFIX}"
EOF

echo "Generated terraform.auto.tfvars and backend.hcl in $(pwd)"
