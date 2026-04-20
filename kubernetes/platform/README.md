# Kubernetes Platform

This directory contains cluster-level platform components and shared resources.

Current layout:

- `cert-manager/`
  Helm values for the cert-manager add-on.

- `issuers/`
  Cluster-wide certificate issuer resources used by ingress TLS.

Use this directory for components that are not business applications but are part of the cluster platform itself.
