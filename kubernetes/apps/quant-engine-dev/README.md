# Quant Engine Dev

This package is the first migration slice for the MT5 quant server app.

Scope in this first cut:

- `core-service`
- `messaging-service`
- `sync-service` manifests, disabled by default until image tag and secrets are set
- public webhook ingress for `quant.danielmtzbarba.com`

Still left on the legacy VM layout for now:

- `mt5-service`
- `sync-service` runtime until you enable the Kubernetes deployment

Both `quant-engine-dev` and `quant-engine-prod` currently share the namespace `quant-engine-mt5`, so every resource name in this package is environment-qualified. Shared namespace resources are owned by `quant-engine-shared/`.

Shared namespace resources now provide temporary bridge services for the still-external
execution plane:

- `Service/quant-engine-mt5-api`
- `Endpoints/quant-engine-mt5-api`

That keeps stable in-cluster service names while routing:

- `quant-engine-mt5-api:8000` -> legacy MT5 service

`sync-service` now runs in-cluster and is addressed directly as:

- `quant-engine-dev-sync-service:8080`

Before this package can run, you still need:

- `quant-engine-shared` applied first so the namespace and `ghcr-pull-secret` already exist
- GCP Secret Manager entries for the `ExternalSecret` keys in this package
- real image tags in `kustomization.yaml`

The new `sync-service` deployment is intentionally created with `replicas: 0` first.
That lets you land the manifests, seed the required secrets, set a real image SHA, and
then enable it without breaking the current bridge-based runtime.

Public ingress notes:

- `quant.danielmtzbarba.com/health` routes to `quant-engine-dev-messaging-service`
- `quant.danielmtzbarba.com/webhook` routes to `quant-engine-dev-messaging-service`
- WhatsApp webhook verification/callback should point at `https://quant.danielmtzbarba.com/webhook`
