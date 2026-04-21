# Website Rollout

This document defines the repeatable rollout path for the website applications.

Current model:

- production image tag stored in Git through `kubernetes/apps/danielmtz-website-prod-tls/kustomization.yaml`
- development image tag stored in Git through `kubernetes/apps/danielmtz-website-dev-tls/kustomization.yaml`
- production public path: HTTPS
- development private path: `http://k3s-server-1:30080`

The website repo already publishes immutable SHA-tagged images to GHCR. This repo should track those exact tags in Git.

## Current Rollout Scripts

Use:

```bash
sh scripts/set_website_image_tag.sh prod <image-sha-tag>
sh scripts/set_website_image_tag.sh dev <image-sha-tag>
sh scripts/website_rollout.sh apply prod [image-sha-tag]
sh scripts/website_rollout.sh apply dev [image-sha-tag]
sh scripts/website_rollout.sh status prod
sh scripts/website_rollout.sh status dev
```

### `set_website_image_tag.sh`

- updates the Git-tracked image tag in `kustomization.yaml`

### `apply`

- optionally updates the image tag first
- applies the selected prod or dev app path
- waits for the rollout to finish
- prints deployment, pod, service, ingress, and certificate status when present

### `status`

- shows the current app deployment state without changing anything

## Recommended Normal Flow

For the current website setup, the normal update path should be:

1. build and push the new SHA-tagged image from the website repo
2. update this repo to the exact prod or dev image tag
3. run the matching rollout:

```bash
sh scripts/website_rollout.sh apply prod <image-sha-tag>
sh scripts/website_rollout.sh apply dev <image-sha-tag>
```

4. verify:

```bash
curl -I https://danielmtzbarba.com
curl -I https://www.danielmtzbarba.com
curl http://k3s-server-1:30080
```

Expected result:

- apex returns `200`
- `www` returns a `308` redirect
- dev returns the private site without redirecting to the public domain

## Why This Fits Argo CD

With immutable tags:

- Git shows the exact deployed prod and dev versions
- Argo CD sees a manifest diff for each production rollout
- Image Updater can write back the dev image change to Git
- no forced restart is needed to pick up new image content

That is the correct GitOps shape for the split environment model.
