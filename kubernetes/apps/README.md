# Kubernetes Apps

This directory is the canonical home for cluster-level manifests and app deployment resources.

Current layout:

- `danielmtz-website-prod-tls/`
  Production website app with public ingress and TLS.

- `danielmtz-website-dev-tls/`
  Private development website app exposed through the tailnet via NodePort.

The intent is simple:

- infrastructure lives in `infra/terraform/`
- node bootstrap lives in `scripts/`
- cluster applications live in `kubernetes/apps/`
- cluster platform components live in `kubernetes/platform/`

The MT5 quant stack is now app-owned in:

- `/home/danielmtz/Projects/kubernetes/quant-server-config`
