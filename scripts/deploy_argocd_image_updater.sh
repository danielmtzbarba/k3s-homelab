#!/usr/bin/env sh

set -eu

KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/config-k3s-lab}"
ARGOCD_NAMESPACE="argocd"
INSTALL_URL="https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/config/install.yaml"

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

export KUBECONFIG="${KUBECONFIG_PATH}"

echo "Installing Argo CD Image Updater into namespace ${ARGOCD_NAMESPACE}..."
kubectl apply -n "${ARGOCD_NAMESPACE}" -f "${INSTALL_URL}"

echo "Waiting for Argo CD Image Updater controller..."
kubectl rollout status deployment/argocd-image-updater-controller -n "${ARGOCD_NAMESPACE}" --timeout=300s

echo
echo "What this install does:"
echo "  - installs Argo CD Image Updater in namespace ${ARGOCD_NAMESPACE}"
echo "  - keeps the updater in the same namespace as Argo CD, which is the recommended path"
echo "  - does not create Git write-back credentials"
echo "  - does not create registry credentials"
echo "  - does not apply any ImageUpdater resources yet"
echo
echo "Next commands:"
echo "  kubectl get pods -n ${ARGOCD_NAMESPACE} | grep argocd-image-updater"
echo "  kubectl apply -f kubernetes/platform/argocd-image-updater/image-updater-dev.yaml"
