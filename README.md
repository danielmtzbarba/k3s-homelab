<div align="center">

# k3s Homelab

**A practical k3s learning path on GCP with Terraform, shell automation, Traefik, and HTTPS**

[![Terraform](https://img.shields.io/badge/terraform-IaC-623CE4)](https://developer.hashicorp.com/terraform)
[![GCP](https://img.shields.io/badge/gcp-compute%20engine-4285F4)](https://cloud.google.com/compute)
[![k3s](https://img.shields.io/badge/k3s-lightweight%20kubernetes-FFC61C)](https://k3s.io/)
[![cert-manager](https://img.shields.io/badge/cert--manager-TLS-326CE5)](https://cert-manager.io/)

</div>

## Overview

`k3s-homelab` is a hands-on Kubernetes learning repository focused on building and understanding a small self-managed cluster on GCP.

The repository is intentionally opinionated around a simple progression:

- bootstrap Terraform remote state
- provision a first k3s server on GCP
- join a first worker node
- deploy a trivial HTTP workload
- expose it through Traefik
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
- local operator wrappers for:
  - infra bootstrap/apply/destroy
  - server setup
  - kubeconfig retrieval
  - add-on deployment
- a working echo example exposed by Traefik
- HTTPS for the echo app with:
  - Route53 DNS
  - cert-manager
  - Let's Encrypt

The current cluster path has been validated end to end:

- infrastructure provisioned by Terraform
- server bootstrap automated through `infra.sh`
- worker join automated through `worker.sh`
- echo app reachable over HTTP
- echo app reachable over HTTPS

## Key Features

- **Flat, understandable Terraform layout** for backend bootstrap, server infra, and worker infra.
- **Thin shell automation** around Terraform and cluster operations instead of burying everything in CI too early.
- **k3s-specific node bootstrap** including required kernel modules, sysctls, `tls-san`, and shell setup.
- **Remote kubeconfig automation** for local cluster access after server creation.
- **Cluster add-on deployment path** for cert-manager and TLS ingress.
- **Minimal test workload** to validate scheduling, ingress, and certificate issuance before real services.
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

These docs describe the repository as it exists today, not a future target architecture.

## Repository Layout

`k3s-homelab/` is organized into a few main layers:

- `infra/terraform/bootstrap/`
  Creates the GCS bucket used as the Terraform remote backend.

- `infra/terraform/server/`
  Provisions the first GCP network and k3s server VM.

- `infra/terraform/worker/`
  Provisions the first worker VM on the same network.

- `scripts/`
  Thin operator wrappers and VM bootstrap scripts for server setup, worker join, kubeconfig retrieval, checks, and add-on deployment.

- `manifests/`
  Legacy manifest staging area kept from the initial bootstrap phase.

- `kubernetes/apps/`
  Canonical home for cluster application workloads such as `danielmtz-website-tls`.

- `kubernetes/platform/`
  Canonical home for cluster platform components such as cert-manager and shared issuer resources.

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
sh scripts/worker.sh join
sh scripts/infra.sh deploy-addons
sh scripts/check.sh
```

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
- GitOps
- centralized observability
- stateful workloads
- high-availability control planes

## Current Constraints

- the server is a single control-plane node
- worker-side k3s still uses the actual upstream service name `k3s-agent`
- the VM subnet must not overlap with the default k3s pod CIDR; use `10.10.0.0/24`, not `10.42.0.0/24`
- generated Terraform artifacts should stay out of version control
