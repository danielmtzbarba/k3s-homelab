# Argo CD Environment Roadmap

This document defines the next GitOps step for the website deployment:

- one production workflow
- one development workflow
- separate Argo CD applications for each environment

## Goal

Split the current single website deployment model into:

- `prod`
  explicit deploy intent through PRs into `k3s-homelab`

- `dev`
  faster automatic updates based on new published images

That gives you:

- review and control for production
- faster iteration for development
- a clean environment boundary inside Argo CD

## Target Model

### Production

Production should remain the stricter path.

Flow:

1. website repo pushes a new production image
2. website repo workflow opens a PR against `k3s-homelab`
3. that PR updates the production app image tag in Git
4. merge to `main` becomes the deployment approval
5. Argo CD reconciles the production application from Git

This keeps production:

- reviewable
- auditable
- rollback-friendly
- aligned with GitOps

### Development

Development should be the faster path.

Flow:

1. website repo pushes a new development image
2. Argo CD detects the new dev image
3. Argo CD updates the development app target
4. the development app syncs automatically

This is the right place for image-driven automation because:

- speed matters more than strict approval
- the environment is for iteration
- you do not want production and development sharing the same release friction

## Recommended Tooling Split

### Production

Use the current PR-based model.

Keep:

- deploy repo update by PR
- Argo CD watching the deploy repo
- Git as the deployment approval boundary

### Development

Use Argo CD Image Updater.

Why:

- it is designed to watch registries
- it can update applications automatically when a new image appears
- it fits the “auto-advance dev” workflow better than PR churn

This is the cleanest split for your stated goal:

- `prod` = Git PR based promotion
- `dev` = registry-driven automatic advancement

## Required App Split

You need two separate website apps in this repo.

Recommended shape:

- `kubernetes/apps/danielmtz-website-prod-tls/`
- `kubernetes/apps/danielmtz-website-dev-tls/`

The current app should become the production app.

The dev app should be a copy with these changes:

- namespace:
  `danielmtz-website-dev`

- private access path:
  `http://k3s-server-1:30080` over Tailscale MagicDNS

- image policy:
  image updater annotations for the dev app

## Required Argo CD Split

You also need two separate Argo CD `Application` resources.

Recommended shape:

- `kubernetes/platform/argocd/applications/danielmtz-website-prod.yaml`
- `kubernetes/platform/argocd/applications/danielmtz-website-dev.yaml`

### Production Application

Should:

- point to the prod app path
- target namespace `danielmtz-website-prod`
- follow `main`
- auto-sync after a Git-approved merge to `main`

### Development Application

Should:

- point to the dev app path
- allow automatic sync
- be the app Argo CD Image Updater manages

## Branch And Workflow Model

Recommended website repo model:

- `prod` branch:
  builds production images and opens deployment PRs to `k3s-homelab`

- `dev` branch:
  builds development images for automatic dev deployment

This gives you a clean operational split:

- `prod` branch drives deploy intent by Git PR
- `dev` branch drives rapid development images

## Image Tag Strategy

Keep immutable image tags for both environments.

Examples:

- production:
  `ghcr.io/danielmtzbarba/danielmtz-website:prod-<40-char-sha>`

- development:
  `ghcr.io/danielmtzbarba/danielmtz-website:dev-<40-char-sha>`

The environment prefix is important here because it gives Image Updater a safe way to filter dev images without accidentally selecting a prod build. The underlying deployment references should still be immutable.

## Production Roadmap

1. Duplicate the current website app as the production app.
2. Create a production Argo CD `Application`.
3. Keep the website repo `prod` workflow opening PRs against `k3s-homelab`.
4. Merge those PRs into `main`.
5. Let Argo CD reconcile production from Git.

## Development Roadmap

1. Duplicate the website app into a dev app path.
2. Change namespace and make the dev copy private over the server MagicDNS name and a dedicated NodePort.
3. Create a development Argo CD `Application`.
4. Install and configure Argo CD Image Updater.
5. Give Image Updater access to:
   - the private GHCR repository
   - the Argo CD application it needs to update
6. Configure Image Updater to only accept `dev-<40-char-sha>` tags.
7. Enable automatic sync for the dev app only.
8. Verify that a new image push from the website `dev` branch advances the dev environment automatically.

## Operational Boundary

This split intentionally treats the environments differently.

Production is:

- slower
- reviewed
- Git-approved
- automatically reconciled after merge

Development is:

- faster
- auto-advanced
- easier to iterate

That asymmetry is a feature, not a flaw.

## Suggested Execution Order

1. Keep the current production app as the baseline.
2. Duplicate it into explicit prod and dev app paths.
3. Create separate Argo CD applications for prod and dev.
4. Keep prod on the current PR-based model.
5. Add Argo CD Image Updater for dev.
6. Verify private dev access through the tailnet.
7. Only after dev is proven, consider enabling more automation on prod.

## What Not To Do

Do not:

- make production auto-follow new images from the registry
- let prod and dev share one namespace
- expose dev publicly by default
- mix dev image updater behavior into the production app
- let dev and prod share the same undifferentiated image tag format

Keep the separation explicit.
