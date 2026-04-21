# Argo CD Image Updater

This document installs Argo CD Image Updater and wires it to the dev website application only.

## Why Only Dev

The intended split is:

- `prod`
  PR-driven deployment approval

- `dev`
  automatic image detection and automatic sync

This keeps:

- production controlled
- development fast

## Install Path

Use:

```bash
sh scripts/infra.sh deploy-image-updater
```

Direct equivalent:

```bash
sh scripts/deploy_argocd_image_updater.sh
```

The install uses the official Argo CD Image Updater manifest in the `argocd` namespace, which is the recommended namespace choice when Argo CD already runs there.

## What The Install Does

It:

1. applies the upstream Image Updater install manifest into `argocd`
2. waits for the `argocd-image-updater-controller` deployment

It does not:

- create Git write-back credentials
- create container registry credentials
- apply the dev `ImageUpdater` resource automatically

Those stay explicit.

## Dev Application Requirement

The dev app should be managed by:

- `kubernetes/platform/argocd/applications/danielmtz-website-dev.yaml`

That app should exist in Argo CD before you enable Image Updater for it.

## Dev Image Updater Resource

The dev updater resource lives at:

- `kubernetes/platform/argocd-image-updater/image-updater-dev.yaml`

It is configured to:

- watch the Argo CD application `danielmtz-website-dev`
- inspect `ghcr.io/danielmtzbarba/danielmtz-website`
- only consider SHA-like tags via:
  - `regexp:^[0-9a-f]{40}$`
- use `newest-build` for immutable SHA tags
- write the selected tag back to:
  - `kubernetes/apps/danielmtz-website-dev-tls`

## Required Credentials

Image Updater needs:

### 1. GHCR Read Access

The current dev updater configuration expects a Docker pull secret at:

- `danielmtz-website-dev/ghcr-pull-secret`

That same secret is also used by the dev workload itself.

### 2. Git Write-Back Access

The current dev updater resource expects a secret at:

- `argocd/k3s-homelab-writeback`

Because the write-back method is:

```yaml
method: "git:secret:argocd/k3s-homelab-writeback"
```

and the repository is:

```yaml
repository: "https://github.com/danielmtzbarba/k3s-homelab.git"
```

That secret should contain:

- `username`
- `password`

where `password` is a GitHub token with write access to `danielmtzbarba/k3s-homelab`.

Create it with:

```bash
kubectl create secret generic k3s-homelab-writeback \
  -n argocd \
  --from-literal=username=YOUR_GITHUB_USERNAME \
  --from-literal=password=YOUR_GITHUB_TOKEN
```

## Apply The Argo CD Applications

Apply:

```bash
kubectl apply -f kubernetes/platform/argocd/applications/danielmtz-website-prod.yaml
kubectl apply -f kubernetes/platform/argocd/applications/danielmtz-website-dev.yaml
```

Verify:

```bash
kubectl get applications -n argocd
```

## Apply The Dev Image Updater

After the credentials exist, apply:

```bash
kubectl apply -f kubernetes/platform/argocd-image-updater/image-updater-dev.yaml
```

Verify:

```bash
kubectl get imageupdaters -n argocd
kubectl describe imageupdater danielmtz-website-dev-updater -n argocd
kubectl logs -n argocd deploy/argocd-image-updater-controller
```

## Expected Flow

1. website repo pushes a new SHA-tagged image from `dev`
2. Image Updater detects the new image in GHCR
3. Image Updater commits the updated image tag to:
   - `kubernetes/apps/danielmtz-website-dev-tls/kustomization.yaml`
4. Argo CD sees the Git change
5. the dev application syncs automatically

## Important Boundary

This automation applies only to the dev app.

Production should continue to use the PR-based flow.

Sources:

- [Argo CD Image Updater installation](https://argocd-image-updater.readthedocs.io/en/stable/install/installation/)
- [Argo CD Image Updater application configuration](https://argocd-image-updater.readthedocs.io/en/latest/configuration/applications/)
- [Argo CD Image Updater update methods](https://argocd-image-updater.readthedocs.io/en/latest/basics/update-methods/)
- [Argo CD Image Updater update strategies](https://argocd-image-updater.readthedocs.io/en/latest/basics/update-strategies/)
