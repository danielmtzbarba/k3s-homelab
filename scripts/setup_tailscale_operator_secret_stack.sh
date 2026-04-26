#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/config-k3s-lab}"
GCP_SECRETS_ENV_FILE="${1:-}"
ENV_HELPER="${ROOT_DIR}/scripts/lib_env.sh"
STORE_TEMPLATE="${ROOT_DIR}/kubernetes/platform/external-secrets/clustersecretstore-gcpsm.example.yaml"
TAILSCALE_EXTERNAL_SECRET_MANIFEST="${ROOT_DIR}/kubernetes/platform/tailscale-operator/externalsecret-operator-oauth.yaml"
GCPSM_SECRET_NAME="gcpsm-secret"
GCPSM_SECRET_NAMESPACE="external-secrets"
GCPSM_SECRET_KEY="secret-access-credentials"
TAILSCALE_NAMESPACE="tailscale"

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

render_cluster_secret_store() {
  TMP_FILE="$(mktemp)"
  sed \
    -e "s/your-gcp-project-id/${PROJECT_ID}/g" \
    "${STORE_TEMPLATE}" > "${TMP_FILE}"
  printf '%s\n' "${TMP_FILE}"
}

apply_gcpsm_bootstrap_secret() {
  SECRET_VALUE="${GCPSM_SECRET_ACCESS_CREDENTIALS:-}"
  SECRET_FILE="${GCPSM_SECRET_ACCESS_CREDENTIALS_FILE:-}"

  if [ -z "${SECRET_VALUE}" ] && [ -n "${SECRET_FILE}" ]; then
    require_file "${SECRET_FILE}"
    kubectl create secret generic "${GCPSM_SECRET_NAME}" \
      -n "${GCPSM_SECRET_NAMESPACE}" \
      --from-file="${GCPSM_SECRET_KEY}=${SECRET_FILE}" \
      --dry-run=client -o yaml | kubectl apply -f -
    return
  fi

  if [ -n "${SECRET_VALUE}" ]; then
    TMP_SECRET_FILE="$(mktemp)"
    printf '%s' "${SECRET_VALUE}" > "${TMP_SECRET_FILE}"
    kubectl create secret generic "${GCPSM_SECRET_NAME}" \
      -n "${GCPSM_SECRET_NAMESPACE}" \
      --from-file="${GCPSM_SECRET_KEY}=${TMP_SECRET_FILE}" \
      --dry-run=client -o yaml | kubectl apply -f -
    rm -f "${TMP_SECRET_FILE}"
    return
  fi

  echo "Required environment variable not set: GCPSM_SECRET_ACCESS_CREDENTIALS or GCPSM_SECRET_ACCESS_CREDENTIALS_FILE" >&2
  exit 1
}

require_cmd gcloud
require_cmd kubectl
require_cmd sed
require_file "${KUBECONFIG_PATH}"
require_file "${ENV_HELPER}"
require_file "${STORE_TEMPLATE}"
require_file "${TAILSCALE_EXTERNAL_SECRET_MANIFEST}"

# shellcheck disable=SC1090
. "${ENV_HELPER}"
load_gcp_secrets_env "${GCP_SECRETS_ENV_FILE:-}"
require_env PROJECT_ID "${PROJECT_ID:-}"

export KUBECONFIG="${KUBECONFIG_PATH}"

echo "Syncing secrets to GCP Secret Manager..."
sh "${ROOT_DIR}/scripts/sync_gcp_secrets.sh" "${GCP_SECRETS_ENV_FILE}"

echo "Applying External Secrets GCP Secret Manager bootstrap secret..."
apply_gcpsm_bootstrap_secret

echo "Rendering and applying ClusterSecretStore..."
TMP_STORE_MANIFEST="$(render_cluster_secret_store)"
kubectl apply -f "${TMP_STORE_MANIFEST}"
rm -f "${TMP_STORE_MANIFEST}"

echo "Waiting for ClusterSecretStore gcp-secret-manager..."
if ! kubectl wait --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True clustersecretstore/gcp-secret-manager --timeout=180s; then
  echo "ClusterSecretStore gcp-secret-manager did not become Ready." >&2
  kubectl describe clustersecretstore gcp-secret-manager || true
  kubectl get clustersecretstore gcp-secret-manager -o yaml || true
  kubectl get pods -n external-secrets -o wide || true
  kubectl logs deployment/external-secrets -n external-secrets --tail=200 || true
  exit 1
fi

echo "Ensuring namespace ${TAILSCALE_NAMESPACE} exists..."
kubectl create namespace "${TAILSCALE_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "Applying Tailscale operator ExternalSecret..."
kubectl apply -f "${TAILSCALE_EXTERNAL_SECRET_MANIFEST}"

echo "Waiting for operator-oauth secret to exist..."
ATTEMPTS=0
until kubectl get secret operator-oauth -n tailscale >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "${ATTEMPTS}" -ge 36 ]; then
    echo "Timed out waiting for tailscale/operator-oauth to be created." >&2
    kubectl describe externalsecret operator-oauth -n tailscale || true
    exit 1
  fi
  sleep 5
done

echo
echo "Tailscale secret stack is configured."
echo "Verification commands:"
echo "  kubectl get clustersecretstore gcp-secret-manager"
echo "  kubectl get secret -n ${GCPSM_SECRET_NAMESPACE} ${GCPSM_SECRET_NAME}"
echo "  kubectl get externalsecret -n tailscale operator-oauth"
echo "  kubectl get secret -n tailscale operator-oauth"
echo "  sh scripts/infra.sh deploy-tailscale-operator"
