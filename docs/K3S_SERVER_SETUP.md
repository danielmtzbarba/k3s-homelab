# k3s Server Setup

This document starts after the infrastructure exists.

Scope:

- provision the server with boot-time cloud-init bootstrap
- verify `k3s server`
- verify the service
- retrieve kubeconfig
- verify cluster access from your machine

No worker node. No application services.

Important:

- your VM subnet must not overlap with k3s default pod networking
- avoid `10.42.0.0/24` as the GCP subnet because k3s uses `10.42.0.0/16` by default
- a safe learning subnet is `10.10.0.0/24`

## 1. Recommended Path: Cloud-Init Server Bootstrap

The canonical server path is now Terraform + cloud-init, not a follow-up SSH session.

Set these values in `.env` before `sh scripts/infra.sh apply`:

```bash
TAILSCALE_ENABLE="true"
TAILSCALE_AUTH_KEY="..."
TAILSCALE_HOSTNAME="k3s-server-1"
TAILSCALE_ACCEPT_DNS="false"
K3S_CLUSTER_TOKEN="..."
```

Optional issuer settings:

```bash
K8S_SERVICE_ACCOUNT_ISSUER_ENABLE="true"
K8S_SERVICE_ACCOUNT_ISSUER_URL="https://k3s-server-1.<your-tailnet>.ts.net:6443"
K8S_SERVICE_ACCOUNT_JWKS_URI="https://k3s-server-1.<your-tailnet>.ts.net:6443/openid/v1/jwks"
```

Then run:

```bash
sh scripts/infra.sh apply
```

That server stack now:

- reserves a stable internal server IP in Terraform
- attaches cloud-init `user-data`
- installs `k3s server` on boot
- optionally joins the tailnet
- optionally configures the service-account issuer

## 2. Verify The Server

From your local machine:

```bash
gcloud compute ssh "$SERVER_NAME" --zone="$ZONE" --command='sudo systemctl status k3s --no-pager'
```

If Tailscale is enabled, tailnet access works too:

```bash
tailscale ssh "$SSH_USER@$TAILSCALE_HOSTNAME" sudo systemctl status k3s --no-pager
```

Useful direct checks on the VM:

```bash
uname -a
cat /etc/os-release
sudo journalctl -u k3s -n 100 --no-pager
sudo kubectl get nodes -o wide
```

For cloud-init debugging:

```bash
sudo cloud-init status --long
sudo tail -200 /var/log/cloud-init-output.log
```

## 3. Recovery Path: Manual Server Setup Script

If you need to repair an existing server manually, the old VM-side setup script still exists as a fallback.

From your local machine:

```bash
gcloud compute scp scripts/k3s_server_setup.sh "$SERVER_NAME":~/ --zone="$ZONE"
```

Then SSH into the server and run:

```bash
chmod +x ~/k3s_server_setup.sh
sh ~/k3s_server_setup.sh
```

The script:

- exports `TERM=xterm-256color`
- installs `zsh`
- installs `helm`
- changes the default shell to `zsh` with `sudo usermod`
- persists `overlay` and `br_netfilter` module loading
- persists the required k3s sysctl settings
- configures `tls-san` for the server public IP when available
- optionally configures a Kubernetes service-account issuer for Workload Identity Federation
- persists the `TERM` setting in `~/.zshrc`
- adds `alias k=kubectl`
- installs k3s
- restarts and verifies the `k3s` service path

After the script finishes, open a new SSH session to enter `zsh` by default.

Wrapper equivalent from your local machine:

```bash
sh scripts/infra.sh server-setup
```

That runs the same VM-side script through `gcloud compute scp` and `gcloud compute ssh`.

## 4. Manual Install Alternative

If you do not want to use the script, run these manually inside the VM:

```bash
export TERM=xterm-256color
sudo apt-get update
sudo apt-get install -y bash zsh curl ca-certificates
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm-3
bash /tmp/get-helm-3
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
sudo sysctl --system
PUBLIC_IP="$(curl -fsS -H 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)"
sudo mkdir -p /etc/rancher/k3s/config.yaml.d
sudo sh -c "cat > /etc/rancher/k3s/config.yaml.d/10-public-ip.yaml <<EOF
tls-san:
  - \"${PUBLIC_IP}\"
EOF"
echo 'export TERM=xterm-256color' >> ~/.zshrc
curl -sfL https://get.k3s.io | sh -
```

## Optional: Enable A Kubernetes Service-Account Issuer

If you want Google Workload Identity Federation for External Secrets Operator later, configure a stable issuer URL before you start depending on it.

Set in `.env`:

```bash
K8S_SERVICE_ACCOUNT_ISSUER_ENABLE="true"
K8S_SERVICE_ACCOUNT_ISSUER_URL="https://k3s-server-1.<your-tailnet>.ts.net:6443"
K8S_SERVICE_ACCOUNT_JWKS_URI="https://k3s-server-1.<your-tailnet>.ts.net:6443/openid/v1/jwks"
```

Then rerun:

```bash
sh scripts/infra.sh apply
```

Verify:

```bash
KUBECONFIG="$HOME/.kube/config-k3s-lab" kubectl get --raw /.well-known/openid-configuration
KUBECONFIG="$HOME/.kube/config-k3s-lab" kubectl get --raw /openid/v1/jwks
```

## 5. Verify the Service

Inside the VM:

```bash
sudo systemctl status k3s --no-pager
```

Check the node and system pods:

```bash
sudo kubectl get nodes -o wide
sudo kubectl get pods -A
```

Expected result:

- one node
- node status `Ready`
- system pods running in `kube-system`

## 6. Verify the API Port

Inside the VM:

```bash
sudo ss -lntp | grep 6443
```

You should see the Kubernetes API listening on `6443`.

## 7. Retrieve the kubeconfig

Automated option from your local machine:

```bash
chmod +x scripts/fetch_kubeconfig.sh
sh scripts/fetch_kubeconfig.sh
```

That script:

- reads `.env`
- pulls `/etc/rancher/k3s/k3s.yaml` from the server
- discovers the server public or Tailscale IP depending on `KUBECONFIG_ENDPOINT_MODE`
- rewrites the API endpoint
- writes the result to `~/.kube/config-k3s-lab`

If you want an explicit verification flow first:

```bash
sh scripts/infra.sh kubeconfig
```

If you want the normal one-shot path from your local machine, use:

```bash
sh scripts/infra.sh apply-kubeconfig
export KUBECONFIG="$HOME/.kube/config-k3s-lab"
```

Then continue with the normal platform path:

```bash
sh scripts/worker.sh apply
sh scripts/infra.sh platform-reconcile
```

Manual option:

Inside the VM:

```bash
sudo cat /etc/rancher/k3s/k3s.yaml
```

Copy the file content to your local machine and save it as:

```bash
~/.kube/config-k3s-lab
```

In that file, replace:

```text
server: https://127.0.0.1:6443
```

with the server public IP:

```text
server: https://YOUR_SERVER_PUBLIC_IP:6443
```

Example:

```text
server: https://34.123.45.67:6443
```

## 8. Verify Access From Your Machine

On your local machine:

```bash
export KUBECONFIG="$HOME/.kube/config-k3s-lab"
kubectl get nodes -o wide
kubectl get pods -A
kubectl cluster-info
```

## 9. What You Have Now

You now have:

- one GCP VM
- one k3s server
- one Kubernetes API endpoint
- no HA
- no worker nodes
- no application workloads

This is a learning platform, not a production cluster.
