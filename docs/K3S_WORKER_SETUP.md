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
- public SSH access on the existing subnet

Important:

- if your current subnet is `10.42.0.0/24`, stop and rebuild with a non-overlapping subnet such as `10.10.0.0/24`
- `10.42.0.0/24` overlaps with the default k3s pod CIDR and breaks worker join

## 2. Join the Worker to the Cluster

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

## 4. Inspect the Worker Directly

If needed:

```bash
gcloud compute ssh "$WORKER_NAME" --zone="$ZONE"
sudo systemctl status k3s-agent --no-pager
sudo journalctl -u k3s-agent -n 100 --no-pager
```

## 5. Destroy the Worker

If you want to reset only the worker:

```bash
sh scripts/worker.sh destroy
```
