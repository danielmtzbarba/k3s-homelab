# Quant Engine Shared

This package owns shared namespace-level resources for the quant-engine workloads.

It exists because `quant-engine-dev` and `quant-engine-prod` intentionally share the
namespace `quant-engine-mt5`, and Argo CD should not have two applications fighting
over the same `Namespace` or `ghcr-pull-secret` resource.

It also owns the temporary bridge services for the still-external execution plane:

- `quant-engine-mt5-api:8000` -> legacy MT5 service

It also owns the shared in-cluster InfluxDB instance used by the quant workloads.
