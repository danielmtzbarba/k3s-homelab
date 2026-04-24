# Kubernetes Platform

This directory contains cluster-level platform components and shared resources.

Current layout:

- `argocd/`
  GitOps scaffolding for Argo CD and cluster application ownership.

- `argocd-image-updater/`
  Dev-focused automatic image detection and write-back scaffolding.

- `cert-manager/`
  Helm values for the cert-manager add-on.

- `observability/`
  Helm values for Prometheus, Grafana, Loki, and related observability platform components.

- `issuers/`
  Cluster-wide certificate issuer resources used by ingress TLS.

Use this directory for components that are not business applications but are part of the cluster platform itself.
