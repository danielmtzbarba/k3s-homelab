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

## Workload Identity Federation

The preferred next step for this repository is Google Workload Identity Federation rather than a long-lived JSON service account key.

Supporting files now included:

- `serviceaccount-gcpsm.yaml`
  Dedicated Kubernetes service account for ESO to use against GCP Secret Manager.

- `clustersecretstore-gcpsm-wif.example.yaml`
  Template for a `ClusterSecretStore` that uses Google Workload Identity Federation on a self-managed cluster.

See [docs/ESO_GCP_WIF.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/docs/ESO_GCP_WIF.md) for the required k3s issuer configuration and Google IAM setup.
