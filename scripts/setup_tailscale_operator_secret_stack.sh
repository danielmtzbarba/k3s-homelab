#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/config-k3s-lab}"
GCP_SECRETS_ENV_FILE="${1:-${ROOT_DIR}/.gcp-secrets.env}"
STORE_TEMPLATE="${ROOT_DIR}/kubernetes/platform/external-secrets/clustersecretstore-gcpsm-wif.example.yaml"
SERVICE_ACCOUNT_MANIFEST="${ROOT_DIR}/kubernetes/platform/external-secrets/serviceaccount-gcpsm.yaml"
TAILSCALE_EXTERNAL_SECRET_MANIFEST="${ROOT_DIR}/kubernetes/platform/tailscale-operator/externalsecret-operator-oauth.yaml"
GRAFANA_EXTERNAL_SECRET_MANIFEST="${ROOT_DIR}/kubernetes/platform/observability/externalsecret-grafana-admin.yaml"

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

load_env_file() {
  set -a
  . "$1"
  set +a
}

render_cluster_secret_store() {
  TMP_FILE="$(mktemp)"
  sed \
    -e "s/your-gcp-project-id/${PROJECT_ID}/g" \
    -e "s/PROJECT_NUMBER/${PROJECT_NUMBER}/g" \
    -e "s/POOL_ID/${POOL_ID}/g" \
    -e "s/PROVIDER_ID/${PROVIDER_ID}/g" \
    "${STORE_TEMPLATE}" > "${TMP_FILE}"
  printf '%s\n' "${TMP_FILE}"
}

require_cmd gcloud
require_cmd kubectl
require_cmd sed
require_file "${KUBECONFIG_PATH}"
require_file "${GCP_SECRETS_ENV_FILE}"
require_file "${STORE_TEMPLATE}"
require_file "${SERVICE_ACCOUNT_MANIFEST}"
require_file "${TAILSCALE_EXTERNAL_SECRET_MANIFEST}"
require_file "${GRAFANA_EXTERNAL_SECRET_MANIFEST}"

load_env_file "${GCP_SECRETS_ENV_FILE}"
require_env PROJECT_ID "${PROJECT_ID:-}"
require_env POOL_ID "${POOL_ID:-}"
require_env PROVIDER_ID "${PROVIDER_ID:-}"

PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
require_env PROJECT_NUMBER "${PROJECT_NUMBER:-}"

export KUBECONFIG="${KUBECONFIG_PATH}"

echo "Syncing secrets to GCP Secret Manager..."
sh "${ROOT_DIR}/scripts/sync_gcp_secrets.sh" "${GCP_SECRETS_ENV_FILE}"

echo "Applying External Secrets service account..."
kubectl apply -f "${SERVICE_ACCOUNT_MANIFEST}"

echo "Rendering and applying ClusterSecretStore..."
TMP_STORE_MANIFEST="$(render_cluster_secret_store)"
kubectl apply -f "${TMP_STORE_MANIFEST}"
rm -f "${TMP_STORE_MANIFEST}"

echo "Waiting for ClusterSecretStore gcp-secret-manager..."
kubectl wait --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True clustersecretstore/gcp-secret-manager --timeout=180s

echo "Applying Tailscale operator ExternalSecret..."
kubectl apply -f "${TAILSCALE_EXTERNAL_SECRET_MANIFEST}"

echo "Applying Grafana admin ExternalSecret..."
kubectl apply -f "${GRAFANA_EXTERNAL_SECRET_MANIFEST}"

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

echo "Waiting for observability/grafana-admin-credentials to exist..."
ATTEMPTS=0
until kubectl get secret grafana-admin-credentials -n observability >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "${ATTEMPTS}" -ge 36 ]; then
    echo "Timed out waiting for observability/grafana-admin-credentials to be created." >&2
    kubectl describe externalsecret grafana-admin-credentials -n observability || true
    exit 1
  fi
  sleep 5
done

echo
echo "Tailscale secret stack is configured."
echo "Verification commands:"
echo "  kubectl get clustersecretstore gcp-secret-manager"
echo "  kubectl get externalsecret -n tailscale operator-oauth"
echo "  kubectl get secret -n tailscale operator-oauth"
echo "  kubectl get externalsecret -n observability grafana-admin-credentials"
echo "  kubectl get secret -n observability grafana-admin-credentials"
echo "  sh scripts/infra.sh deploy-tailscale-operator"
