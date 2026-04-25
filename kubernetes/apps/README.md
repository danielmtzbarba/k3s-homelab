# Kubernetes Apps

This directory is the canonical home for cluster-level manifests and app deployment resources.

Current layout:

- `danielmtz-website-prod-tls/`
  Production website app with public ingress and TLS.

- `danielmtz-website-dev-tls/`
  Private development website app exposed through the tailnet via NodePort.

- `quant-engine-dev/`
  First migration slice for the MT5 quant app in the shared `quant-engine-mt5` namespace.

- `quant-engine-prod/`
  Production counterpart to `quant-engine-dev`, also using the shared `quant-engine-mt5` namespace.

- `quant-engine-shared/`
  Shared namespace-level resources for `quant-engine-dev` and `quant-engine-prod`.

The intent is simple:

- infrastructure lives in `infra/terraform/`
- node bootstrap lives in `scripts/`
- cluster applications live in `kubernetes/apps/`
- cluster platform components live in `kubernetes/platform/`
