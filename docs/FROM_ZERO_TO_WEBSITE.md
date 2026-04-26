# From Zero To Website

This guide rebuilds the environment from zero and verifies the current end-to-end path:

- Terraform backend bucket
- server infrastructure
- k3s server bootstrap
- Tailscale admin access
- cert-manager platform add-on
- worker node join
- `danielmtz-website-prod-tls` deployment
- HTTPS on the real domain

This is the exact operator path for the current repository state.

## 1. Prepare `.env`

Before running anything, make sure your real `.env` has the values you want.

Important values for a full rebuild with Tailscale:

```bash
PUBLIC_SSH_ENABLE=true
TAILSCALE_ENABLE=true
TAILSCALE_AUTH_KEY=tskey-auth-...
TAILSCALE_HOSTNAME=k3s-server-1
TAILSCALE_ACCEPT_DNS=false
KUBECONFIG_ENDPOINT_MODE=tailscale
TF_STATE_FORCE_DESTROY=true
```

Notes:

- `PUBLIC_SSH_ENABLE=true`
  keeps initial public SSH open during rebuild, which is useful before Tailscale is verified again

- `TAILSCALE_ENABLE=true`
  enables Tailscale installation during server setup

- `KUBECONFIG_ENDPOINT_MODE=tailscale`
  makes kubeconfig use the server Tailscale IP instead of the public IP

- `TF_STATE_FORCE_DESTROY=true`
  is required only if you want `nuke` to destroy the backend bucket too

Load the environment into your shell:

```bash
set -a
source .env
set +a
```

## 2. Destroy Everything

Run the full reset:

```bash
sh scripts/infra.sh nuke
```

This destroys:

- worker infrastructure
- server infrastructure
- Terraform backend bucket infrastructure

## 3. Recreate The Backend And Server Infrastructure

Bootstrap the backend bucket again:

```bash
sh scripts/infra.sh bootstrap
```

Then create the server infrastructure:

```bash
sh scripts/infra.sh apply
```

## 4. Bootstrap The Server And Rebuild Kubeconfig

Run the server setup:

```bash
sh scripts/infra.sh server-setup
```

Then fetch kubeconfig:

```bash
sh scripts/infra.sh kubeconfig
```

Verify cluster access:

```bash
kubectl get nodes -o wide
kubectl cluster-info
```

Verify Tailscale SSH access:

```bash
ssh danielmtz@k3s-server-1
```

At this stage, you should have:

- working Tailscale SSH
- working kubeconfig over the tailnet

## 5. Deploy Platform Add-ons

Install or reconcile the platform add-ons:

```bash
sh scripts/infra.sh deploy-addons
```

Verify:

```bash
kubectl get pods -n cert-manager -o wide
kubectl get clusterissuer
```

## 6. Recreate The Worker

Create the worker infrastructure:

```bash
sh scripts/worker.sh apply
```

Join the worker to the cluster:

```bash
sh scripts/worker.sh join
```

Verify:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

At this stage, you should have:

- one server
- one worker
- both nodes `Ready`

## 7. Verify The GHCR Pull Secret Path

Because the website image lives in a private GHCR repository, the namespace needs `ghcr-pull-secret`.

The steady-state path is now declarative through:

- `kubernetes/apps/danielmtz-website-prod-tls/ghcr-pull-secret-externalsecret.yaml`

Create the namespace:

```bash
kubectl apply -f kubernetes/apps/danielmtz-website-prod-tls/namespace.yaml
```

Verify the `ExternalSecret` / secret:

```bash
kubectl get externalsecret,secret -n danielmtz-website-prod | grep ghcr-pull-secret
```

Manual fallback only if that path is broken:

```bash
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace danielmtz-website-prod \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT \
  --docker-email=YOUR_EMAIL
```

If the secret already exists from a partial retry and you need to recreate it manually:

```bash
kubectl delete secret ghcr-pull-secret -n danielmtz-website-prod
```

Then recreate it.

## 8. Deploy The Website

Use the rollout script:

```bash
sh scripts/website_rollout.sh apply prod
```

This:

- applies `kubernetes/apps/danielmtz-website-prod-tls`
- waits for rollout success
- prints deployment, pod, ingress, and certificate status

If you need to deploy a specific immutable image tag first:

```bash
sh scripts/website_rollout.sh apply prod <image-sha-tag>
```

You can also deploy manually if needed:

```bash
kubectl apply -k kubernetes/apps/danielmtz-website-prod-tls
kubectl rollout status deployment/danielmtz-website-prod -n danielmtz-website-prod --timeout=180s
```

## 9. Verify The Website

Check Kubernetes state:

```bash
kubectl get pods -n danielmtz-website-prod -o wide
kubectl get svc,ingress -n danielmtz-website-prod
kubectl get certificate -n danielmtz-website-prod
kubectl describe certificate danielmtzbarba-com-tls -n danielmtz-website-prod
```

Check the public site:

```bash
curl -I https://danielmtzbarba.com
curl -I https://www.danielmtzbarba.com
```

Expected:

- apex returns `200`
- `www` returns `308`

## 10. Close Public SSH Again

Once Tailscale SSH and `kubectl` access are confirmed working, disable public SSH again.

Update `.env`:

```bash
PUBLIC_SSH_ENABLE=false
```

Then apply:

```bash
sh scripts/infra.sh apply
```

Verify:

```bash
ssh danielmtz@k3s-server-1
kubectl get nodes -o wide
```

At this stage:

- public `22/tcp` should no longer be needed
- admin access should be over Tailscale

## 11. Final Health Check

Run:

```bash
sh scripts/check.sh
sh scripts/website_rollout.sh status
```

## Minimal Command Block

If you want the shortest exact command sequence:

```bash
set -a
source .env
set +a

sh scripts/infra.sh nuke
sh scripts/infra.sh bootstrap
sh scripts/infra.sh apply
sh scripts/infra.sh server-setup
sh scripts/infra.sh kubeconfig
sh scripts/infra.sh deploy-addons
sh scripts/worker.sh apply
sh scripts/worker.sh join

kubectl apply -f kubernetes/apps/danielmtz-website-prod-tls/namespace.yaml
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace danielmtz-website-prod \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT \
  --docker-email=YOUR_EMAIL

sh scripts/website_rollout.sh apply prod

curl -I https://danielmtzbarba.com
curl -I https://www.danielmtzbarba.com
```
