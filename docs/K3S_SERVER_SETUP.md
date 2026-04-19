# k3s Server Setup

This document starts after the infrastructure exists and you are ready to SSH into the server.

Scope:

- SSH into the VM
- apply basic server shell setup changes
- install k3s server
- verify the service
- retrieve kubeconfig
- verify cluster access from your machine

No worker node. No application services.

## 1. SSH Into the Server

From your local machine:

```bash
gcloud compute ssh "$SERVER_NAME" --zone="$ZONE"
```

If you are not in a shell with `.env` loaded, use the explicit values:

```bash
gcloud compute ssh "k3s-server-1" --zone="europe-west3-a"
```

## 2. Verify the VM

Once inside the VM:

```bash
uname -a
cat /etc/os-release
```

## 3. Setup Checklist

Before installing k3s, apply these base changes on the server:

- use `zsh`
- export `TERM=xterm-256color`
- persist `TERM` in `~/.zshrc`
- keep the server package set minimal
- install k3s only after the shell environment is sane

## 4. Run the Setup Script

From your local machine, copy the script to the server:

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
- changes the default shell to `zsh` with `sudo usermod`
- persists `overlay` and `br_netfilter` module loading
- persists the required k3s sysctl settings
- configures `tls-san` for the server public IP when available
- persists the `TERM` setting in `~/.zshrc`
- adds `alias k=kubectl`
- installs k3s
- restarts and verifies the `k3s` service path

After the script finishes, open a new SSH session to enter `zsh` by default.

## 5. Install k3s Server Manually Instead

If you do not want to use the script, run these manually inside the VM:

```bash
export TERM=xterm-256color
sudo apt-get update
sudo apt-get install -y zsh curl ca-certificates
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

## 6. Verify the Service

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

## 7. Verify the API Port

Inside the VM:

```bash
sudo ss -lntp | grep 6443
```

You should see the Kubernetes API listening on `6443`.

## 8. Retrieve the kubeconfig

Automated option from your local machine:

```bash
chmod +x scripts/fetch_kubeconfig.sh
sh scripts/fetch_kubeconfig.sh
```

That script:

- reads `.env`
- copies the server setup script to the VM
- runs the server setup script on the VM
- pulls `/etc/rancher/k3s/k3s.yaml` from the server
- discovers the server public IP
- rewrites the API endpoint
- writes the result to `~/.kube/config-k3s-lab`

Because it runs the server setup first, it is safe to rerun after rebuilding the VM.

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

## 9. Verify Access From Your Machine

On your local machine:

```bash
export KUBECONFIG="$HOME/.kube/config-k3s-lab"
kubectl get nodes -o wide
kubectl get pods -A
kubectl cluster-info
```

## 10. What You Have Now

You now have:

- one GCP VM
- one k3s server
- one Kubernetes API endpoint
- no HA
- no worker nodes
- no application workloads

This is a learning platform, not a production cluster.
