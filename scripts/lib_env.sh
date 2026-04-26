#!/usr/bin/env sh

load_env_file() {
  FILE_PATH="$1"

  if [ ! -f "${FILE_PATH}" ]; then
    echo "Required env file not found: ${FILE_PATH}" >&2
    return 1
  fi

  : "${K3S_HOMELAB_ROOT:=${ROOT_DIR}}"
  export K3S_HOMELAB_ROOT
  set -a
  # shellcheck disable=SC1090
  . "${FILE_PATH}"
  set +a
}

load_env_dir_pattern() {
  DIR_PATH="$1"
  FILE_PATTERN="$2"
  FOUND="false"

  for FILE_PATH in "${DIR_PATH}"/${FILE_PATTERN}; do
    if [ -f "${FILE_PATH}" ]; then
      FOUND="true"
      : "${K3S_HOMELAB_ROOT:=${ROOT_DIR}}"
      export K3S_HOMELAB_ROOT
      set -a
      # shellcheck disable=SC1090
      . "${FILE_PATH}"
      set +a
    fi
  done

  if [ "${FOUND}" != "true" ]; then
    echo "No env files matching ${FILE_PATTERN} found in ${DIR_PATH}" >&2
    return 1
  fi
}

has_env_dir_pattern() {
  DIR_PATH="$1"
  FILE_PATTERN="$2"

  for FILE_PATH in "${DIR_PATH}"/${FILE_PATTERN}; do
    if [ -f "${FILE_PATH}" ]; then
      return 0
    fi
  done

  return 1
}

load_infra_env() {
  REQUESTED_PATH="${1:-}"
  DEFAULT_ENV_FILE="${K3S_HOMELAB_ENV_FILE:-${ROOT_DIR}/.env}"
  DEFAULT_ENV_DIR="${K3S_HOMELAB_ENV_DIR:-${ROOT_DIR}/infra/envs}"

  if [ -n "${REQUESTED_PATH}" ]; then
    if [ -d "${REQUESTED_PATH}" ]; then
      load_env_dir_pattern "${REQUESTED_PATH}" "infra.*.env"
      return
    fi
    load_env_file "${REQUESTED_PATH}"
    return
  fi

  if [ -f "${DEFAULT_ENV_FILE}" ]; then
    load_env_file "${DEFAULT_ENV_FILE}"
    return
  fi

  load_env_dir_pattern "${DEFAULT_ENV_DIR}" "infra.*.env"
}

load_gcp_secrets_env() {
  REQUESTED_PATH="${1:-}"
  DEFAULT_ENV_FILE="${K3S_HOMELAB_GCP_ENV_FILE:-${ROOT_DIR}/.env}"
  DEFAULT_ENV_DIR="${K3S_HOMELAB_ENV_DIR:-${ROOT_DIR}/infra/envs}"

  if [ -n "${REQUESTED_PATH}" ]; then
    if [ -d "${REQUESTED_PATH}" ]; then
      load_env_dir_pattern "${REQUESTED_PATH}" "gcp.*.env"
      return
    fi
    load_env_file "${REQUESTED_PATH}"
    return
  fi

  if [ -f "${DEFAULT_ENV_FILE}" ]; then
    load_env_file "${DEFAULT_ENV_FILE}"
    return
  fi

  load_env_dir_pattern "${DEFAULT_ENV_DIR}" "gcp.*.env"
}

has_gcp_secrets_env() {
  DEFAULT_ENV_FILE="${K3S_HOMELAB_GCP_ENV_FILE:-${ROOT_DIR}/.env}"
  DEFAULT_ENV_DIR="${K3S_HOMELAB_ENV_DIR:-${ROOT_DIR}/infra/envs}"

  if [ -f "${DEFAULT_ENV_FILE}" ]; then
    return 0
  fi

  has_env_dir_pattern "${DEFAULT_ENV_DIR}" "gcp.*.env"
}
