# Infra Env Layout

Preferred local env layout:

- `infra/envs/infra.project.env`
- `infra/envs/infra.server.env`
- `infra/envs/infra.workers.env`
- `infra/envs/infra.access.env`
- `infra/envs/infra.terraform.env`

Preferred GCP secret sync layout:

- `infra/envs/gcp.platform.env`
- `infra/envs/gcp.argocd.env`
- `infra/envs/gcp.apps.env`

All scripts support the root `.env`.

Loading rules:

- infrastructure/bootstrap scripts load `.env` first if it exists
- otherwise they source `infra/envs/infra.*.env` in lexical order
- GCP secret sync scripts load `.env` first if it exists
- otherwise they source `infra/envs/gcp.*.env` in lexical order

Recommended root shim pattern:

- keep the real values in `infra/envs/*.env`
- make the root `.env` import both the split `infra.*.env` and `gcp.*.env` files

Example `.env`:

```bash
. "${K3S_HOMELAB_ROOT}/infra/envs/infra.project.env"
. "${K3S_HOMELAB_ROOT}/infra/envs/infra.server.env"
. "${K3S_HOMELAB_ROOT}/infra/envs/infra.workers.env"
. "${K3S_HOMELAB_ROOT}/infra/envs/infra.access.env"
. "${K3S_HOMELAB_ROOT}/infra/envs/infra.terraform.env"
. "${K3S_HOMELAB_ROOT}/infra/envs/gcp.platform.env"
. "${K3S_HOMELAB_ROOT}/infra/envs/gcp.argocd.env"
```

The loaders export `K3S_HOMELAB_ROOT` automatically before sourcing env files.

Recommended setup:

```bash
cp infra/envs/infra.project.env.example infra/envs/infra.project.env
cp infra/envs/infra.server.env.example infra/envs/infra.server.env
cp infra/envs/infra.workers.env.example infra/envs/infra.workers.env
cp infra/envs/infra.access.env.example infra/envs/infra.access.env
cp infra/envs/infra.terraform.env.example infra/envs/infra.terraform.env

cp infra/envs/gcp.platform.env.example infra/envs/gcp.platform.env
cp infra/envs/gcp.argocd.env.example infra/envs/gcp.argocd.env
```

Quant app-specific GCP env files now live in:

- `/home/danielmtz/Projects/kubernetes/quant-server-config/infra/envs/`

The restored `gcp.apps.env.example` in this repo now covers only the app secrets
still owned by `k3s-homelab`, such as:

- `argocd/ghcr-pull-secret`
- `danielmtz-website-dev/ghcr-pull-secret`
- `danielmtz-website-prod/ghcr-pull-secret`

For multi-worker reconciliation, put either:

- `WORKERS_JSON=...` in `infra.workers.env`
- or `WORKERS_TFVARS_PATH=...` in `infra.workers.env`

Actual `*.env` files in this directory are ignored by Git.
