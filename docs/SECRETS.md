# Secrets

This document inventories the current secrets in the repository, defines the secret classes, and sets the migration target for cleaner secret management.

## Secret Classes

Use these classes consistently:

- `bootstrap-local`
  Short-lived local operator inputs used to bootstrap infrastructure or first-time access. These may live in `.env` temporarily, but should not remain the steady-state delivery path for cluster secrets.

- `platform-managed`
  Long-lived platform credentials consumed by shared controllers such as Argo CD, Image Updater, Tailscale Operator, or External Secrets Operator. These should move to GCP Secret Manager and be synced into Kubernetes with `ExternalSecret`, preferably using Workload Identity Federation instead of a static GCP service account key.

- `app-runtime`
  Application secrets consumed by workloads. These should also come from GCP Secret Manager through `ExternalSecret`, usually namespace-scoped.

- `controller-generated`
  Secrets created automatically by a controller or chart. These are not source-of-truth secrets and generally should not be manually created.

- `provider-issued`
  Secrets materialized by an external provider workflow such as cert-manager certificate issuance. These should remain controller-managed.

## Current Inventory

| Secret / Credential | Current Consumer | Current Location / Creation Path | Class | Steady-State Target |
| --- | --- | --- | --- | --- |
| `TAILSCALE_AUTH_KEY` | k3s server bootstrap | `.env`, consumed by [scripts/k3s_server_setup.sh](/home/danielmtz/Projects/kubernetes/k3s-homelab/scripts/k3s_server_setup.sh) | `bootstrap-local` | Keep local-only for bootstrap, rotate periodically, do not sync into cluster |
| `TAILSCALE_OAUTH_CLIENT_ID` | Tailscale Operator bootstrap only | local `.env` or one-time shell export, consumed by [scripts/sync_gcp_secrets.sh](/home/danielmtz/Projects/kubernetes/k3s-homelab/scripts/sync_gcp_secrets.sh) | `platform-managed` | GCP Secret Manager -> `ExternalSecret` -> `tailscale/operator-oauth` |
| `TAILSCALE_OAUTH_CLIENT_SECRET` | Tailscale Operator bootstrap only | local `.env` or one-time shell export, consumed by [scripts/sync_gcp_secrets.sh](/home/danielmtz/Projects/kubernetes/k3s-homelab/scripts/sync_gcp_secrets.sh) | `platform-managed` | GCP Secret Manager -> `ExternalSecret` -> `tailscale/operator-oauth` |
| `GRAFANA_ADMIN_USER` | Grafana admin login username | local `.env` or one-time shell export, consumed by [scripts/sync_gcp_secrets.sh](/home/danielmtz/Projects/kubernetes/k3s-homelab/scripts/sync_gcp_secrets.sh) | `platform-managed` | GCP Secret Manager -> `ExternalSecret` -> `observability/grafana-admin-credentials` |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin login password | local `.env` or one-time shell export, consumed by [scripts/sync_gcp_secrets.sh](/home/danielmtz/Projects/kubernetes/k3s-homelab/scripts/sync_gcp_secrets.sh) | `platform-managed` | GCP Secret Manager -> `ExternalSecret` -> `observability/grafana-admin-credentials` |
| `ALERTMANAGER_SLACK_WEBHOOK_URL` | Alertmanager Slack delivery | local `.env` or one-time shell export, consumed by [scripts/sync_gcp_secrets.sh](/home/danielmtz/Projects/kubernetes/k3s-homelab/scripts/sync_gcp_secrets.sh) | `platform-managed` | GCP Secret Manager -> `ExternalSecret` -> `observability/alertmanager-slack-webhook` |
| `repo-k3s-homelab` SSH deploy key | Argo CD repository access | Manual `kubectl create secret` in [docs/ARGOCD.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/docs/ARGOCD.md) | `platform-managed` | GCP Secret Manager -> `ExternalSecret` -> `argocd/repo-k3s-homelab` |
| `k3s-homelab-writeback` GitHub token | Argo CD Image Updater Git write-back | Manual `kubectl create secret` in [docs/ARGOCD_IMAGE_UPDATER.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/docs/ARGOCD_IMAGE_UPDATER.md) | `platform-managed` | GCP Secret Manager -> `ExternalSecret` -> `argocd/k3s-homelab-writeback` |
| `argocd/ghcr-pull-secret` | Argo CD Image Updater registry read access | Manual `kubectl create secret docker-registry` in [docs/ARGOCD_IMAGE_UPDATER.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/docs/ARGOCD_IMAGE_UPDATER.md) | `platform-managed` | GCP Secret Manager -> `ExternalSecret` -> `argocd/ghcr-pull-secret` |
| `danielmtz-website-*/ghcr-pull-secret` | Website image pulls in dev/prod namespaces | `ExternalSecret` in [kubernetes/apps/danielmtz-website-dev-tls/ghcr-pull-secret-externalsecret.yaml](/home/danielmtz/Projects/kubernetes/k3s-homelab/kubernetes/apps/danielmtz-website-dev-tls/ghcr-pull-secret-externalsecret.yaml) and [kubernetes/apps/danielmtz-website-prod-tls/ghcr-pull-secret-externalsecret.yaml](/home/danielmtz/Projects/kubernetes/k3s-homelab/kubernetes/apps/danielmtz-website-prod-tls/ghcr-pull-secret-externalsecret.yaml) | `app-runtime` | GCP Secret Manager -> namespace `ExternalSecret` -> workload image pull secret |
| `quant-engine-mt5/ghcr-pull-secret` | Quant engine image pulls in the shared namespace | `ExternalSecret` in [/home/danielmtz/Projects/kubernetes/quant-server-config/kubernetes/apps/quant-engine-shared/ghcr-pull-secret-externalsecret.yaml](/home/danielmtz/Projects/kubernetes/quant-server-config/kubernetes/apps/quant-engine-shared/ghcr-pull-secret-externalsecret.yaml) | `app-runtime` | GCP Secret Manager -> namespace `ExternalSecret` -> workload image pull secret |
| `quant-engine-dev` bundled service secrets | Quant engine dev `core-service`, `messaging-service`, and `sync-service` | `ExternalSecret` resources in [/home/danielmtz/Projects/kubernetes/quant-server-config/kubernetes/apps/quant-engine-dev](/home/danielmtz/Projects/kubernetes/quant-server-config/kubernetes/apps/quant-engine-dev) | `app-runtime` | One GCP secret per service/env -> `ExternalSecret dataFrom.extract` -> namespace `Secret` |
| `quant-engine-prod` bundled service secrets | Quant engine prod `core-service` and `messaging-service` | `ExternalSecret` resources in [/home/danielmtz/Projects/kubernetes/quant-server-config/kubernetes/apps/quant-engine-prod](/home/danielmtz/Projects/kubernetes/quant-server-config/kubernetes/apps/quant-engine-prod) | `app-runtime` | One GCP secret per service/env -> `ExternalSecret dataFrom.extract` -> namespace `Secret` |
| `quant-server-config-writeback` GitHub token | Quant Argo CD Image Updater Git write-back | `ExternalSecret` in [/home/danielmtz/Projects/kubernetes/quant-server-config/argocd/externalsecret-quant-server-config-writeback.yaml](/home/danielmtz/Projects/kubernetes/quant-server-config/argocd/externalsecret-quant-server-config-writeback.yaml) | `platform-managed` | GCP Secret Manager -> `ExternalSecret` -> `argocd/quant-server-config-writeback` |
| `argocd-initial-admin-secret` | First Argo CD login | Controller-generated by Argo CD chart, referenced in [docs/ARGOCD.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/docs/ARGOCD.md) | `controller-generated` | Keep generated; remove after first login |
| `danielmtzbarba-com-tls` | Website ingress TLS | Generated by cert-manager from [kubernetes/platform/issuers/letsencrypt-prod.yaml](/home/danielmtz/Projects/kubernetes/k3s-homelab/kubernetes/platform/issuers/letsencrypt-prod.yaml) and [kubernetes/apps/danielmtz-website-prod-tls/ingress.yaml](/home/danielmtz/Projects/kubernetes/k3s-homelab/kubernetes/apps/danielmtz-website-prod-tls/ingress.yaml) | `provider-issued` | Keep provider-managed by cert-manager |
| k3s node token (`/var/lib/rancher/k3s/server/node-token`) | Worker join | Generated by k3s, read by [scripts/worker.sh](/home/danielmtz/Projects/kubernetes/k3s-homelab/scripts/worker.sh) | `controller-generated` | Keep node-generated; do not store in Git |
| kubeconfig at `~/.kube/config-k3s-lab` | Local cluster admin access | Generated by [scripts/fetch_kubeconfig.sh](/home/danielmtz/Projects/kubernetes/k3s-homelab/scripts/fetch_kubeconfig.sh) | `bootstrap-local` | Keep local-only; do not sync into cluster |

## Naming Convention For GCP Secret Manager

Use a stable path-like naming convention:

- `k3s-homelab/platform/tailscale/oauth-client-id`
- `k3s-homelab/platform/tailscale/oauth-client-secret`
- `k3s-homelab/platform/argocd/repo-ssh-private-key`
- `k3s-homelab/platform/argocd-image-updater/github-token`
- `k3s-homelab/platform/ghcr/pull-secret`
- `k3s-homelab/apps/danielmtz-website/dev/ghcr-pull-secret`
- `k3s-homelab/apps/danielmtz-website/prod/ghcr-pull-secret`
- `k3s-quant-engine-ghcr-dockerconfigjson`
- `k3s-quant-engine-dev-core-env`
- `k3s-quant-engine-dev-messaging-env`
- `k3s-quant-engine-prod-core-env`
- `k3s-quant-engine-prod-messaging-env`

## Initial Migration Order

Migrate these first:

1. Tailscale Operator OAuth client ID and secret
2. Argo CD repository SSH key
3. Argo CD Image Updater Git write-back token
4. GHCR pull credentials in `argocd`
5. GHCR pull credentials in app namespaces

Do not start with:

- cert-manager TLS secrets
- k3s node token
- local kubeconfig

Those are either controller-generated or deliberately local-only.

## Local Sync Script

For local operator-driven sync into GCP Secret Manager, use:

- [scripts/sync_gcp_secrets.sh](/home/danielmtz/Projects/kubernetes/k3s-homelab/scripts/sync_gcp_secrets.sh)
- [scripts/setup_tailscale_operator_secret_stack.sh](/home/danielmtz/Projects/kubernetes/k3s-homelab/scripts/setup_tailscale_operator_secret_stack.sh)
- [.env.example](/home/danielmtz/Projects/kubernetes/k3s-homelab/.env.example)
- [infra/envs/README.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/infra/envs/README.md)

Model:

- each `GCP_SECRET_<NAME>` variable defines the GCP secret ID
- the matching `<NAME>` variable defines the uploaded value
- or `<NAME>_FILE` can point to a file whose contents should be uploaded

Example:

```bash
GCP_SECRET_TAILSCALE_OAUTH_CLIENT_ID="k3s-ts-oauth-client-id"
TAILSCALE_OAUTH_CLIENT_ID="..."
```

```bash
GCP_SECRET_GRAFANA_ADMIN_PASSWORD="k3s-grafana-admin-password"
GRAFANA_ADMIN_PASSWORD="..."
```

```bash
GCP_SECRET_ALERTMANAGER_SLACK_WEBHOOK_URL="k3s-alertmanager-slack-webhook-url"
ALERTMANAGER_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

For multiline or file-backed secrets such as the Argo CD repo SSH key:

```bash
GCP_SECRET_ARGOCD_REPO_SSH_PRIVATE_KEY="k3s-argocd-repo-ssh-private-key"
ARGOCD_REPO_SSH_PRIVATE_KEY_FILE="$HOME/.ssh/id_ed25519_argocd"
```

By default, the script only creates missing secrets and skips any secret that already exists. That is the safe mode for repeated bootstrap runs.

If you want the old delete/recreate behavior to avoid version buildup, pass `--delete-existing`. That also resets secret-level IAM bindings, so set:

```bash
GCP_SECRET_ACCESSORS="serviceAccount:eso-gcpsm@your-gcp-project-id.iam.gserviceaccount.com"
```

Then run:

```bash
cp .env.example .env
sh scripts/sync_gcp_secrets.sh
```

To force delete/recreate mode:

```bash
sh scripts/sync_gcp_secrets.sh --delete-existing
```

For the current platform secret stack, the wrapper path is:

```bash
cp .env.example .env
sh scripts/setup_tailscale_operator_secret_stack.sh
sh scripts/infra.sh deploy-tailscale-operator
```

For the GCP Secret Manager bootstrap credential used by External Secrets
Operator itself, set one of:

```bash
GCPSM_SECRET_ACCESS_CREDENTIALS_FILE="${K3S_HOMELAB_ROOT}/infra/terraform/server/generated/eso-gcpsm.json"
```

or:

```bash
GCPSM_SECRET_ACCESS_CREDENTIALS='{"type":"service_account",...}'
```

If you keep the default Terraform server settings, that file is generated automatically
by the server stack and no extra `gcloud iam service-accounts keys create ...` step is
required.

For the quant-engine config repo slice, use:

```bash
cd /home/danielmtz/Projects/kubernetes/quant-server-config
sh scripts/sync_quant_engine_envs_to_gcp.sh --environment dev
sh scripts/setup_quant_engine_secret_stack.sh
```

That reads:

- `/home/danielmtz/Projects/algotrading/mt5-quant-server/infra/envs/core.env`
- `/home/danielmtz/Projects/algotrading/mt5-quant-server/infra/envs/messaging.env`
- `/home/danielmtz/Projects/algotrading/mt5-quant-server/infra/envs/sync.env`
- `/home/danielmtz/Projects/algotrading/mt5-quant-server/infra/envs/mt5.env`

bundles the sensitive values into one GCP secret per service and environment, and then materializes them into `quant-engine-mt5` through ESO.

The quant app-owned write-back credential now lives in the config repo too:

```bash
kubectl apply -f /home/danielmtz/Projects/kubernetes/quant-server-config/argocd/externalsecret-quant-server-config-writeback.yaml
```

The old quant secret scripts and quant workload manifests have been removed from
`k3s-homelab` now that live ownership has moved to `quant-server-config`.
