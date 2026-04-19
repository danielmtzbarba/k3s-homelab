# k3s Homelab

This repository is intentionally staged.

Right now the root is only for the first infrastructure steps:

- understand the GCP networking and VM building blocks
- add the first flat Terraform stack for one server
- provision the base infrastructure and then install one k3s server manually
- use a local `.env` file for values

Everything beyond that lives under `future-work/` until the first path is boring and understood.

## Root Structure

```text
.
├── .env.example
├── docs/
│   ├── INFRA.md
│   └── K3S_SERVER_SETUP.md
├── infra/
│   └── terraform/
│       ├── bootstrap/
│       └── server/
└── future-work/
```

## Current Workflow

1. Copy `.env.example` to `.env`.
2. Fill in your GCP values.
3. Follow [docs/INFRA.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/docs/INFRA.md:1) to create the backend bucket, enable APIs, and provision the server.
4. Follow [docs/K3S_SERVER_SETUP.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/docs/K3S_SERVER_SETUP.md:1) to install and verify k3s on the VM.

Do not add services yet. Learn the infrastructure lifecycle first.
