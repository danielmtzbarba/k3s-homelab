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

if ! command -v curl >/dev/null 2>&1 || ! command -v zsh >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y curl ca-certificates zsh
fi

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
echo
echo "Verification commands:"
echo "  export TERM=xterm-256color"
echo "  sudo systemctl status k3s --no-pager"
echo "  sudo kubectl get nodes -o wide"
echo "  sudo kubectl get pods -A"
echo "  sudo ss -lntp | grep 6443"
