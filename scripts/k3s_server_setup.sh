#!/usr/bin/env sh

set -eu

export TERM=xterm-256color

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this script as a regular user with sudo access, not as root." >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v zsh >/dev/null 2>&1 || ! command -v bash >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y bash curl ca-certificates zsh
fi

if ! command -v helm >/dev/null 2>&1; then
  TMP_HELM_INSTALL="$(mktemp)"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o "${TMP_HELM_INSTALL}"
  bash "${TMP_HELM_INSTALL}"
  rm -f "${TMP_HELM_INSTALL}"
fi

TAILSCALE_ENABLE="${TAILSCALE_ENABLE:-false}"
TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-}"
TAILSCALE_ACCEPT_DNS="${TAILSCALE_ACCEPT_DNS:-false}"
K8S_SERVICE_ACCOUNT_ISSUER_ENABLE="${K8S_SERVICE_ACCOUNT_ISSUER_ENABLE:-false}"
K8S_SERVICE_ACCOUNT_ISSUER_URL="${K8S_SERVICE_ACCOUNT_ISSUER_URL:-}"
K8S_SERVICE_ACCOUNT_JWKS_URI="${K8S_SERVICE_ACCOUNT_JWKS_URI:-}"

sudo mkdir -p /etc/modules-load.d /etc/sysctl.d

sudo sh -c "cat > /etc/modules-load.d/k3s.conf <<'EOF'
overlay
br_netfilter
EOF"

sudo modprobe overlay
sudo modprobe br_netfilter

sudo sh -c "cat > /etc/sysctl.d/99-k3s.conf <<'EOF'
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF"

sudo sysctl --system >/dev/null

sudo mkdir -p /etc/rancher/k3s/config.yaml.d

PUBLIC_IP="$(curl -fsS -H 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip || true)"

if [ -n "${PUBLIC_IP}" ]; then
  sudo sh -c "cat > /etc/rancher/k3s/config.yaml.d/10-public-ip.yaml <<EOF
tls-san:
  - \"${PUBLIC_IP}\"
EOF"
fi

if [ "${K8S_SERVICE_ACCOUNT_ISSUER_ENABLE}" = "true" ]; then
  if [ -z "${K8S_SERVICE_ACCOUNT_ISSUER_URL}" ]; then
    echo "K8S_SERVICE_ACCOUNT_ISSUER_ENABLE=true requires K8S_SERVICE_ACCOUNT_ISSUER_URL." >&2
    exit 1
  fi

  TMP_ISSUER_CONFIG="$(mktemp)"
  cat > "${TMP_ISSUER_CONFIG}" <<EOF
kube-apiserver-arg:
  - service-account-issuer=${K8S_SERVICE_ACCOUNT_ISSUER_URL}
EOF

  if [ -n "${K8S_SERVICE_ACCOUNT_JWKS_URI}" ]; then
    cat >> "${TMP_ISSUER_CONFIG}" <<EOF
  - service-account-jwks-uri=${K8S_SERVICE_ACCOUNT_JWKS_URI}
EOF
  fi

  sudo cp "${TMP_ISSUER_CONFIG}" /etc/rancher/k3s/config.yaml.d/30-service-account-issuer.yaml
  rm -f "${TMP_ISSUER_CONFIG}"
fi

TAILSCALE_IP=""

if [ "${TAILSCALE_ENABLE}" = "true" ]; then
  if [ -z "${TAILSCALE_AUTH_KEY}" ]; then
    echo "TAILSCALE_ENABLE=true requires TAILSCALE_AUTH_KEY." >&2
    exit 1
  fi

  TMP_TAILSCALE_INSTALL="$(mktemp)"
  curl -fsSL https://tailscale.com/install.sh -o "${TMP_TAILSCALE_INSTALL}"
  sudo sh "${TMP_TAILSCALE_INSTALL}"
  rm -f "${TMP_TAILSCALE_INSTALL}"

  sudo systemctl enable tailscaled
  sudo systemctl start tailscaled

  TAILSCALE_ARGS="--auth-key=${TAILSCALE_AUTH_KEY} --accept-dns=${TAILSCALE_ACCEPT_DNS}"
  if [ -n "${TAILSCALE_HOSTNAME}" ]; then
    TAILSCALE_ARGS="${TAILSCALE_ARGS} --hostname=${TAILSCALE_HOSTNAME}"
  fi

  sudo tailscale up ${TAILSCALE_ARGS}
  TAILSCALE_IP="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"

  if [ -n "${TAILSCALE_IP}" ]; then
    sudo sh -c "cat > /etc/rancher/k3s/config.yaml.d/20-tailscale-ip.yaml <<EOF
tls-san:
  - \"${TAILSCALE_IP}\"
EOF"
  fi
fi

touch "${HOME}/.zshrc"

if ! grep -Fq 'export TERM=xterm-256color' "${HOME}/.zshrc"; then
  printf '\nexport TERM=xterm-256color\n' >> "${HOME}/.zshrc"
fi

if ! grep -Fq 'alias k=kubectl' "${HOME}/.zshrc"; then
  printf 'alias k=kubectl\n' >> "${HOME}/.zshrc"
fi

ZSH_PATH="$(command -v zsh)"
CURRENT_SHELL="${SHELL:-}"

if [ "${CURRENT_SHELL}" != "${ZSH_PATH}" ]; then
  sudo usermod -s "${ZSH_PATH}" "${USER}"
fi

if ! sudo systemctl is-enabled k3s >/dev/null 2>&1; then
  curl -sfL https://get.k3s.io | sh -
fi

sudo systemctl enable k3s
sudo systemctl restart k3s

echo
echo "Default shell set to: ${ZSH_PATH}"
echo "Open a new SSH session to enter zsh by default."
if [ -n "${PUBLIC_IP}" ]; then
  echo "Configured tls-san for public IP: ${PUBLIC_IP}"
fi
if [ -n "${TAILSCALE_IP}" ]; then
  echo "Configured tls-san for Tailscale IP: ${TAILSCALE_IP}"
fi
echo
echo "Verification commands:"
echo "  export TERM=xterm-256color"
echo "  helm version"
echo "  tailscale status"
echo "  sudo systemctl status k3s --no-pager"
echo "  sudo kubectl get nodes -o wide"
echo "  sudo kubectl get pods -A"
echo "  sudo kubectl get --raw /.well-known/openid-configuration"
echo "  sudo ss -lntp | grep 6443"
