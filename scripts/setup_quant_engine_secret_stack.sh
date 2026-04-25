#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/config-k3s-lab}"
GCP_SECRETS_ENV_FILE="${1:-${ROOT_DIR}/.gcp-secrets.env}"

SHARED_NAMESPACE_MANIFEST="${ROOT_DIR}/kubernetes/apps/quant-engine-shared/namespace.yaml"
SHARED_GHCR_EXTERNAL_SECRET="${ROOT_DIR}/kubernetes/apps/quant-engine-shared/ghcr-pull-secret-externalsecret.yaml"
DEV_CORE_EXTERNAL_SECRET="${ROOT_DIR}/kubernetes/apps/quant-engine-dev/core-externalsecret.yaml"
DEV_MESSAGING_EXTERNAL_SECRET="${ROOT_DIR}/kubernetes/apps/quant-engine-dev/messaging-externalsecret.yaml"

PROD_CORE_EXTERNAL_SECRET="${ROOT_DIR}/kubernetes/apps/quant-engine-prod/core-externalsecret.yaml"
PROD_MESSAGING_EXTERNAL_SECRET="${ROOT_DIR}/kubernetes/apps/quant-engine-prod/messaging-externalsecret.yaml"

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

require_cmd kubectl
require_file "${KUBECONFIG_PATH}"
require_file "${GCP_SECRETS_ENV_FILE}"
require_file "${SHARED_NAMESPACE_MANIFEST}"
require_file "${SHARED_GHCR_EXTERNAL_SECRET}"
require_file "${DEV_CORE_EXTERNAL_SECRET}"
require_file "${DEV_MESSAGING_EXTERNAL_SECRET}"
require_file "${PROD_CORE_EXTERNAL_SECRET}"
require_file "${PROD_MESSAGING_EXTERNAL_SECRET}"

export KUBECONFIG="${KUBECONFIG_PATH}"

echo "Syncing quant-engine secrets to GCP Secret Manager..."
sh "${ROOT_DIR}/scripts/sync_gcp_secrets.sh" "${GCP_SECRETS_ENV_FILE}"

echo "Applying quant-engine namespace..."
kubectl apply -f "${SHARED_NAMESPACE_MANIFEST}"

echo "Applying quant-engine shared ExternalSecrets..."
kubectl apply -f "${SHARED_GHCR_EXTERNAL_SECRET}"

echo "Applying quant-engine dev ExternalSecrets..."
kubectl apply -f "${DEV_CORE_EXTERNAL_SECRET}"
kubectl apply -f "${DEV_MESSAGING_EXTERNAL_SECRET}"

echo "Applying quant-engine prod ExternalSecrets..."
kubectl apply -f "${PROD_CORE_EXTERNAL_SECRET}"
kubectl apply -f "${PROD_MESSAGING_EXTERNAL_SECRET}"

echo "Waiting for quant-engine ghcr-pull-secret to exist..."
ATTEMPTS=0
until kubectl get secret ghcr-pull-secret -n quant-engine-mt5 >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "${ATTEMPTS}" -ge 36 ]; then
    echo "Timed out waiting for quant-engine-mt5/ghcr-pull-secret to be created." >&2
    kubectl describe externalsecret ghcr-pull-secret -n quant-engine-mt5 || true
    exit 1
  fi
  sleep 5
done

echo "Waiting for quant-engine dev core secret to exist..."
ATTEMPTS=0
until kubectl get secret quant-engine-dev-core-secrets -n quant-engine-mt5 >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "${ATTEMPTS}" -ge 36 ]; then
    echo "Timed out waiting for quant-engine-mt5/quant-engine-dev-core-secrets." >&2
    kubectl describe externalsecret quant-engine-dev-core-secrets -n quant-engine-mt5 || true
    exit 1
  fi
  sleep 5
done

echo "Waiting for quant-engine dev messaging secret to exist..."
ATTEMPTS=0
until kubectl get secret quant-engine-dev-messaging-secrets -n quant-engine-mt5 >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "${ATTEMPTS}" -ge 36 ]; then
    echo "Timed out waiting for quant-engine-mt5/quant-engine-dev-messaging-secrets." >&2
    kubectl describe externalsecret quant-engine-dev-messaging-secrets -n quant-engine-mt5 || true
    exit 1
  fi
  sleep 5
done

echo
echo "Quant engine secret stack is configured."
echo "Verification commands:"
echo "  kubectl get secret -n quant-engine-mt5 ghcr-pull-secret"
echo "  kubectl get secret -n quant-engine-mt5 quant-engine-dev-core-secrets"
echo "  kubectl get secret -n quant-engine-mt5 quant-engine-dev-messaging-secrets"
echo "  kubectl get secret -n quant-engine-mt5 quant-engine-prod-core-secrets"
echo "  kubectl get secret -n quant-engine-mt5 quant-engine-prod-messaging-secrets"
