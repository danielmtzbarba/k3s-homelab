# Tailscale Operator

This directory contains the GitOps scaffolding for the Tailscale Kubernetes Operator.

Use this component when you want cluster workloads to be reachable on the tailnet
without exposing them on the public internet.

Current intended use:

- private HTTPS access to Grafana
- private HTTPS access to Argo CD
- private HTTPS access to the quant `core-service` admin panel
- private HTTPS access to the quant `sync-service` dashboard

Why this operator exists in this repo:

- Tailscale on the server VM already gives you private admin access to SSH and `kubectl`
- the operator adds a cluster-native way to expose selected Services or Ingresses to the tailnet
- this is a cleaner private app access model than public ingress or ad hoc NodePorts

## Important Boundary

Keep this separate from the existing public Traefik ingress path.

- public domains stay on the existing `traefik` ingress class
- private tailnet-only app access uses the `tailscale` ingress class

That separation is the safe model for this cluster.

## Required External Setup

The operator requires Tailscale OAuth client credentials that should not be committed to Git.

Before enabling the operator:

1. In the Tailscale admin console, create:
   - `tag:k8s-operator`
   - `tag:k8s`
2. Make `tag:k8s-operator` an owner of `tag:k8s`
3. Create an OAuth client with:
   - `Devices Core` write scope
   - `Auth Keys` write scope
   - `Services` write scope
   - tag `tag:k8s-operator`
4. Store the client ID and client secret in a Kubernetes Secret or another secret backend you trust

Official references:

- https://tailscale.com/docs/features/kubernetes-operator/
- https://tailscale.com/kb/1439/kubernetes-operator-cluster-ingress

## Current Repo Scope

This repository currently adds:

- private `Ingress` resources for Grafana and Argo CD using ingress class `tailscale`
- private `Ingress` for the quant `core-service` admin panel using ingress class `tailscale`
- private `Ingress` for the quant `sync-service` dashboard using ingress class `tailscale`
- a `kustomization.yaml` so Argo CD can manage those private ingress resources from Git
- a shell wrapper at `scripts/deploy_tailscale_operator.sh` for the credentialed Helm install
- an ESO-based `ExternalSecret` template for the operator OAuth secret
- documentation for the private tailnet-only access path

It does not commit live OAuth credentials.

## External Secrets Template

The preferred steady-state path for the operator OAuth secret is:

- GCP Secret Manager
- `ClusterSecretStore`
- `ExternalSecret`
- generated Kubernetes secret `tailscale/operator-oauth`

Template:

- `externalsecret-operator-oauth.example.yaml`

Replace the `remoteRef.key` values if your GCP secret IDs differ from:

- `k3s-ts-oauth-client-id`
- `k3s-ts-oauth-client-secret`

Then apply it:

```bash
kubectl apply -f kubernetes/platform/tailscale-operator/externalsecret-operator-oauth.example.yaml
```

## Install Path

1. Bootstrap the operator secret stack:

```bash
cp .gcp-secrets.env.example .gcp-secrets.env
sh scripts/setup_tailscale_operator_secret_stack.sh
```

2. Install the operator:

```bash
sh scripts/infra.sh deploy-tailscale-operator
```

Steady-state recommendation:

- let External Secrets Operator create `tailscale/operator-oauth`
- run the deploy script without `TAILSCALE_OAUTH_CLIENT_ID` and `TAILSCALE_OAUTH_CLIENT_SECRET` in `.env`
- that keeps Helm from overwriting the ESO-managed secret

3. Let Argo CD own the private ingress resources:

```bash
kubectl apply -f kubernetes/platform/argocd/applications/tailscale-private-access.yaml
```

After that, Argo CD will reconcile:

- `grafana-private`
- `argocd-private`
- `quant-core-private`
- `quant-sync-private`

through the `tailscale` ingress class.
