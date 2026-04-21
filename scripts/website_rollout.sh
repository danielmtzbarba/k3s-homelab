#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/config-k3s-lab}"

usage() {
  cat <<'EOF'
Usage:
  sh scripts/website_rollout.sh apply [prod|dev] [image-tag]
  sh scripts/website_rollout.sh status [prod|dev]

Commands:
  apply   Apply the target website app. If an image tag is provided, update kustomization first.
  status  Show deployment, pods, service, ingress, and certificate status for the target app.
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

resolve_env() {
  case "$1" in
    ""|prod)
      APP_ENV="prod"
      APP_NAMESPACE="danielmtz-website-prod"
      APP_DEPLOYMENT="danielmtz-website-prod"
      APP_DIR="${ROOT_DIR}/kubernetes/apps/danielmtz-website-prod-tls"
      ;;
    dev)
      APP_ENV="dev"
      APP_NAMESPACE="danielmtz-website-dev"
      APP_DEPLOYMENT="danielmtz-website-dev"
      APP_DIR="${ROOT_DIR}/kubernetes/apps/danielmtz-website-dev-tls"
      ;;
    *)
      echo "Unknown environment: $1" >&2
      exit 1
      ;;
  esac
}

apply_app() {
  require_dir "${APP_DIR}"
  if [ $# -eq 1 ]; then
    echo "Updating ${APP_ENV} website image tag..."
    sh "${ROOT_DIR}/scripts/set_website_image_tag.sh" "${APP_ENV}" "$1"
  fi
  echo "Applying ${APP_ENV} website app..."
  kubectl apply -k "${APP_DIR}"
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
  if [ $# -lt 1 ] || [ $# -gt 3 ]; then
    usage
    exit 1
  fi

  validate_prereqs

  case "$1" in
    apply)
      if [ $# -eq 1 ]; then
        resolve_env "prod"
        apply_app
      elif [ $# -eq 2 ]; then
        case "$2" in
          prod|dev)
            resolve_env "$2"
            apply_app
            ;;
          *)
            resolve_env "prod"
            apply_app "$2"
            ;;
        esac
      else
        resolve_env "$2"
        apply_app "$3"
      fi
      show_status
      ;;
    status)
      if [ $# -eq 2 ]; then
        resolve_env "$2"
      else
        resolve_env "prod"
      fi
      show_status
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
