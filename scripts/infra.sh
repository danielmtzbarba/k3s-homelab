#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
BOOTSTRAP_DIR="${ROOT_DIR}/infra/terraform/bootstrap"
SERVER_DIR="${ROOT_DIR}/infra/terraform/server"
WORKER_DIR="${ROOT_DIR}/infra/terraform/worker"

usage() {
  cat <<'EOF'
Usage:
  sh scripts/infra.sh bootstrap
  sh scripts/infra.sh plan
  sh scripts/infra.sh apply
  sh scripts/infra.sh server-setup
  sh scripts/infra.sh kubeconfig
  sh scripts/infra.sh deploy-addons
  sh scripts/infra.sh destroy
  sh scripts/infra.sh worker-destroy
  sh scripts/infra.sh destroy-backend
  sh scripts/infra.sh nuke
  sh scripts/infra.sh status

Commands:
  bootstrap       Create or reconcile the Terraform backend bucket.
  plan            Generate server Terraform inputs and run terraform plan.
  apply           Generate server Terraform inputs and run terraform apply.
  server-setup    Copy and run the VM-side k3s server setup script.
  kubeconfig      Fetch kubeconfig from the server and rewrite it for local use.
  deploy-addons   Install cluster add-ons such as cert-manager and TLS ingress.
  destroy         Destroy the server infrastructure stack.
  worker-destroy  Destroy the worker infrastructure stack.
  destroy-backend Destroy the backend bucket stack.
  nuke            Destroy worker, server, and then the backend bucket stack.
  status          Show a high-level status view of both Terraform stacks.
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
  require_file "${ENV_FILE}"
  set -a
  . "${ENV_FILE}"
  set +a
}

validate_env() {
  : "${PROJECT_ID:?PROJECT_ID is required in .env}"
  : "${ZONE:?ZONE is required in .env}"
  : "${SERVER_NAME:?SERVER_NAME is required in .env}"
  : "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required in .env}"
}

validate_prereqs() {
  require_cmd gcloud
  require_cmd terraform
  load_env
  validate_env

  if [ -n "${SSH_PUBLIC_KEY_PATH:-}" ] && [ ! -f "${SSH_PUBLIC_KEY_PATH}" ]; then
    echo "SSH public key file not found: ${SSH_PUBLIC_KEY_PATH}" >&2
    exit 1
  fi
}

run_server_setup() {
  echo "Running k3s server setup on VM..."
  cd "${ROOT_DIR}"
  TMP_SERVER_ENV="$(mktemp)"
  cat > "${TMP_SERVER_ENV}" <<EOF
TAILSCALE_ENABLE="${TAILSCALE_ENABLE:-false}"
TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-${SERVER_NAME}}"
TAILSCALE_ACCEPT_DNS="${TAILSCALE_ACCEPT_DNS:-false}"
EOF
  gcloud compute scp "./scripts/k3s_server_setup.sh" "${SERVER_NAME}:~/k3s_server_setup.sh" --zone="${ZONE}"
  gcloud compute scp "${TMP_SERVER_ENV}" "${SERVER_NAME}:~/k3s_server_setup.env" --zone="${ZONE}"
  gcloud compute ssh "${SERVER_NAME}" --zone="${ZONE}" --command="set -a && . ~/k3s_server_setup.env && set +a && chmod +x ~/k3s_server_setup.sh && sh ~/k3s_server_setup.sh && rm -f ~/k3s_server_setup.env"
  rm -f "${TMP_SERVER_ENV}"
}

set_gcloud_project() {
  gcloud config set project "${PROJECT_ID}" >/dev/null
}

terraform_init_local() {
  terraform init -input=false
}

terraform_init_remote() {
  terraform init -input=false -reconfigure -backend-config=backend.hcl
}

run_bootstrap() {
  echo "Bootstrapping Terraform backend bucket..."
  cd "${BOOTSTRAP_DIR}"
  sh ./generate_tf_files.sh
  terraform_init_local
  terraform apply
}

run_server_plan() {
  echo "Planning server infrastructure..."
  cd "${SERVER_DIR}"
  sh ./generate_tf_files.sh
  terraform_init_remote
  terraform plan
}

run_server_apply() {
  echo "Applying server infrastructure..."
  cd "${SERVER_DIR}"
  sh ./generate_tf_files.sh
  terraform_init_remote
  terraform apply
}

run_kubeconfig() {
  echo "Fetching kubeconfig..."
  cd "${ROOT_DIR}"
  sh ./scripts/fetch_kubeconfig.sh
}

run_deploy_addons() {
  echo "Deploying cluster add-ons..."
  cd "${ROOT_DIR}"
  sh ./scripts/deploy_cluster_addons.sh
}

run_destroy_server() {
  echo "Destroying server infrastructure..."
  cd "${SERVER_DIR}"
  sh ./generate_tf_files.sh
  terraform_init_remote
  terraform destroy
}

run_destroy_worker() {
  echo "Destroying worker infrastructure..."
  cd "${WORKER_DIR}"
  sh ./generate_tf_files.sh
  terraform_init_remote
  terraform destroy
}

run_destroy_backend() {
  echo "Destroying backend bucket infrastructure..."
  cd "${BOOTSTRAP_DIR}"
  sh ./generate_tf_files.sh
  terraform_init_local
  terraform destroy
}

run_nuke() {
  echo "This will destroy:"
  echo "  - the worker infrastructure stack"
  echo "  - the server infrastructure stack"
  echo "  - the Terraform backend bucket stack"
  echo
  echo "This removes the worker VM, server VM, network resources, static IP, and the backend state bucket."
  echo "Type 'nuke' to continue:"
  printf "> "
  read -r CONFIRM

  if [ "${CONFIRM}" != "nuke" ]; then
    echo "Aborted."
    exit 1
  fi

  run_destroy_worker
  run_destroy_server
  run_destroy_backend
}

run_status() {
  echo "Project: ${PROJECT_ID}"
  echo

  echo "Bootstrap stack:"
  cd "${BOOTSTRAP_DIR}"
  sh ./generate_tf_files.sh >/dev/null
  if terraform_init_local >/dev/null 2>&1; then
    terraform state list 2>/dev/null || true
  else
    echo "  not initialized yet"
  fi
  echo

  echo "Server stack:"
  cd "${SERVER_DIR}"
  sh ./generate_tf_files.sh >/dev/null
  if terraform_init_remote >/dev/null 2>&1; then
    terraform state list 2>/dev/null || true
  else
    echo "  backend not ready or not initialized yet"
  fi
  echo

  echo "Worker stack:"
  cd "${WORKER_DIR}"
  sh ./generate_tf_files.sh >/dev/null
  if terraform_init_remote >/dev/null 2>&1; then
    terraform state list 2>/dev/null || true
  else
    echo "  backend not ready or not initialized yet"
  fi
  echo

  echo "GCE instances:"
  if [ -n "${WORKER_NAME:-}" ]; then
    gcloud compute instances list --filter="name=(${SERVER_NAME} ${WORKER_NAME})" || true
  else
    gcloud compute instances list --filter="name=${SERVER_NAME}" || true
  fi
}

main() {
  if [ $# -ne 1 ]; then
    usage
    exit 1
  fi

  validate_prereqs
  set_gcloud_project

  case "$1" in
    bootstrap)
      run_bootstrap
      ;;
    plan)
      run_server_plan
      ;;
    apply)
      run_server_apply
      ;;
    server-setup)
      run_server_setup
      ;;
    kubeconfig)
      run_kubeconfig
      ;;
    deploy-addons)
      run_deploy_addons
      ;;
    destroy)
      run_destroy_server
      ;;
    worker-destroy)
      run_destroy_worker
      ;;
    destroy-backend)
      run_destroy_backend
      ;;
    nuke)
      run_nuke
      ;;
    status)
      run_status
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
