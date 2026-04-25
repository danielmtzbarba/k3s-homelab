# Quant Engine Prod

This package is the production counterpart to `quant-engine-dev`.

Scope in this first cut:

- `core-service`
- `messaging-service`

Still left on the legacy VM layout for now:

- `sync-service`
- `mt5-service`
- `influxdb-mt5`

This package intentionally shares the namespace `quant-engine-mt5` with dev, so every resource name is environment-qualified. Shared namespace resources are owned by `quant-engine-shared/`.

Before this package can run, you still need:

- `quant-engine-shared` applied first so the namespace and `ghcr-pull-secret` already exist
- GCP Secret Manager entries for the `ExternalSecret` keys in this package
- real values for the temporary external URLs that still point to the legacy execution plane
- real image tags in `kustomization.yaml`
