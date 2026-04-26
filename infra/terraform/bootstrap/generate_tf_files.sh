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

cat > terraform.auto.tfvars <<EOF
project_id                  = "${PROJECT_ID}"
tf_state_bucket             = "${TF_STATE_BUCKET}"
tf_state_location           = "${TF_STATE_LOCATION}"
delete_old_versions         = ${TF_STATE_DELETE_OLD_VERSIONS}
noncurrent_version_age_days = ${TF_STATE_NONCURRENT_VERSION_AGE_DAYS}
force_destroy               = ${TF_STATE_FORCE_DESTROY}
EOF

echo "Generated terraform.auto.tfvars in $(pwd)"
