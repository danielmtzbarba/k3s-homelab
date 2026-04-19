# k3s Homelab

This repository contains the first complete learning path for a self-managed k3s cluster on GCP:

- bootstrap Terraform backend
- provision one server
- install and verify k3s on the server
- add one worker
- deploy a trivial echo app through Traefik

## Operator Path

1. Copy `.env.example` to `.env`.
2. Follow [docs/INFRA.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/docs/INFRA.md:1).
3. Follow [docs/K3S_SERVER_SETUP.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/docs/K3S_SERVER_SETUP.md:1).
4. Follow [docs/K3S_WORKER_SETUP.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/docs/K3S_WORKER_SETUP.md:1).
5. Follow [docs/ECHO_APP.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/docs/ECHO_APP.md:1).

## Quick Commands

```bash
sh scripts/infra.sh bootstrap
sh scripts/infra.sh apply
sh scripts/infra.sh kubeconfig
sh scripts/worker.sh apply
sh scripts/worker.sh join
kubectl apply -f manifests/echo-app.yaml
sh scripts/check.sh
```

## Repo Shape

```text
.
├── .env.example
├── docs/
├── infra/terraform/
│   ├── bootstrap/
│   ├── server/
│   └── worker/
├── manifests/
├── scripts/
└── future-work/
```

## Important Assumptions

- keep the VM subnet away from the default k3s pod CIDR; use `10.10.0.0/24`, not `10.42.0.0/24`
- `k3s-agent` is still the actual worker-side systemd service name used by k3s
- generated Terraform artifacts stay out of version control
