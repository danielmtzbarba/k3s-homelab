# External Secrets

This directory contains the Helm values and GitOps scaffolding for External Secrets Operator.

Current purpose:

- install External Secrets Operator as a platform component
- establish a standard path for syncing Kubernetes `Secret` objects from an external backend
- reduce manual `kubectl create secret` workflows over time

## Current Scope

This initial install does not yet wire a live backend such as GCP Secret Manager.

It creates the operator so the cluster is ready for:

- `ClusterSecretStore`
- `SecretStore`
- `ExternalSecret`

resources in the next migration step.

## Why This Component Exists

This repository currently mixes several secret patterns:

- `.env` values used during local bootstrap
- manual `kubectl create secret` commands
- controller-generated bootstrap secrets
- provider-generated runtime secrets

External Secrets Operator gives the cluster one standard way to receive managed secrets from outside Kubernetes.

## GCP Secret Manager

Supporting files now included:

- `clustersecretstore-gcpsm.example.yaml`
  Template for a `ClusterSecretStore` that authenticates to GCP Secret Manager
  using a Kubernetes secret containing a dedicated GCP service account key.

The bootstrap flow now creates a `gcpsm-secret` Kubernetes secret in the
`external-secrets` namespace and points the `ClusterSecretStore` at it.
