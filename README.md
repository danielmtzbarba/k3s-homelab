<div align="center">

# k3s Homelab

**A practical k3s learning path on GCP with Terraform, shell automation, Traefik, and HTTPS**

[![Terraform](https://img.shields.io/badge/terraform-IaC-623CE4)](https://developer.hashicorp.com/terraform)
[![GCP](https://img.shields.io/badge/gcp-compute%20engine-4285F4)](https://cloud.google.com/compute)
[![k3s](https://img.shields.io/badge/k3s-lightweight%20kubernetes-FFC61C)](https://k3s.io/)
[![cert-manager](https://img.shields.io/badge/cert--manager-TLS-326CE5)](https://cert-manager.io/)
[![Argo CD](https://img.shields.io/badge/argo%20cd-GitOps-EF7B4D)](https://argo-cd.readthedocs.io/)

</div>

## Overview

`k3s-homelab` is a hands-on Kubernetes learning repository focused on building and understanding a small self-managed cluster on GCP.

The repository is intentionally opinionated around a simple progression:

- bootstrap Terraform remote state
- provision a first k3s server on GCP
- join a first worker node
- deploy a real website workload
- expose production through Traefik
- keep development private on the tailnet
- issue a real TLS certificate with cert-manager and Let's Encrypt

This repository is a clean base for understanding infrastructure, node bootstrap, cluster access, ingress, and HTTPS before moving real services onto Kubernetes.

## Current Status

The repository currently supports:

- Terraform bootstrap for a GCS remote-state bucket
- Terraform server stack for:
  - VPC
  - subnet
  - firewall rules
  - static public IP
  - service account
  - GCE VM
- Terraform worker stack for a first k3s worker node
- VM bootstrap scripts for:
  - k3s server setup
  - k3s worker join
  - shell and sysctl/module hardening required for k3s networking
- cloud-init worker bootstrap for:
  - reserved internal worker IP
  - worker Tailscale join on boot
  - worker `k3s-agent` join on boot when `K3S_CLUSTER_TOKEN` is configured
- local operator wrappers for:
  - infra bootstrap/apply/destroy
  - server setup
  - kubeconfig retrieval
  - add-on deployment
- a working website deployment with:
  - Route53 DNS
  - Traefik ingress
  - cert-manager
  - Let's Encrypt
  - Tailscale-based admin access

The current cluster path has been validated end to end:

- infrastructure provisioned by Terraform
- server bootstrap automated through `infra.sh`
- worker join automated through `worker.sh`
- worker recreation validated through cloud-init bootstrap
- website reachable over HTTPS
- `www` redirecting to the apex domain
- separate prod and dev website app paths
- Argo CD installed for GitOps
- admin access working over Tailscale

## Key Features

- **Flat, understandable Terraform layout** for backend bootstrap, server infra, and worker infra.
- **Thin shell automation** around Terraform and cluster operations instead of burying everything in CI too early.
- **k3s-specific node bootstrap** including required kernel modules, sysctls, `tls-san`, and shell setup.
- **Cloud-init worker bootstrap** so recreated workers can rejoin Tailscale and k3s without SSH.
- **Remote kubeconfig automation** for local cluster access after server creation.
- **Cluster add-on deployment path** for cert-manager and shared issuer resources.
- **Canonical app path** for the website workload with `kustomize` and TLS included.
- **Tailscale-based admin access** for SSH and kubeconfig after cluster bootstrap.
- **Operator-focused documentation** that follows the actual execution order.

## Documentation

Project documentation lives in `docs/`:

- [Infrastructure Bootstrap](docs/INFRA.md)
- [k3s Server Setup](docs/K3S_SERVER_SETUP.md)
- [k3s Worker Setup](docs/K3S_WORKER_SETUP.md)
- [HTTPS With cert-manager](docs/HTTPS.md)
- [Tailscale On The Cluster](docs/TAILSCALE_CLUSTER.md)
- [Personal Website Roadmap](docs/PERSONAL_WEBSITE_ROADMAP.md)
- [Website Deployment](docs/WEBSITE_DEPLOYMENT.md)
- [Website Rollout](docs/WEBSITE_ROLLOUT.md)
- [From Zero To Website](docs/FROM_ZERO_TO_WEBSITE.md)
- [Argo CD Install](docs/ARGOCD.md)
- [Argo CD Roadmap](docs/ARGOCD_ROADMAP.md)
- [Argo CD Environment Roadmap](docs/ARGOCD_ENVIRONMENTS.md)
- [Argo CD Image Updater](docs/ARGOCD_IMAGE_UPDATER.md)
- [Observability](docs/OBSERVABILITY.md)
- [Private Tailnet Apps](docs/PRIVATE_TAILNET_APPS.md)
- [Secrets](docs/SECRETS.md)
- [ESO On GCP With WIF](docs/ESO_GCP_WIF.md)
- [MT5 Quant Server Migration Design](docs/MT5_QUANT_MIGRATION.md)

These docs describe the repository as it exists today, not a future target architecture.

## Repository Layout

`k3s-homelab/` is organized into a few main layers:

- `infra/terraform/bootstrap/`
  Creates the GCS bucket used as the Terraform remote backend.

- `infra/terraform/server/`
  Provisions the first GCP network and k3s server VM.

- `infra/terraform/worker/`
  Provisions the first worker VM on the same network, with cloud-init support for Tailscale and `k3s-agent` boot-time join.

- `scripts/`
  Thin operator wrappers and VM bootstrap scripts for infrastructure, cluster access, platform bootstrap, and workload rollout. See [scripts/README.md](scripts/README.md).

- `kubernetes/apps/`
  Canonical home for cluster application workloads such as `danielmtz-website-prod-tls` and `danielmtz-website-dev-tls`.

- `kubernetes/platform/`
  Canonical home for cluster platform components such as cert-manager, issuer resources, and Argo CD scaffolding.

- `docs/`
  Step-by-step operator documentation for the current learning path.

## Setup

Start from the repository root:

```bash
cp .env.example .env
```

Then follow the operator path:

1. [docs/INFRA.md](docs/INFRA.md)
2. [docs/K3S_SERVER_SETUP.md](docs/K3S_SERVER_SETUP.md)
3. [docs/K3S_WORKER_SETUP.md](docs/K3S_WORKER_SETUP.md)
4. [docs/HTTPS.md](docs/HTTPS.md)

## Quick Commands

```bash
sh scripts/infra.sh bootstrap
sh scripts/infra.sh apply
sh scripts/infra.sh server-setup
sh scripts/infra.sh kubeconfig
sh scripts/worker.sh apply
sh scripts/infra.sh platform-bootstrap
sh scripts/infra.sh deploy-addons
sh scripts/infra.sh deploy-argocd
sh scripts/infra.sh deploy-image-updater
sh scripts/infra.sh deploy-tailscale-operator
sh scripts/check.sh
```

Use `sh scripts/worker.sh join` only as a recovery path for an existing worker. The preferred worker path is now:

- set `WORKER_INTERNAL_IP`
- set `TAILSCALE_ENABLE=true`
- set `TAILSCALE_WORKER_AUTH_KEY`
- set `K3S_CLUSTER_TOKEN`
- run `sh scripts/worker.sh apply`

## Current Scope

The current repository covers:

- Terraform-managed GCP infrastructure
- manual-but-repeatable cluster bring-up
- remote cluster access from a local machine
- multi-node scheduling on k3s
- ingress routing with Traefik
- public HTTPS with Let's Encrypt

Planned next layers include:

- production-grade secret management
- backups and disaster recovery
- Argo CD-managed GitOps reconciliation for prod and dev
- centralized observability
- stateful workloads
- high-availability control planes

## Current Constraints

- the server is a single control-plane node
- worker-side k3s still uses the actual upstream service name `k3s-agent`
- the VM subnet must not overlap with the default k3s pod CIDR; use `10.10.0.0/24`, not `10.42.0.0/24`
- generated Terraform artifacts should stay out of version control
