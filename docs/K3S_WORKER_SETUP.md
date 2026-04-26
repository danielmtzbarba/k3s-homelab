# k3s Worker Setup

This document adds the first worker node for the cluster.

Scope:

- provision one worker VM
- join it to the existing k3s server
- verify multi-node scheduling

This assumes:

- the server stack already exists
- the k3s server is already healthy
- local `kubectl` access already works
- the VM subnet does not overlap with k3s defaults such as pod CIDR `10.42.0.0/16`

If your server was created before the worker workflow was added to this repo, reconcile the server stack once first so the inter-node firewall rule exists:

```bash
sh scripts/infra.sh apply
```

## 1. Provision the Worker VM

From the repository root:

```bash
sh scripts/worker.sh plan
sh scripts/worker.sh apply
```

This creates:

- one Ubuntu VM
- one VM service account
- one reserved internal IP for the worker
- optional cloud-init Tailscale enrollment
- optional cloud-init `k3s-agent` install/join when `K3S_CLUSTER_TOKEN` is configured

Important:

- if your current subnet is `10.42.0.0/24`, stop and rebuild with a non-overlapping subnet such as `10.10.0.0/24`
- `10.42.0.0/24` overlaps with the default k3s pod CIDR and breaks worker join

## 2. Recommended Worker Join Path: Cloud-Init

The canonical path is now boot-time reconciliation through cloud-init, not a follow-up SSH join step.

Set these values in `.env` before `worker.sh apply`:

```bash
WORKER_INTERNAL_IP="10.10.0.3"
TAILSCALE_ENABLE="true"
TAILSCALE_WORKER_AUTH_KEY="..."
TAILSCALE_WORKER_HOSTNAME="k3s-worker-1"
TAILSCALE_ACCEPT_DNS="false"
K3S_CLUSTER_TOKEN="..."
```

Notes:

- `WORKER_INTERNAL_IP` keeps the worker node address stable across recreation.
- `TAILSCALE_WORKER_AUTH_KEY` should preferably be a dedicated ephemeral key.
- `K3S_CLUSTER_TOKEN` is the stable shared cluster token used by the server and worker boot paths.

With those values set, `sh scripts/worker.sh apply` should be enough for the worker to:

- boot
- join the tailnet
- install/start `k3s-agent`
- join the cluster

without `worker.sh join`.

## 3. Verify the Worker

On your local machine:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

Expected result:

- two nodes
- one server node
- one worker node
- both in `Ready` state

For worker boot debugging, check cloud-init first:

```bash
tailscale ssh "$SSH_USER@$TAILSCALE_WORKER_HOSTNAME" sudo cloud-init status --long
tailscale ssh "$SSH_USER@$TAILSCALE_WORKER_HOSTNAME" sudo tail -200 /var/log/cloud-init-output.log
tailscale ssh "$SSH_USER@$TAILSCALE_WORKER_HOSTNAME" sudo systemctl status k3s-agent --no-pager -l
```

## 4. Recovery Path: Manual Join Helper

If you need to repair an existing worker manually, `worker.sh join` still exists as a fallback path.

Run:

```bash
sh scripts/worker.sh join
```

That helper:

- reads `.env`
- discovers the server private IP
- reads the node token from the server
- copies `scripts/k3s_worker_setup.sh` to the worker VM
- runs it on the worker
- if `TAILSCALE_ENABLE=true`, also installs Tailscale and joins the worker to the tailnet

This is now the recovery path, not the preferred day-one provisioning path.

## 5. Inspect the Worker Directly

If needed:

```bash
tailscale ssh "$SSH_USER@$TAILSCALE_WORKER_HOSTNAME"
sudo systemctl status k3s-agent --no-pager
sudo journalctl -u k3s-agent -n 100 --no-pager
tailscale status
```

If Tailscale access is not available, fall back to:

```bash
gcloud compute ssh "$WORKER_NAME" --zone="$ZONE"
```

## 6. Destroy the Worker

If you want to reset only the worker:

```bash
sh scripts/worker.sh destroy
```
