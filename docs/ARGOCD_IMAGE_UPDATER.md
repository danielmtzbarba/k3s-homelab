# Argo CD Image Updater

This document installs Argo CD Image Updater and wires it to the dev workloads that
should auto-advance from GHCR.

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

It does not create Git write-back credentials or container registry credentials.
It does apply the `ImageUpdater` resources from:

- `kubernetes/platform/argocd-image-updater/`

## Dev Application Requirement

The auto-advanced dev apps should be managed by:

- `kubernetes/platform/argocd/applications/danielmtz-website-dev.yaml`
- `kubernetes/platform/argocd/applications/quant-engine-dev.yaml`
- `kubernetes/platform/argocd/applications/quant-engine-shared.yaml`

Those apps should exist in Argo CD before you enable Image Updater for them.

## Dev Image Updater Resources

The updater resources live at:

- `kubernetes/platform/argocd-image-updater/image-updater-dev.yaml`
- `kubernetes/platform/argocd-image-updater/image-updater-quant-dev.yaml`
- `kubernetes/platform/argocd-image-updater/image-updater-quant-shared.yaml`

They are configured to:

- watch the Argo CD application `danielmtz-website-dev`
- watch the Argo CD application `quant-engine-dev`
- watch the Argo CD application `quant-engine-shared`
- inspect `ghcr.io/danielmtzbarba/danielmtz-website`
- inspect:
  - `ghcr.io/danielmtzbarba/core_service`
  - `ghcr.io/danielmtzbarba/messaging_service`
  - `ghcr.io/danielmtzbarba/sync_service`
  - `ghcr.io/danielmtzbarba/mt5_service`
- only consider branch-aware dev tags via:
  - `regexp:^dev-[0-9a-f]{40}$`
- use `newest-build` for immutable dev tags
- write the selected tag back to:
  - `kubernetes/apps/danielmtz-website-dev-tls`
  - `kubernetes/apps/quant-engine-dev`
  - `kubernetes/apps/quant-engine-shared`

## Quant Upstream Requirement

The quant repo currently publishes raw SHA tags for both the `dev` and `prod`
branches. That is not safe for Image Updater, because `newest-build` cannot tell
which branch a raw SHA came from.

For the quant services, the upstream GitHub Action should publish branch-aware tags:

- `dev-<40-char-sha>`
- `prod-<40-char-sha>`

for:

- `core_service`
- `messaging_service`
- `sync_service`
- `mt5_service`

The minimal workflow change in the quant repo looks like:

```yaml
- name: Compute branch-aware tag
  id: image_tag
  run: |
    if [ "${GITHUB_REF_NAME}" = "dev" ]; then
      echo "tag=dev-${GITHUB_SHA}" >> "${GITHUB_OUTPUT}"
    else
      echo "tag=prod-${GITHUB_SHA}" >> "${GITHUB_OUTPUT}"
    fi

- name: Build Service Image
  uses: docker/build-push-action@v5
  with:
    tags: ghcr.io/${{ github.repository_owner }}/${{ matrix.service }}:${{ steps.image_tag.outputs.tag }}
```

Without that upstream branch-aware tagging, the website updater remains safe, but the
quant updaters do not.

## Required Credentials

Image Updater needs:

### 1. GHCR Read Access

The current dev updater configuration expects a Docker pull secret at:

- `argocd/ghcr-pull-secret`

This keeps Image Updater from needing cross-namespace secret access.

Create it with:

```bash
kubectl create secret docker-registry ghcr-pull-secret \
  -n argocd \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GHCR_PAT \
  --docker-email=YOUR_EMAIL
```

The dev workload can still keep its own `ghcr-pull-secret` in `danielmtz-website-dev` for image pulls.

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
kubectl apply -f kubernetes/platform/argocd/applications/quant-engine-shared.yaml
kubectl apply -f kubernetes/platform/argocd/applications/quant-engine-dev.yaml
```

Verify:

```bash
kubectl get applications -n argocd
```

## Apply The Dev Image Updaters

After the credentials exist, deploy the updater:

```bash
sh scripts/infra.sh deploy-image-updater
```

Verify:

```bash
kubectl get imageupdaters -n argocd
kubectl describe imageupdater danielmtz-website-dev-updater -n argocd
kubectl describe imageupdater quant-engine-dev-updater -n argocd
kubectl describe imageupdater quant-engine-shared-updater -n argocd
kubectl logs -n argocd deploy/argocd-image-updater-controller
```

## Expected Flow

1. the upstream repo pushes a new branch-aware dev image tag such as `dev-<40-char-sha>`
2. Image Updater detects the new image in GHCR
3. Image Updater commits the updated image tag to one of:
   - `kubernetes/apps/danielmtz-website-dev-tls/kustomization.yaml`
   - `kubernetes/apps/quant-engine-dev/kustomization.yaml`
   - `kubernetes/apps/quant-engine-shared/kustomization.yaml`
4. Argo CD sees the Git change
5. Argo CD auto-syncs the dev application
6. because the rendered Deployment image field changes to a new immutable tag, Kubernetes creates a new ReplicaSet and rolls out new pods for that image

## Important Boundary

This automation applies only to the dev workloads.

Production should continue to use the PR-based flow.

Sources:

- [Argo CD Image Updater installation](https://argocd-image-updater.readthedocs.io/en/stable/install/installation/)
- [Argo CD Image Updater application configuration](https://argocd-image-updater.readthedocs.io/en/latest/configuration/applications/)
- [Argo CD Image Updater update methods](https://argocd-image-updater.readthedocs.io/en/latest/basics/update-methods/)
- [Argo CD Image Updater update strategies](https://argocd-image-updater.readthedocs.io/en/latest/basics/update-strategies/)
