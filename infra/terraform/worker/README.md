# Terraform Worker Stack

This stack provisions the first k3s worker VM.

It assumes the server stack already created:

- the VPC
- the subnet
- the node firewall rules

This stack only creates:

- one VM service account
- one Ubuntu VM for the worker
- one reserved internal IP for the worker
- optional Tailscale enrollment during VM boot through cloud-init
- optional boot-time `k3s-agent` install/join through cloud-init when a stable cluster token is configured

## Usage

```bash
cd infra/terraform/worker
bash generate_tf_files.sh
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

This is the canonical worker path now. The VM should join both:

- the tailnet, when `TAILSCALE_ENABLE=true`
- the k3s cluster, when `K3S_CLUSTER_TOKEN` is set

without a separate SSH-driven `worker.sh join` step.

For worker lifecycle hygiene, prefer setting `TAILSCALE_WORKER_AUTH_KEY` to a dedicated
ephemeral auth key. That allows destroyed worker nodes to age out of the tailnet cleanly
without reusing the same broader auth key as the server.

If `K3S_CLUSTER_TOKEN` is also set in `.env`, the worker VM cloud-init boot path writes `/etc/rancher/k3s/config.yaml`, installs `k3s-agent` if needed, and joins the cluster automatically on boot. This is the preferred long-term path for recreating workers without SSH.

Recommended inputs in `.env`:

- `WORKER_INTERNAL_IP`
  Reserve a stable node IP so the worker does not drift across reboots or recreation.

- `K3S_CLUSTER_TOKEN`
  Stable shared token used by the server and worker bootstraps.

- `TAILSCALE_WORKER_AUTH_KEY`
  Prefer a dedicated ephemeral auth key for the worker lifecycle.

- `TAILSCALE_WORKER_HOSTNAME`
  Stable worker hostname on the tailnet.

Use `scripts/worker.sh join` only as a recovery path when you need to repair an existing worker manually.
