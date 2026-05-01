# Argo CD Applications

This directory contains Argo CD `Application` resources.

Apply these only after:

- Argo CD is installed
- the `argocd` namespace exists
- the Argo CD CRDs are available in the cluster

Normal operator path:

```bash
sh scripts/infra.sh platform-reconcile
```

Current website applications:

- `danielmtz-website-prod.yaml`
- `danielmtz-website-dev.yaml`
- `external-secrets.yaml`
- `observability-kube-prometheus-stack.yaml`
- `observability-loki.yaml`
- `observability-promtail.yaml`
- `observability-dashboards.yaml`
- `tailscale-private-access.yaml`

Quant Argo `Application` manifests are now owned by:

- `/home/danielmtz/Projects/kubernetes/quant-server-config/argocd/applications`

Recommendation:

- keep production Git-approved through PR merge, then let Argo CD auto-sync
- allow development automation only after Image Updater is configured
- if two Argo applications share one namespace, resource names must stay environment-qualified to avoid collisions
