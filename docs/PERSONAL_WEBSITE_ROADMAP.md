# Personal Website Roadmap

This roadmap now assumes the website is already containerized and split into two cluster targets:

- production:
  `kubernetes/apps/danielmtz-website-prod-tls/`
- development:
  `kubernetes/apps/danielmtz-website-dev-tls/`

The current model is:

- production is public, behind Traefik, with TLS
- development is private on the tailnet through a dedicated NodePort
- both environments use immutable GHCR image tags
- Argo CD owns the desired-state path

## Current Baseline

The repository already contains:

- a public production website app
- a private development website app
- Argo CD application manifests for both
- Argo CD Image Updater scaffolding for dev
- a production PR-based deployment path from the website repo

## Environment Model

### Production

Production lives under:

- `kubernetes/apps/danielmtz-website-prod-tls/`

It should remain:

- public
- TLS-enabled
- review-driven
- reconciled from Git

The intended production flow is:

1. the website `prod` branch publishes a SHA-tagged image
2. the website repo opens a PR against `k3s-homelab`
3. that PR updates the prod app image tag in Git
4. merge to `main` becomes the deploy approval
5. Argo CD syncs production from Git

### Development

Development lives under:

- `kubernetes/apps/danielmtz-website-dev-tls/`

It should remain:

- private
- reachable only on the tailnet
- fast-moving
- automatically advanced from new dev images

The intended development flow is:

1. the website `dev` branch publishes a SHA-tagged image
2. Argo CD Image Updater detects the new image
3. it writes the new dev tag back into this repo
4. Argo CD auto-syncs the dev app

## What Still Needs To Be Proven

The remaining roadmap items are operational, not structural:

1. clean out the old legacy website resources from the cluster
2. prove the private dev build never redirects to the public domain
3. complete the Argo CD handoff for prod and dev
4. validate one full automatic dev image update
5. validate one full PR-based production rollout

## Recommended Validation Order

1. deploy the renamed prod app into `danielmtz-website-prod`
2. delete the old single-app production resources from `danielmtz-website`
3. delete the old dev resources named `danielmtz-website` from `danielmtz-website-dev`
4. verify private dev access on `http://k3s-server-1:30080`
5. apply the Argo CD prod and dev applications
6. validate Argo CD Image Updater for dev
7. validate the website repo PR workflow for prod

## Longer-Term Follow-Up

After the environment split is stable, the next worthwhile improvements are:

- tighten the dev access path if you want something cleaner than a raw NodePort
- move more cluster apps under Argo CD ownership
- add observability for app rollout failures and certificate issues
- formalize promotion from dev to prod around immutable image tags
