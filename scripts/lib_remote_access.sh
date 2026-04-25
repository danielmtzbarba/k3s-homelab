#!/usr/bin/env sh

remote_access_mode() {
  if [ "${TAILSCALE_ENABLE:-false}" = "true" ] && [ "${PUBLIC_SSH_ENABLE:-true}" = "false" ]; then
    printf '%s\n' "tailscale"
    return
  fi

  if [ "${KUBECONFIG_ENDPOINT_MODE:-public}" = "tailscale" ]; then
    printf '%s\n' "tailscale"
    return
  fi

  printf '%s\n' "gcloud"
}

remote_ssh_target() {
  : "${SSH_USER:?SSH_USER is required for remote SSH access}"

  TARGET_HOST="${TAILSCALE_HOSTNAME:-${SERVER_NAME:-}}"
  if [ -z "${TARGET_HOST}" ]; then
    echo "Could not determine Tailscale SSH target host." >&2
    return 1
  fi

  printf '%s\n' "${SSH_USER}@${TARGET_HOST}"
}

remote_require_mode_prereqs() {
  MODE="$(remote_access_mode)"

  if [ "${MODE}" = "tailscale" ]; then
    if ! command -v ssh >/dev/null 2>&1; then
      echo "Missing required command: ssh" >&2
      return 1
    fi
    if ! command -v scp >/dev/null 2>&1; then
      echo "Missing required command: scp" >&2
      return 1
    fi
    if ! command -v tailscale >/dev/null 2>&1; then
      echo "Missing required command: tailscale" >&2
      return 1
    fi
  else
    if ! command -v gcloud >/dev/null 2>&1; then
      echo "Missing required command: gcloud" >&2
      return 1
    fi
  fi
}

remote_copy_to() {
  SRC="$1"
  DEST="$2"
  MODE="$(remote_access_mode)"

  if [ "${MODE}" = "tailscale" ]; then
    TARGET="$(remote_ssh_target)" || return 1
    scp "${SRC}" "${TARGET}:${DEST}"
  else
    gcloud compute scp "${SRC}" "${SERVER_NAME}:${DEST}" --zone="${ZONE}"
  fi
}

remote_run() {
  CMD="$1"
  MODE="$(remote_access_mode)"

  if [ "${MODE}" = "tailscale" ]; then
    TARGET="$(remote_ssh_target)" || return 1
    ssh "${TARGET}" "${CMD}"
  else
    gcloud compute ssh "${SERVER_NAME}" --zone="${ZONE}" --command="${CMD}"
  fi
}
