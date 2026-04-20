#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo ".env not found at ${ENV_FILE}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

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
EOF

cat > backend.hcl <<EOF
bucket = "${TF_STATE_BUCKET}"
prefix = "${TF_STATE_PREFIX}"
EOF

echo "Generated terraform.auto.tfvars and backend.hcl in $(pwd)"
