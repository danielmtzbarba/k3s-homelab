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

cat > terraform.auto.tfvars <<EOF
project_id                  = "${PROJECT_ID}"
tf_state_bucket             = "${TF_STATE_BUCKET}"
tf_state_location           = "${TF_STATE_LOCATION}"
delete_old_versions         = ${TF_STATE_DELETE_OLD_VERSIONS}
noncurrent_version_age_days = ${TF_STATE_NONCURRENT_VERSION_AGE_DAYS}
EOF

echo "Generated terraform.auto.tfvars in $(pwd)"
