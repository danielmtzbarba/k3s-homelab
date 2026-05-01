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

## Current Ownership

The website dev updater is still owned by `k3s-homelab`.

The quant updaters have been cut over to the app-owned config repo:

- `/home/danielmtz/Projects/kubernetes/quant-server-config`

That means:

- live quant `Application` manifests should be applied from
  `quant-server-config/argocd/applications/`
- live quant `ImageUpdater` resources should be applied from
  `quant-server-config/argocd/image-updaters/`
- the old quant copies under `k3s-homelab` have been removed after cutover

## Dev Application Requirement

The auto-advanced dev apps should be managed by:

- `kubernetes/platform/argocd/applications/danielmtz-website-dev.yaml`
- `/home/danielmtz/Projects/kubernetes/quant-server-config/argocd/applications/quant-engine-dev.yaml`
- `/home/danielmtz/Projects/kubernetes/quant-server-config/argocd/applications/quant-engine-shared.yaml`

Those apps should exist in Argo CD before you enable Image Updater for them.

## Dev Image Updater Resources

The updater resources live at:

- `kubernetes/platform/argocd-image-updater/image-updater-dev.yaml`
- `/home/danielmtz/Projects/kubernetes/quant-server-config/argocd/image-updaters/image-updater-quant-dev.yaml`
- `/home/danielmtz/Projects/kubernetes/quant-server-config/argocd/image-updaters/image-updater-quant-shared.yaml`

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
  - `/home/danielmtz/Projects/kubernetes/quant-server-config/kubernetes/apps/quant-engine-dev`
  - `/home/danielmtz/Projects/kubernetes/quant-server-config/kubernetes/apps/quant-engine-shared`

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

The website updater in this repo expects a secret at:

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

For the quant updaters in `quant-server-config`, the expected secret is:

- `argocd/quant-server-config-writeback`

with declarative manifest:

- `/home/danielmtz/Projects/kubernetes/quant-server-config/argocd/externalsecret-quant-server-config-writeback.yaml`

and repository:

```yaml
repository: "https://github.com/danielmtzbarba/quant-server-config.git"
```

## Apply The Argo CD Applications

Apply:

```bash
kubectl apply -f kubernetes/platform/argocd/applications/danielmtz-website-prod.yaml
kubectl apply -f kubernetes/platform/argocd/applications/danielmtz-website-dev.yaml
kubectl apply -f /home/danielmtz/Projects/kubernetes/quant-server-config/argocd/applications/quant-engine-shared.yaml
kubectl apply -f /home/danielmtz/Projects/kubernetes/quant-server-config/argocd/applications/quant-engine-dev.yaml
kubectl apply -f /home/danielmtz/Projects/kubernetes/quant-server-config/argocd/applications/quant-engine-prod.yaml
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

Then apply the quant updater resources from the config repo:

```bash
kubectl apply -f /home/danielmtz/Projects/kubernetes/quant-server-config/argocd/image-updaters/image-updater-quant-dev.yaml
kubectl apply -f /home/danielmtz/Projects/kubernetes/quant-server-config/argocd/image-updaters/image-updater-quant-shared.yaml
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
   - `/home/danielmtz/Projects/kubernetes/quant-server-config/kubernetes/apps/quant-engine-dev/kustomization.yaml`
   - `/home/danielmtz/Projects/kubernetes/quant-server-config/kubernetes/apps/quant-engine-shared/kustomization.yaml`
4. Argo CD sees the Git change
5. Argo CD auto-syncs the dev application
6. because the rendered Deployment image field changes to a new immutable tag, Kubernetes creates a new ReplicaSet and rolls out new pods for that image

## Important Boundary

This automation applies only to the dev workloads.

Production should continue to use the PR-based flow.

## Reusable Config Repo Pattern

The quant stack is now the reference pattern for splitting app config out of the
platform repo into a dedicated Argo-tracked config repo.

Use this pattern when you want:

- the platform repo to keep owning cluster services only
- the app source repo to keep owning builds and image publishing
- a separate config repo to own Kubernetes manifests, app secrets wiring, and
  Argo CD Image Updater write-back

Minimal shape:

1. create a config repo with:
   - `kubernetes/apps/<app-shared>/`
   - `kubernetes/apps/<app-dev>/`
   - `kubernetes/apps/<app-prod>/`
   - `argocd/applications/`
   - `argocd/image-updaters/`
2. create an Argo repository secret for that repo
3. create an Image Updater write-back secret for that repo
4. point `Application.spec.source.repoURL` at the config repo
5. point `ImageUpdater.spec.writeBackConfig.gitConfig.repository` at the same repo
6. ensure the app image workflow publishes branch-aware immutable tags such as:
   - `dev-<40-char-sha>`
   - `prod-<40-char-sha>`

The live working example is:

- config repo:
  `/home/danielmtz/Projects/kubernetes/quant-server-config`
- Argo repo secret:
  `/home/danielmtz/Projects/kubernetes/quant-server-config/argocd/externalsecret-repo-quant-server-config.yaml`
- Image Updater write-back secret:
  `/home/danielmtz/Projects/kubernetes/quant-server-config/argocd/externalsecret-quant-server-config-writeback.yaml`

The full operator walkthrough for creating a config repo in this style now lives in:

- `/home/danielmtz/Projects/kubernetes/quant-server-config/README.md`

Sources:

- [Argo CD Image Updater installation](https://argocd-image-updater.readthedocs.io/en/stable/install/installation/)
- [Argo CD Image Updater application configuration](https://argocd-image-updater.readthedocs.io/en/latest/configuration/applications/)
- [Argo CD Image Updater update methods](https://argocd-image-updater.readthedocs.io/en/latest/basics/update-methods/)
- [Argo CD Image Updater update strategies](https://argocd-image-updater.readthedocs.io/en/latest/basics/update-strategies/)
