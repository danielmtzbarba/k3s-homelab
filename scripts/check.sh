#!/usr/bin/env sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
ENV_HELPER="${ROOT_DIR}/scripts/lib_env.sh"
KUBECONFIG_PATH="${HOME}/.kube/config-k3s-lab"

section() {
  printf '\n%s\n' "$1"
}

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    printf 'ok   %s\n' "$1"
  else
    printf 'fail %s\n' "$1"
    exit 1
  fi
}

check_file() {
  if [ -f "$1" ]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'fail %s\n' "$1"
    exit 1
  fi
}

load_env() {
  check_file "${ENV_HELPER}"
  # shellcheck disable=SC1090
  . "${ENV_HELPER}"
  load_infra_env
}

section "Prerequisites"
check_cmd gcloud
check_cmd terraform
check_cmd kubectl

section "Environment"
load_env
: "${PROJECT_ID:?PROJECT_ID is required in infra env}"
: "${SERVER_NAME:?SERVER_NAME is required in infra env}"
: "${ZONE:?ZONE is required in infra env}"
: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required in infra env}"
: "${SUBNET_CIDR:?SUBNET_CIDR is required in infra env}"
printf 'ok   PROJECT_ID=%s\n' "${PROJECT_ID}"
printf 'ok   SERVER_NAME=%s\n' "${SERVER_NAME}"
if [ "${SUBNET_CIDR}" = "10.42.0.0/24" ]; then
  echo "fail SUBNET_CIDR overlaps with default k3s pod CIDR"
  exit 1
fi
printf 'ok   SUBNET_CIDR=%s\n' "${SUBNET_CIDR}"

section "GCP Project"
gcloud config set project "${PROJECT_ID}" >/dev/null
printf 'ok   gcloud project set to %s\n' "${PROJECT_ID}"

section "Backend Bucket"
if gcloud storage buckets describe "gs://${TF_STATE_BUCKET}" >/dev/null 2>&1; then
  printf 'ok   gs://%s\n' "${TF_STATE_BUCKET}"
else
  printf 'fail gs://%s\n' "${TF_STATE_BUCKET}"
  exit 1
fi

section "Server VM"
if gcloud compute instances describe "${SERVER_NAME}" --zone="${ZONE}" >/dev/null 2>&1; then
  printf 'ok   %s\n' "${SERVER_NAME}"
else
  printf 'fail %s\n' "${SERVER_NAME}"
  exit 1
fi

section "Kubeconfig"
if [ -f "${KUBECONFIG_PATH}" ]; then
  printf 'ok   %s\n' "${KUBECONFIG_PATH}"
else
  printf 'warn %s not found\n' "${KUBECONFIG_PATH}"
  echo 'hint run: sh scripts/infra.sh kubeconfig'
  exit 1
fi

export KUBECONFIG="${KUBECONFIG_PATH}"
printf 'ok   KUBECONFIG=%s\n' "${KUBECONFIG_PATH}"

section "Cluster"
kubectl get nodes -o wide
echo
kubectl get pods -A -o wide
