# Argo CD

This directory holds the Argo CD layer for the cluster.

Scope:

- Argo CD namespace scaffolding
- Argo CD `Application` manifests
- future Argo CD install artifacts

This directory does not belong in:

- Terraform
- VM bootstrap scripts
- `scripts/k3s_server_setup.sh`

Argo CD is a cluster platform component and should be managed at the Kubernetes layer.

## Current Contents

- `namespace.yaml`
  Namespace scaffold for Argo CD.

- `values.yaml`
  Helm values for the Argo CD install.

- `applications/`
  Initial `Application` resources that Argo CD can reconcile after installation.

## First Intended Application

The first application Argo CD should own is:

- `danielmtz-website-prod`
- `danielmtz-website-dev`

Those apps already have:

- one canonical manifest path
- working `kustomize` layouts
- a public prod path and a private dev path

Because the repository is private, Argo CD will need repository credentials before the `Application` resources here can sync.

## Install Path

Use:

```bash
sh scripts/infra.sh deploy-argocd
```

That installs Argo CD with Helm into the `argocd` namespace and waits for the core pods to become ready.

## Next Step

After the install:

1. port-forward the Argo CD server
2. configure repository credentials
3. apply the application manifests in `applications/`

Keep the Argo CD server private to the admin path. Do not expose it publicly for this cluster stage.
