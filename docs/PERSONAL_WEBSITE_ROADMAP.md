# Personal Website Roadmap

This roadmap starts from the point where the cluster is already working:

- server and worker are joined
- Traefik ingress works
- HTTPS is already working through cert-manager and Let's Encrypt

The goal now is to deploy your personal website as the first real workload after the echo example.

## Target Structure

Cluster application manifests should now live under:

- `kubernetes/platform/cert-manager/`
- `kubernetes/platform/issuers/`
- `kubernetes/apps/danielmtz-website-tls/`

The website deployment should follow the same pattern:

1. `Deployment`
2. `Service`
3. `Ingress`
4. `Ingress` with TLS

## Step 1. Decide How The Website Runs

Before writing Kubernetes manifests, define the runtime shape of the website.

Pick one of these:

- static site served by `nginx` or `caddy`
- framework app served by its own runtime, such as Next.js or another Node server

The first option is better for the initial deployment if your site can be exported as static files.

Why:

- fewer moving parts
- smaller image
- easier health checks
- simpler rollout behavior

## Step 2. Containerize The Website

Your first real task is not Kubernetes. It is making the website image clean and reproducible.

The website image should:

- build deterministically
- expose one HTTP port
- run as a single process
- serve the built site reliably

Exit criteria for this step:

- you can build the image locally
- you can run it locally
- you can open the site in a browser on the expected port

## Step 3. Choose The Public Hostname

Pick the website hostname before writing the ingress.

Good options:

- `danielmtzbarba.com`
- `www.danielmtzbarba.com`
- `site.k3s.danielmtzbarba.com`

Recommendation:

- keep the root or `www` hostname for the website
- keep future subdomains available for later services if needed

You should create the corresponding Route53 record before enabling TLS.

## Step 4. Create The Website Kubernetes Manifests

Once the image exists, create the first website manifests inside:

- `kubernetes/apps/danielmtz-website-tls/deployment.yaml`
- `kubernetes/apps/danielmtz-website-tls/service.yaml`
- `kubernetes/apps/danielmtz-website-tls/ingress.yaml`

The current version includes:

- `replicas: 2`
- resource requests and limits
- `readinessProbe`
- `livenessProbe`
- `Ingress` with dedicated hostnames
- TLS using the existing `letsencrypt-prod` issuer

## Step 5. Deploy The App

Apply:

```bash
kubectl apply -k kubernetes/apps/danielmtz-website-tls
```

Then verify:

- pods are running
- the service resolves
- the website serves through the ingress
- the certificate is issued cleanly

Verify:

- `kubectl get certificate`
- `kubectl describe certificate`
- `curl -I https://<your-hostname>`

## Step 6. Test Rollouts

Once the first deployment works, force yourself to test an actual update.

You should:

- build a second image version
- update the `Deployment`
- observe rollout behavior
- confirm there is no broken ingress routing during the update

This is where the deployment starts becoming real.

## Step 7. Add Minimal Operational Hardening

Before calling the website deployment stable, add:

- explicit resource requests and limits
- non-root container execution if the image supports it
- rollout history visibility
- clear image tagging strategy
- a simple rollback path

Do not jump into heavy platform work yet. Keep the first website deployment simple and correct.

## Recommended Execution Order

1. finalize how the website runs locally
2. containerize it
3. choose the hostname
4. create Route53 DNS
5. add website manifests under `kubernetes/apps/danielmtz-website-tls/`
6. deploy the app
7. test one full update/rollout

## What I Recommend Next

The next concrete step is to inspect the website project itself and decide whether it should be deployed as:

- a static site image
- or an application server image

That decision determines the manifest shape, resource profile, and health checks.

## Current Imported Baseline

The repository now already contains the first website deployment baseline in:

- `kubernetes/apps/danielmtz-website-tls/namespace.yaml`
- `kubernetes/apps/danielmtz-website-tls/deployment.yaml`
- `kubernetes/apps/danielmtz-website-tls/service.yaml`
- `kubernetes/apps/danielmtz-website-tls/ingress.yaml`

These files were adapted from the website repository infra.

Before applying them, you still need to:

1. decide whether `stable` is the right rollout tag for the deployment
2. apply the app and verify the certificate issuance path
