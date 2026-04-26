#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
ENV_HELPER="${ROOT_DIR}/scripts/lib_env.sh"
REMOTE_LIB="${ROOT_DIR}/scripts/lib_remote_access.sh"
BOOTSTRAP_DIR="${ROOT_DIR}/infra/terraform/bootstrap"
SERVER_DIR="${ROOT_DIR}/infra/terraform/server"
WORKER_DIR="${ROOT_DIR}/infra/terraform/worker"
ENVS_DIR="${ROOT_DIR}/infra/envs"
GCP_PLATFORM_ENV_FILE="${ENVS_DIR}/gcp.platform.env"
GCP_ARGOCD_ENV_FILE="${ENVS_DIR}/gcp.argocd.env"

usage() {
  cat <<'EOF'
Usage:
  sh scripts/infra.sh bootstrap
  sh scripts/infra.sh plan
  sh scripts/infra.sh apply
  sh scripts/infra.sh apply-kubeconfig
  sh scripts/infra.sh server-setup
  sh scripts/infra.sh kubeconfig
  sh scripts/infra.sh platform-bootstrap
  sh scripts/infra.sh platform-reconcile
  sh scripts/infra.sh deploy-addons
  sh scripts/infra.sh deploy-argocd
  sh scripts/infra.sh deploy-image-updater
  sh scripts/infra.sh deploy-tailscale-operator
  sh scripts/infra.sh destroy
  sh scripts/infra.sh worker-destroy
  sh scripts/infra.sh destroy-backend
  sh scripts/infra.sh nuke
  sh scripts/infra.sh status

Commands:
  bootstrap       Create or reconcile the Terraform backend bucket.
  plan            Generate server Terraform inputs and run terraform plan.
  apply           Generate server Terraform inputs and run terraform apply.
  apply-kubeconfig Generate server Terraform inputs, run terraform apply, and fetch kubeconfig.
  server-setup    Copy and run the VM-side k3s server setup script.
  kubeconfig      Fetch kubeconfig from the server and rewrite it for local use.
  platform-bootstrap Reconcile the first platform layer after cluster access works.
  platform-reconcile Run platform-bootstrap, deploy Argo CD Image Updater, and apply Argo CD Applications.
  deploy-addons   Install cluster add-ons such as cert-manager and TLS ingress.
  deploy-argocd   Install or upgrade Argo CD with Helm.
  deploy-image-updater Install Argo CD Image Updater in the argocd namespace.
  deploy-tailscale-operator Install or upgrade the Tailscale Kubernetes Operator.
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
  require_file "${ENV_HELPER}"
  # shellcheck disable=SC1090
  . "${ENV_HELPER}"
  load_infra_env
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
  require_file "${REMOTE_LIB}"
  # shellcheck disable=SC1090
  . "${REMOTE_LIB}"
  load_env
  validate_env
  remote_require_mode_prereqs

  if [ -n "${SSH_PUBLIC_KEY_PATH:-}" ] && [ ! -f "${SSH_PUBLIC_KEY_PATH}" ]; then
    echo "SSH public key file not found: ${SSH_PUBLIC_KEY_PATH}" >&2
    exit 1
  fi
}

run_argocd_secret_stack() {
  cd "${ROOT_DIR}"
  if [ -f "${GCP_ARGOCD_ENV_FILE}" ]; then
    sh ./scripts/setup_argocd_secret_stack.sh "${GCP_ARGOCD_ENV_FILE}"
    return
  fi

  sh ./scripts/setup_argocd_secret_stack.sh
}

run_tailscale_secret_stack() {
  cd "${ROOT_DIR}"
  if [ -f "${GCP_PLATFORM_ENV_FILE}" ]; then
    sh ./scripts/setup_tailscale_operator_secret_stack.sh "${GCP_PLATFORM_ENV_FILE}"
    return
  fi

  sh ./scripts/setup_tailscale_operator_secret_stack.sh
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
K8S_SERVICE_ACCOUNT_ISSUER_ENABLE="${K8S_SERVICE_ACCOUNT_ISSUER_ENABLE:-false}"
K8S_SERVICE_ACCOUNT_ISSUER_URL="${K8S_SERVICE_ACCOUNT_ISSUER_URL:-}"
K8S_SERVICE_ACCOUNT_JWKS_URI="${K8S_SERVICE_ACCOUNT_JWKS_URI:-}"
EOF
  remote_copy_to "./scripts/k3s_server_setup.sh" "k3s_server_setup.sh"
  remote_copy_to "${TMP_SERVER_ENV}" "k3s_server_setup.env"
  remote_run "set -a && . \"\$HOME/k3s_server_setup.env\" && set +a && chmod +x \"\$HOME/k3s_server_setup.sh\" && sh \"\$HOME/k3s_server_setup.sh\" && rm -f \"\$HOME/k3s_server_setup.env\""
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

  if gcloud storage buckets describe "gs://${TF_STATE_BUCKET}" >/dev/null 2>&1; then
    if ! terraform state show google_storage_bucket.tf_state >/dev/null 2>&1; then
      echo "Importing existing backend bucket ${TF_STATE_BUCKET} into local bootstrap state..."
      terraform import google_storage_bucket.tf_state "${TF_STATE_BUCKET}"
    fi
  fi

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

run_server_apply_kubeconfig() {
  run_server_apply
  echo
  run_kubeconfig
}

run_bootstrap_external_secrets() {
  echo "Bootstrapping External Secrets via Argo CD..."
  cd "${ROOT_DIR}"
  kubectl apply -f ./kubernetes/platform/argocd/applications/external-secrets.yaml

  echo "Waiting for Argo CD Application external-secrets to become Synced and Healthy..."
  ATTEMPTS=0
  while :; do
    APP_SYNC_STATUS="$(kubectl get application -n argocd external-secrets -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    APP_HEALTH_STATUS="$(kubectl get application -n argocd external-secrets -o jsonpath='{.status.health.status}' 2>/dev/null || true)"

    if [ "${APP_SYNC_STATUS}" = "Synced" ] && [ "${APP_HEALTH_STATUS}" = "Healthy" ]; then
      break
    fi

    ATTEMPTS=$((ATTEMPTS + 1))
    if [ "${ATTEMPTS}" -ge 48 ]; then
      echo "Timed out waiting for Argo CD Application external-secrets to become Synced/Healthy." >&2
      kubectl get application -n argocd external-secrets -o yaml || true
      exit 1
    fi
    sleep 5
  done

  echo "Waiting for external-secrets namespace..."
  ATTEMPTS=0
  until kubectl get namespace external-secrets >/dev/null 2>&1; do
    ATTEMPTS=$((ATTEMPTS + 1))
    if [ "${ATTEMPTS}" -ge 36 ]; then
      echo "Timed out waiting for namespace/external-secrets to be created." >&2
      exit 1
    fi
    sleep 5
  done

  echo "Waiting for External Secrets controller deployment..."
  ATTEMPTS=0
  until kubectl get deployment external-secrets -n external-secrets >/dev/null 2>&1; do
    ATTEMPTS=$((ATTEMPTS + 1))
    if [ "${ATTEMPTS}" -ge 36 ]; then
      echo "Timed out waiting for deployment/external-secrets to be created." >&2
      kubectl get all -n external-secrets || true
      exit 1
    fi
    sleep 5
  done
  kubectl rollout status deployment/external-secrets -n external-secrets --timeout=180s
}

tailscale_secret_stack_ready() {
  if ! kubectl get clustersecretstore gcp-secret-manager >/dev/null 2>&1; then
    return 1
  fi

  STORE_READY="$(kubectl get clustersecretstore gcp-secret-manager -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
  if [ "${STORE_READY}" != "True" ]; then
    return 1
  fi

  kubectl get secret operator-oauth -n tailscale >/dev/null 2>&1
}

argocd_secret_stack_ready() {
  kubectl get secret repo-k3s-homelab -n argocd >/dev/null 2>&1 &&
    kubectl get secret k3s-homelab-writeback -n argocd >/dev/null 2>&1 &&
    kubectl get secret ghcr-pull-secret -n argocd >/dev/null 2>&1
}

run_platform_bootstrap() {
  echo "Bootstrapping platform components..."
  echo "  1. cert-manager and shared issuer"
  echo "  2. Argo CD"
  echo "  3. External Secrets"
  echo "  4. Tailscale operator secret stack, if GCP secret env files exist"
  echo "  5. Argo CD secret stack, if GCP secret env files exist"
  echo "  6. Tailscale Kubernetes Operator"
  echo

  run_deploy_addons
  run_deploy_argocd
  run_bootstrap_external_secrets

  if has_gcp_secrets_env; then
    if tailscale_secret_stack_ready; then
      echo "Tailscale operator secret stack already configured; skipping GCP secret sync/bootstrap."
    else
      echo "Configuring Tailscale operator secret stack from configured GCP secret env source..."
      run_tailscale_secret_stack
    fi

    if argocd_secret_stack_ready; then
      echo "Argo CD secret stack already configured; skipping GCP secret sync/bootstrap."
    else
      echo "Configuring Argo CD secret stack from configured GCP secret env source..."
      run_argocd_secret_stack
    fi

    run_deploy_tailscale_operator
  else
    echo "Skipping Tailscale operator bootstrap."
    echo "Provide the GCP secret mappings in .env or use infra/envs/gcp.*.env."
  fi

  echo
  echo "Platform bootstrap finished."
}

run_deploy_addons() {
  echo "Deploying cluster add-ons..."
  cd "${ROOT_DIR}"
  sh ./scripts/deploy_cluster_addons.sh
}

run_deploy_argocd() {
  echo "Deploying Argo CD..."
  cd "${ROOT_DIR}"
  sh ./scripts/deploy_argocd.sh
}

run_deploy_image_updater() {
  echo "Deploying Argo CD Image Updater..."
  cd "${ROOT_DIR}"
  sh ./scripts/deploy_argocd_image_updater.sh
}

run_apply_argocd_applications() {
  echo "Applying Argo CD Application resources..."
  cd "${ROOT_DIR}"
  kubectl apply -f ./kubernetes/platform/argocd/applications/
}

run_deploy_tailscale_operator() {
  echo "Deploying the Tailscale Kubernetes Operator..."
  cd "${ROOT_DIR}"
  sh ./scripts/deploy_tailscale_operator.sh
}

run_platform_reconcile() {
  run_platform_bootstrap
  echo
  run_deploy_image_updater
  echo
  run_apply_argocd_applications
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
  if [ -n "${CLUSTER_TAG:-}" ]; then
    gcloud compute instances list --filter="tags.items=${CLUSTER_TAG}" || true
  elif [ -n "${WORKER_NAME:-}" ]; then
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
    apply-kubeconfig)
      run_server_apply_kubeconfig
      ;;
    server-setup)
      run_server_setup
      ;;
    kubeconfig)
      run_kubeconfig
      ;;
    platform-bootstrap)
      run_platform_bootstrap
      ;;
    platform-reconcile)
      run_platform_reconcile
      ;;
    deploy-addons)
      run_deploy_addons
      ;;
    deploy-argocd)
      run_deploy_argocd
      ;;
    deploy-image-updater)
      run_deploy_image_updater
      ;;
    deploy-tailscale-operator)
      run_deploy_tailscale_operator
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
