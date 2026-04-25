# Quant Engine Dev

This package is the first migration slice for the MT5 quant server app.

Scope in this first cut:

- `core-service`
- `messaging-service`
- public webhook ingress for `quant.danielmtzbarba.com`

Still left on the legacy VM layout for now:

- `sync-service`
- `mt5-service`
- `influxdb-mt5`

Both `quant-engine-dev` and `quant-engine-prod` currently share the namespace `quant-engine-mt5`, so every resource name in this package is environment-qualified. Shared namespace resources are owned by `quant-engine-shared/`.

Before this package can run, you still need:

- `quant-engine-shared` applied first so the namespace and `ghcr-pull-secret` already exist
- GCP Secret Manager entries for the `ExternalSecret` keys in this package
- real values for the temporary external URLs that still point to the legacy execution plane
- real image tags in `kustomization.yaml`

Public ingress notes:

- `quant.danielmtzbarba.com/health` routes to `quant-engine-dev-messaging-service`
- `quant.danielmtzbarba.com/webhook` routes to `quant-engine-dev-messaging-service`
- WhatsApp webhook verification/callback should point at `https://quant.danielmtzbarba.com/webhook`
