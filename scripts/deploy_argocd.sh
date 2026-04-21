#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/config-k3s-lab}"
ARGOCD_NAMESPACE="argocd"
ARGOCD_RELEASE="argocd"
ARGOCD_REPO_NAME="argo"
ARGOCD_REPO_URL="https://argoproj.github.io/argo-helm"
ARGOCD_CHART="argo/argo-cd"
ARGOCD_VALUES="${ROOT_DIR}/kubernetes/platform/argocd/values.yaml"
ARGOCD_NAMESPACE_MANIFEST="${ROOT_DIR}/kubernetes/platform/argocd/namespace.yaml"

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
require_file "${ARGOCD_VALUES}"
require_file "${ARGOCD_NAMESPACE_MANIFEST}"

export KUBECONFIG="${KUBECONFIG_PATH}"

echo "Creating Argo CD namespace scaffold..."
kubectl apply -f "${ARGOCD_NAMESPACE_MANIFEST}"

echo "Adding or updating Argo Helm repository..."
helm repo add "${ARGOCD_REPO_NAME}" "${ARGOCD_REPO_URL}" >/dev/null 2>&1 || true
helm repo update "${ARGOCD_REPO_NAME}"

echo "Installing or upgrading Argo CD..."
helm upgrade --install \
  "${ARGOCD_RELEASE}" "${ARGOCD_CHART}" \
  --namespace "${ARGOCD_NAMESPACE}" \
  --create-namespace \
  --values "${ARGOCD_VALUES}"

echo "Waiting for Argo CD workloads..."
kubectl rollout status statefulset/argocd-application-controller -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl rollout status deployment/argocd-applicationset-controller -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl rollout status deployment/argocd-dex-server -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl rollout status deployment/argocd-notifications-controller -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl rollout status deployment/argocd-redis -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl rollout status deployment/argocd-server -n "${ARGOCD_NAMESPACE}" --timeout=300s

echo
echo "What this install does:"
echo "  - installs Argo CD into namespace ${ARGOCD_NAMESPACE}"
echo "  - installs Argo CD CRDs through the Helm chart"
echo "  - keeps the server as ClusterIP for first access via port-forward"
echo "  - does not install ingress or TLS for Argo CD yet"
echo "  - does not apply Application resources yet"
echo "  - does not configure private Git repository credentials yet"
echo
echo "Next commands:"
echo "  kubectl get pods -n ${ARGOCD_NAMESPACE} -o wide"
echo "  kubectl port-forward svc/argocd-server -n ${ARGOCD_NAMESPACE} 8080:80"
echo "  kubectl get secret argocd-initial-admin-secret -n ${ARGOCD_NAMESPACE} -o jsonpath='{.data.password}' | base64 -d && echo"
echo "  kubectl delete secret argocd-initial-admin-secret -n ${ARGOCD_NAMESPACE}"
