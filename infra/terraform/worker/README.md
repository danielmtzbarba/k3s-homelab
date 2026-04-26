# Terraform Worker Stack

This stack provisions the desired set of k3s worker VMs.

It assumes the server stack already created:

- the VPC
- the subnet
- the node firewall rules

This stack creates, per worker:

- one VM service account
- one Ubuntu VM
- one reserved internal IP
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

This is the canonical worker path now. Each VM should join both:

- the tailnet, when `TAILSCALE_ENABLE=true`
- the k3s cluster, when `K3S_CLUSTER_TOKEN` is set

without a separate SSH-driven `worker.sh join` step.

For worker lifecycle hygiene, prefer setting `TAILSCALE_WORKER_AUTH_KEY` to a dedicated
ephemeral auth key. That allows destroyed worker nodes to age out of the tailnet cleanly
without reusing the same broader auth key as the server.

If `K3S_CLUSTER_TOKEN` is also set in `.env`, the worker VM cloud-init boot path writes `/etc/rancher/k3s/config.yaml`, installs `k3s-agent` if needed, and joins the cluster automatically on boot. This is the preferred long-term path for recreating workers without SSH.

Recommended inputs in `.env` for the backward-compatible single-worker path:

- `WORKER_INTERNAL_IP`
  Reserve a stable node IP so the worker does not drift across reboots or recreation.

- `K3S_CLUSTER_TOKEN`
  Stable shared token used by the server and worker bootstraps.
  If you paste a full secure k3s token like `K10<hash>::<secret>`, the generator strips it back to the shared secret before cloud-init uses it.

- `TAILSCALE_WORKER_AUTH_KEY`
  Prefer a dedicated ephemeral auth key for the worker lifecycle.

- `TAILSCALE_WORKER_HOSTNAME`
  Stable worker hostname on the tailnet.

For real multi-worker reconciliation, prefer one of these:

- `WORKERS_JSON`
  JSON object keyed by worker name. Each value may define:
  - `internal_ip` (required)
  - `worker_tag`
  - `node_labels`
  - `machine_type`
  - `boot_disk_size_gb`
  - `tailscale_auth_key`
  - `tailscale_hostname`

`node_labels` are applied during worker bootstrap and can be used by workload
`nodeSelector`s instead of provider-generated node hostnames.

- `WORKERS_TFVARS_PATH`
  Path to an HCL snippet file that defines the `workers = { ... }` map directly.

If neither is set, the generator falls back to the existing single-worker inputs.

Use `scripts/worker.sh join [worker-name]` only as a recovery path when you need to repair an existing worker manually.
