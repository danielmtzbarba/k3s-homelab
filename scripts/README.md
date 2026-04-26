# Scripts

This directory contains the operator entrypoints for infrastructure, cluster bootstrap, platform bootstrap, and workload rollout.

Use the wrappers in this order unless you are debugging a specific layer.

Env source model:

- canonical: root `.env`
- preferred structure behind it: split `infra.*.env` and `gcp.*.env` files under [infra/envs/README.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/infra/envs/README.md)

## Recommended Order

1. `infra.sh bootstrap`
   Create or reconcile the Terraform backend bucket.

2. `infra.sh apply-kubeconfig`
   Create or reconcile the server infrastructure stack and fetch kubeconfig.
   In tailnet mode, the kubeconfig fetch now waits for Tailscale/MagicDNS readiness
   and clears the stale `k3s-server-1` SSH host key before retrying.

3. verify the server boot path
   Cloud-init should bring up `k3s server` and optional Tailscale during VM boot
   when the relevant values are set in `.env`.

4. export `KUBECONFIG`
   `infra.sh apply-kubeconfig` writes `~/.kube/config-k3s-lab`, but it cannot
   export into your current shell. Run:
   `export KUBECONFIG="$HOME/.kube/config-k3s-lab"`

5. `worker.sh apply`
   Create or reconcile the desired worker set.

6. verify the worker boot path
   Cloud-init should join each worker to Tailscale and k3s automatically when
   `TAILSCALE_ENABLE=true` and `K3S_CLUSTER_TOKEN` are set in `.env`.

7. `worker.sh join`
   Recovery path only. Use this when you need to repair an existing worker manually.

8. `infra.sh platform-reconcile`
   Normal platform path. This runs:
   - `infra.sh platform-bootstrap`
   - `infra.sh deploy-image-updater`
   - `kubectl apply -f kubernetes/platform/argocd/applications/`

9. `infra.sh platform-bootstrap`
   Lower-level repair path for the first platform layer:
   - cert-manager
   - Argo CD
   - Tailscale operator secret stack when the root `.env` contains the GCP secret mappings
   - Tailscale Kubernetes Operator

10. `website_rollout.sh`
   Deploy or update the website workload.

## Script Groups

### Infra Wrappers

- `infra.sh`
  Main operator entrypoint for Terraform, cluster bootstrap, and platform bootstrap.
  `infra.sh server-setup` remains the manual repair path for the server.

- `worker.sh`
  Worker infrastructure and recovery workflow. The preferred path is boot-time
  cloud-init reconciliation after `worker.sh apply`; `worker.sh join` remains the
  manual repair path. If `TAILSCALE_ENABLE=true` in `.env`, the worker cloud-init
  path and `worker.sh join` can both enroll the worker into the tailnet.

### VM Bootstrap

- `k3s_server_setup.sh`
  VM-side setup for the first k3s server, including Tailscale and optional service-account issuer config.

- `k3s_worker_setup.sh`
  VM-side setup for a worker join, with optional Tailscale enrollment.

### Access Helpers

- `fetch_kubeconfig.sh`
  Pull kubeconfig from the server and rewrite the endpoint for local access.
  In Tailscale mode it retries until the server is reachable on the tailnet and
  removes the stale server host key before reconnecting after a VM recreate.

- `lib_remote_access.sh`
  Shared helper that chooses between public `gcloud` access and Tailscale SSH/SCP.

### Platform Deployment

- `deploy_cluster_addons.sh`
  Install cert-manager and the shared Let's Encrypt issuer.

- `deploy_argocd.sh`
  Install Argo CD with Helm.

- `deploy_argocd_image_updater.sh`
  Install Argo CD Image Updater.

- `deploy_tailscale_operator.sh`
  Install the Tailscale Kubernetes Operator. In steady state, it expects `tailscale/operator-oauth` to already exist.

### Secret Management

- `sync_gcp_secrets.sh`
  Sync local secret values into GCP Secret Manager.
  Default mode creates missing secrets and skips existing ones.
  Use `--delete-existing` to force delete/recreate mode and re-apply secret-level IAM bindings.

- `setup_tailscale_operator_secret_stack.sh`
  End-to-end wrapper for the Tailscale operator secret path:
  - sync GCP secrets
  - create/update `external-secrets/gcpsm-secret`
  - render/apply the `ClusterSecretStore`
  - apply the Tailscale `ExternalSecret`
  - wait for `tailscale/operator-oauth`

- `setup_quant_engine_secret_stack.sh`
  Syncs the quant-engine app secrets to GCP Secret Manager and materializes
  the namespace `ExternalSecret` resources in `quant-engine-mt5`.

- `sync_quant_engine_envs_to_gcp.sh`
  Reads `mt5-quant-server/infra/envs/core.env` and `messaging.env`, bundles the
  sensitive values per service and environment, and uploads them to GCP Secret Manager.

### Workload Operations

- `website_rollout.sh`
  Apply or verify the website manifests and rollout.

- `set_website_image_tag.sh`
  Update the website image tag in Git.

- `check.sh`
  Quick cluster or rollout checks.
