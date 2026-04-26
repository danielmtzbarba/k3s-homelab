#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/config-k3s-lab}"
GCP_SECRETS_ENV_FILE="${1:-}"
ENV_HELPER="${ROOT_DIR}/scripts/lib_env.sh"
ARGOCD_NAMESPACE="argocd"
REPO_SECRET_MANIFEST="${ROOT_DIR}/kubernetes/platform/argocd/externalsecret-repo-k3s-homelab.yaml"
WRITEBACK_SECRET_MANIFEST="${ROOT_DIR}/kubernetes/platform/argocd/externalsecret-k3s-homelab-writeback.yaml"
GHCR_SECRET_MANIFEST="${ROOT_DIR}/kubernetes/platform/argocd/externalsecret-ghcr-pull-secret.yaml"

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

require_env() {
  if [ -z "${2:-}" ]; then
    echo "Required environment variable not set: $1" >&2
    exit 1
  fi
}

wait_for_secret() {
  SECRET_NAME="$1"
  ATTEMPTS=0

  until kubectl get secret "${SECRET_NAME}" -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; do
    ATTEMPTS=$((ATTEMPTS + 1))
    if [ "${ATTEMPTS}" -ge 36 ]; then
      echo "Timed out waiting for ${ARGOCD_NAMESPACE}/${SECRET_NAME} to be created." >&2
      kubectl describe externalsecret "${SECRET_NAME}" -n "${ARGOCD_NAMESPACE}" || true
      exit 1
    fi
    sleep 5
  done
}

wait_for_cluster_secret_store() {
  ATTEMPTS=0

  until kubectl get clustersecretstore gcp-secret-manager >/dev/null 2>&1; do
    ATTEMPTS=$((ATTEMPTS + 1))
    if [ "${ATTEMPTS}" -ge 36 ]; then
      echo "Timed out waiting for ClusterSecretStore/gcp-secret-manager to exist." >&2
      exit 1
    fi
    sleep 5
  done

  kubectl wait \
    --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True \
    clustersecretstore/gcp-secret-manager \
    --timeout=180s
}

require_cmd kubectl
require_file "${KUBECONFIG_PATH}"
require_file "${ENV_HELPER}"
require_file "${REPO_SECRET_MANIFEST}"
require_file "${WRITEBACK_SECRET_MANIFEST}"
require_file "${GHCR_SECRET_MANIFEST}"

# shellcheck disable=SC1090
. "${ENV_HELPER}"
load_gcp_secrets_env "${GCP_SECRETS_ENV_FILE:-}"
require_env PROJECT_ID "${PROJECT_ID:-}"

export KUBECONFIG="${KUBECONFIG_PATH}"

echo "Syncing Argo CD secrets to GCP Secret Manager..."
sh "${ROOT_DIR}/scripts/sync_gcp_secrets.sh" "${GCP_SECRETS_ENV_FILE}"

echo "Waiting for ClusterSecretStore gcp-secret-manager..."
wait_for_cluster_secret_store

echo "Ensuring namespace ${ARGOCD_NAMESPACE} exists..."
kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "Applying Argo CD ExternalSecrets..."
kubectl apply -f "${REPO_SECRET_MANIFEST}"
kubectl apply -f "${WRITEBACK_SECRET_MANIFEST}"
kubectl apply -f "${GHCR_SECRET_MANIFEST}"

echo "Waiting for Argo CD repository secret..."
wait_for_secret "repo-k3s-homelab"

echo "Waiting for Argo CD write-back secret..."
wait_for_secret "k3s-homelab-writeback"

echo "Waiting for Argo CD GHCR pull secret..."
wait_for_secret "ghcr-pull-secret"

echo
echo "Argo CD secret stack is configured."
echo "Verification commands:"
echo "  kubectl get externalsecret -n ${ARGOCD_NAMESPACE}"
echo "  kubectl get secret -n ${ARGOCD_NAMESPACE} repo-k3s-homelab"
echo "  kubectl get secret -n ${ARGOCD_NAMESPACE} k3s-homelab-writeback"
echo "  kubectl get secret -n ${ARGOCD_NAMESPACE} ghcr-pull-secret"
