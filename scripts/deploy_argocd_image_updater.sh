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
require_file "./kubernetes/platform/argocd-image-updater/image-updater-dev.yaml"
require_file "./kubernetes/platform/argocd-image-updater/image-updater-quant-dev.yaml"
require_file "./kubernetes/platform/argocd-image-updater/image-updater-quant-shared.yaml"

export KUBECONFIG="${KUBECONFIG_PATH}"
SERVER_NODE_SELECTOR_KEY="kubernetes.io/hostname"
SERVER_NODE_SELECTOR_VALUE="k3s-server-1.europe-west3-a.c.k3s-homelab-danielmtz.internal"

echo "Installing Argo CD Image Updater into namespace ${ARGOCD_NAMESPACE}..."
kubectl apply -n "${ARGOCD_NAMESPACE}" -f "${INSTALL_URL}"

echo "Pinning Argo CD Image Updater to ${SERVER_NODE_SELECTOR_VALUE}..."
kubectl patch deployment argocd-image-updater-controller \
  -n "${ARGOCD_NAMESPACE}" \
  --type merge \
  -p "{\"spec\":{\"template\":{\"spec\":{\"nodeSelector\":{\"${SERVER_NODE_SELECTOR_KEY}\":\"${SERVER_NODE_SELECTOR_VALUE}\"}}}}}"

echo "Waiting for Argo CD Image Updater controller..."
kubectl rollout status deployment/argocd-image-updater-controller -n "${ARGOCD_NAMESPACE}" --timeout=300s

echo "Applying Argo CD Image Updater resources..."
for resource in ./kubernetes/platform/argocd-image-updater/*.yaml; do
  kubectl apply -f "${resource}"
done

echo
echo "What this install does:"
echo "  - installs Argo CD Image Updater in namespace ${ARGOCD_NAMESPACE}"
echo "  - keeps the updater in the same namespace as Argo CD, which is the recommended path"
echo "  - does not create Git write-back credentials"
echo "  - does not create registry credentials"
echo "  - applies the ImageUpdater resources from kubernetes/platform/argocd-image-updater/"
echo
echo "Next commands:"
echo "  kubectl get pods -n ${ARGOCD_NAMESPACE} | grep argocd-image-updater"
echo "  kubectl get imageupdaters -n ${ARGOCD_NAMESPACE}"
