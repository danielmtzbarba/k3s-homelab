# Kubernetes Platform

This directory contains cluster-level platform components and shared resources.

Current layout:

- `argocd/`
  GitOps scaffolding for Argo CD and cluster application ownership.

- `argocd-image-updater/`
  Dev-focused automatic image detection and write-back scaffolding.

- `cert-manager/`
  Helm values for the cert-manager add-on.

- `external-secrets/`
  Helm values and secret-management scaffolding for External Secrets Operator.

- `observability/`
  Helm values for Prometheus, Grafana, Loki, and related observability platform components.

- `promtail/`
  Kubernetes pod log collector that forwards logs into Loki.

- `tailscale-operator/`
  Private tailnet-only ingress scaffolding for internal UIs such as Grafana and Argo CD.

- `issuers/`
  Cluster-wide certificate issuer resources used by ingress TLS.

Use this directory for components that are not business applications but are part of the cluster platform itself.
