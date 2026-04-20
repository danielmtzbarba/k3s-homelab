#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/config-k3s-lab}"
CERT_MANAGER_NAMESPACE="cert-manager"
CERT_MANAGER_RELEASE="cert-manager"
CERT_MANAGER_CHART="oci://quay.io/jetstack/charts/cert-manager"
CERT_MANAGER_VERSION="v1.20.2"
CERT_MANAGER_VALUES="${ROOT_DIR}/kubernetes/platform/cert-manager/values.yaml"
ISSUER_MANIFEST="${ROOT_DIR}/kubernetes/platform/issuers/letsencrypt-prod.yaml"

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

require_cmd helm
require_cmd kubectl
require_file "${KUBECONFIG_PATH}"
require_file "${CERT_MANAGER_VALUES}"
require_file "${ISSUER_MANIFEST}"

export KUBECONFIG="${KUBECONFIG_PATH}"

echo "Installing or upgrading cert-manager..."
helm upgrade --install \
  "${CERT_MANAGER_RELEASE}" "${CERT_MANAGER_CHART}" \
  --version "${CERT_MANAGER_VERSION}" \
  --namespace "${CERT_MANAGER_NAMESPACE}" \
  --create-namespace \
  --values "${CERT_MANAGER_VALUES}"

echo "Waiting for cert-manager deployments..."
kubectl rollout status deployment/cert-manager -n "${CERT_MANAGER_NAMESPACE}" --timeout=180s
kubectl rollout status deployment/cert-manager-cainjector -n "${CERT_MANAGER_NAMESPACE}" --timeout=180s
kubectl rollout status deployment/cert-manager-webhook -n "${CERT_MANAGER_NAMESPACE}" --timeout=180s

echo "Applying Let's Encrypt ClusterIssuer..."
kubectl apply -f "${ISSUER_MANIFEST}"

echo
echo "Verification commands:"
echo "  kubectl get pods -n cert-manager -o wide"
echo "  kubectl get clusterissuer"
echo "  kubectl get certificate -w"
echo "  kubectl get orders.acme.cert-manager.io -w"
echo "  kubectl get challenges.acme.cert-manager.io -w"
