# Kubernetes Apps

This directory is the canonical home for cluster-level manifests and app deployment resources.

Current layout:

- `danielmtz-website-tls/`
  Canonical website deployment with TLS included.

The intent is simple:

- infrastructure lives in `infra/terraform/`
- node bootstrap lives in `scripts/`
- cluster applications live in `kubernetes/apps/`
- cluster platform components live in `kubernetes/platform/`
