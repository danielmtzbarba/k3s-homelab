# Private Tailnet Apps

This document defines the private app access model for internal UIs such as:

- Grafana
- Argo CD

## Goal

Expose selected cluster UIs on the tailnet only.

Requirements:

- no public DNS
- no public load balancer
- no reuse of the public Traefik ingress path
- reachable over Tailscale using private HTTPS hostnames
- MagicDNS enabled on the tailnet
- HTTPS enabled on the tailnet

## Why Not Use Public Traefik

The current public Traefik service is reachable on public web ports.

Even if you used a private-looking hostname, that would still reuse the public ingress path.

That is not the right boundary for Grafana or Argo CD.

## Recommended Model

Use the Tailscale Kubernetes Operator for private app ingress.

Why:

- it exposes selected cluster workloads directly to the tailnet
- it provisions HTTPS for the tailnet endpoint
- it avoids opening Grafana or Argo CD on the public internet
- it keeps private app access separate from public web ingress

Official references:

- [Tailscale Kubernetes Operator](https://tailscale.com/docs/features/kubernetes-operator/)
- [Cluster ingress to tailnet](https://tailscale.com/kb/1439/kubernetes-operator-cluster-ingress)

## Current Repo Manifests

Private ingress manifests live at:

- `kubernetes/platform/tailscale-operator/grafana-ingress.yaml`
- `kubernetes/platform/tailscale-operator/argocd-ingress.yaml`
- `kubernetes/platform/tailscale-operator/externalsecret-operator-oauth.example.yaml`
- `kubernetes/platform/tailscale-operator/kustomization.yaml`
- `kubernetes/platform/argocd/applications/tailscale-private-access.yaml`

These use:

- `ingressClassName: tailscale`
- host `grafana` for Grafana
- host `argocd` for Argo CD

The Tailscale docs state that only the first label of the requested host is used for the Tailscale node name.

## Prerequisites

Before these ingresses work, you must install the Tailscale Kubernetes Operator and provide OAuth client credentials outside Git.

Required Tailscale setup:

1. create tag `tag:k8s-operator`
2. create tag `tag:k8s`
3. allow `tag:k8s-operator` to own `tag:k8s`
4. create an OAuth client with:
   - `Devices Core` write scope
   - `Auth Keys` write scope
   - `Services` write scope
   - tag `tag:k8s-operator`

Bootstrap once:

```bash
cp .env.example .env
sh scripts/setup_tailscale_operator_secret_stack.sh
sh scripts/infra.sh deploy-tailscale-operator
```

Steady-state:

- keep the OAuth client credentials in GCP Secret Manager, not `.env`
- let ESO recreate `tailscale/operator-oauth`
- run `deploy-tailscale-operator` without `TAILSCALE_OAUTH_CLIENT_ID` and `TAILSCALE_OAUTH_CLIENT_SECRET` set

After the operator is ready, let Argo CD manage the private ingress resources:

```bash
kubectl apply -f kubernetes/platform/argocd/applications/tailscale-private-access.yaml
```

## Access Model

Once the operator is installed and the private ingress resources are applied:

- Grafana should be reachable at a tailnet hostname based on `grafana`
- Argo CD should be reachable at a tailnet hostname based on `argocd`

The exact FQDN is assigned by Tailscale for your tailnet and shown by the created proxy resource and in the Tailscale admin console.

The first HTTPS request can be slow because the operator provisions the certificate on first connect.

## Current Recommendation

Until the operator is installed, keep using:

- `kubectl port-forward` for Grafana
- `kubectl port-forward` for Argo CD

After the operator is proven, switch the operator path to be the normal private UI access method.
