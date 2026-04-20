#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAMESPACE="danielmtz-website"
APP_DEPLOYMENT="danielmtz-website"
APP_DIR="${ROOT_DIR}/kubernetes/apps/danielmtz-website-tls"
KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/config-k3s-lab}"

usage() {
  cat <<'EOF'
Usage:
  sh scripts/website_rollout.sh apply
  sh scripts/website_rollout.sh status

Commands:
  apply   Apply the website TLS app and force a rollout restart.
  status  Show deployment, pods, service, ingress, and certificate status.
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_dir() {
  if [ ! -d "$1" ]; then
    echo "Required directory not found: $1" >&2
    exit 1
  fi
}

require_file() {
  if [ ! -f "$1" ]; then
    echo "Required file not found: $1" >&2
    exit 1
  fi
}

validate_prereqs() {
  require_cmd kubectl
  require_file "${KUBECONFIG_PATH}"
  export KUBECONFIG="${KUBECONFIG_PATH}"
}

apply_app() {
  require_dir "${APP_DIR}"
  echo "Applying danielmtz-website TLS app..."
  kubectl apply -k "${APP_DIR}"
  kubectl rollout restart deployment/"${APP_DEPLOYMENT}" -n "${APP_NAMESPACE}"
  kubectl rollout status deployment/"${APP_DEPLOYMENT}" -n "${APP_NAMESPACE}" --timeout=180s
}

show_status() {
  echo "Deployment:"
  kubectl get deployment -n "${APP_NAMESPACE}" "${APP_DEPLOYMENT}" -o wide
  echo
  echo "Pods:"
  kubectl get pods -n "${APP_NAMESPACE}" -o wide
  echo
  echo "Service and ingress:"
  kubectl get svc,ingress -n "${APP_NAMESPACE}"
  echo
  echo "Certificate:"
  kubectl get certificate -n "${APP_NAMESPACE}" 2>/dev/null || true
}

main() {
  if [ $# -ne 1 ]; then
    usage
    exit 1
  fi

  validate_prereqs

  case "$1" in
    apply)
      apply_app
      show_status
      ;;
    status)
      show_status
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
