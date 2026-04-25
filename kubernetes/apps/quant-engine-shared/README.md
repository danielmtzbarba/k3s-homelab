# Quant Engine Shared

This package owns shared namespace-level resources for the quant-engine workloads.

It exists because `quant-engine-dev` and `quant-engine-prod` intentionally share the
namespace `quant-engine-mt5`, and Argo CD should not have two applications fighting
over the same `Namespace` or `ghcr-pull-secret` resource.
