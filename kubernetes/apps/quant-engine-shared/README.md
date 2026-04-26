# Quant Engine Shared

This package owns shared namespace-level resources for the quant-engine workloads.

It exists because `quant-engine-dev` and `quant-engine-prod` intentionally share the
namespace `quant-engine-mt5`, and Argo CD should not have two applications fighting
over the same `Namespace` or `ghcr-pull-secret` resource.

It also owns the shared in-cluster InfluxDB instance used by the quant workloads.

It now also includes a staged in-cluster MT5 runtime scaffold:

- `Deployment/quant-engine-mt5-runtime`
- `Service/quant-engine-mt5-service`
- `ConfigMap/quant-engine-mt5-config`
- `ExternalSecret/quant-engine-mt5-secrets`

The MT5 runtime now uses the published image tag wired in this repo and is the
authoritative in-cluster MT5 endpoint for the quant workloads.
