#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/config-k3s-lab}"
TAILSCALE_NAMESPACE="tailscale"
TAILSCALE_RELEASE="tailscale-operator"
TAILSCALE_REPO_NAME="tailscale"
TAILSCALE_REPO_URL="https://pkgs.tailscale.com/helmcharts"
TAILSCALE_CHART="tailscale/tailscale-operator"

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
  if [ -f "${ENV_FILE}" ]; then
    set -a
    . "${ENV_FILE}"
    set +a
  fi
}

load_env

require_cmd helm
require_cmd kubectl
require_file "${KUBECONFIG_PATH}"

export KUBECONFIG="${KUBECONFIG_PATH}"

echo "Adding or updating the Tailscale Helm repository..."
helm repo add "${TAILSCALE_REPO_NAME}" "${TAILSCALE_REPO_URL}" >/dev/null 2>&1 || true
helm repo update "${TAILSCALE_REPO_NAME}"

set -- \
  --namespace "${TAILSCALE_NAMESPACE}" \
  --create-namespace

if [ -n "${TAILSCALE_OAUTH_CLIENT_ID:-}" ] && [ -n "${TAILSCALE_OAUTH_CLIENT_SECRET:-}" ]; then
  echo "Using OAuth client credentials from environment for Helm-managed operator-oauth secret."
  set -- "$@" \
    --set-string "oauth.clientId=${TAILSCALE_OAUTH_CLIENT_ID}" \
    --set-string "oauth.clientSecret=${TAILSCALE_OAUTH_CLIENT_SECRET}"
else
  echo "No OAuth client credentials provided in environment."
  echo "Expecting a precreated Kubernetes secret named operator-oauth in namespace ${TAILSCALE_NAMESPACE}."
fi

echo "Installing or upgrading the Tailscale Kubernetes Operator..."
helm upgrade --install \
  "${TAILSCALE_RELEASE}" "${TAILSCALE_CHART}" \
  "$@"

echo "Waiting for the operator deployment..."
kubectl rollout status deployment/operator -n "${TAILSCALE_NAMESPACE}" --timeout=300s

echo
echo "What this install does:"
echo "  - installs the Tailscale Kubernetes Operator into namespace ${TAILSCALE_NAMESPACE}"
echo "  - creates the tailscale ingress class used for private tailnet-only app access"
echo "  - uses env-provided OAuth credentials only when they are explicitly set"
echo "  - otherwise expects a precreated Secret named operator-oauth"
echo "  - does not expose any workloads by itself"
echo
echo "Next commands:"
echo "  kubectl get pods -n ${TAILSCALE_NAMESPACE}"
echo "  kubectl get ingressclass tailscale"
echo "  kubectl apply -f ${ROOT_DIR}/kubernetes/platform/argocd/applications/tailscale-private-access.yaml"
