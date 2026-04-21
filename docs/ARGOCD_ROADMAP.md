# Argo CD Roadmap

This document defines the next GitOps layer for the cluster without mixing it into VM bootstrap or Terraform.

For the upcoming prod/dev split, see:

- [Argo CD Environment Roadmap](ARGOCD_ENVIRONMENTS.md)

## Goal

Move from manual reconciliation:

- `kubectl apply -k ...`
- rollout helper scripts
- operator-driven restarts for mutable tags

to a GitOps model where:

- Git is the source of truth for desired cluster state
- Argo CD reconciles platform and app manifests
- application ownership moves from ad hoc `kubectl` usage into Kubernetes-native application definitions

## Current Starting Point

The repository already has the correct separation to begin this transition:

- `infra/terraform/`
  Infrastructure only.

- `scripts/`
  Operator helpers and node bootstrap only.

- `kubernetes/platform/`
  Cluster add-ons and shared platform resources.

- `kubernetes/apps/`
  Application workloads.

That boundary should remain intact. Argo CD belongs in `kubernetes/platform/`, not in node setup scripts.

## Target Structure

The intended Argo CD layout is:

- `kubernetes/platform/argocd/`
  Namespace and Argo CD-specific repo scaffolding.

- `kubernetes/platform/argocd/applications/`
  Argo CD `Application` resources for platform components and workloads.

## Step 1. Install Argo CD

Install Argo CD into:

- namespace: `argocd`

Keep installation separate from `k3s_server_setup.sh`.

That means:

- no Argo CD installation in VM bootstrap
- no Argo CD installation in Terraform
- no Argo CD installation hidden inside `infra.sh`

The current repository install path uses Helm:

```bash
sh scripts/infra.sh deploy-argocd
```

That command installs Argo CD into the cluster but intentionally stops short of exposing it publicly or applying applications automatically.

## Step 2. Expose Argo CD Safely

Bring up access in two phases:

1. Use port-forward first.
2. Later expose it with ingress and TLS on a dedicated host such as `argocd.k3s.danielmtzbarba.com`.

Do not make Argo CD exposure part of the first install step.

## Step 3. Start With One Application

The first workloads Argo CD should own are:

- `danielmtz-website-prod`
- `danielmtz-website-dev`

Why:

- it already has a single canonical path
- it already uses `kustomize`
- it already exercises ingress, TLS, DNS, and rollout behavior

The initial sync policy should be manual.

That lets you learn:

- app discovery
- sync flow
- drift reporting
- health reporting

before enabling automatic reconciliation.

Because this repository is private, Argo CD will also need repository credentials before that first `Application` can sync successfully.

That can be done later with either:

- an SSH deploy key
- a GitHub token-based repository credential

## Step 4. Transfer Ownership Cleanly

Once Argo CD is installed and the website applications are visible:

- stop using `kubectl apply -k` as the normal path for production
- use Argo CD to sync the production application instead

At that point, the rollout script becomes transitional tooling rather than the long-term deployment path.

## Step 5. Fix Image Update Strategy

This is the main design choice you should make before relying heavily on GitOps.

### Current Direction

Use immutable image references, such as:

- commit SHA tags

Then the workflow becomes:

1. build and push image with immutable tag
2. update the manifest tag in Git
3. Argo CD sees the Git diff
4. Argo CD syncs the new revision

That is the intended deployment model for the website app.

## Step 6. Move Platform Components Gradually

After the website is stable under Argo CD ownership, move platform resources in small steps:

1. issuer resources
2. cert-manager
3. later observability components

Do not move everything at once.

## Step 7. Enable Automation

Only after the manual sync flow is understood and trusted:

- enable automated sync
- enable self-heal
- enable prune

That turns Argo CD into the normal reconciliation mechanism instead of a dashboard for manual sync clicks.

## Recommended Execution Order

1. Install Argo CD in the `argocd` namespace.
2. Access it with port-forward first.
3. Apply the prod and dev website `Application` resources.
4. Keep sync manual first for prod.
5. Verify Argo CD can own and reconcile both applications.
6. Update the production image tag in Git for each rollout.
7. Bring platform resources under Argo CD incrementally.
8. Turn on automated sync after the flow is trusted.

## What This Repository Now Provides

The repo now includes:

- an Argo CD platform directory
- application scaffolding for `danielmtz-website-prod` and `danielmtz-website-dev`
- documentation for the migration path

It does not yet include:

- an ingress for Argo CD
- automated Argo CD bootstrap
- repository credentials for the private GitHub repository

Those should be added only when you are ready to choose the actual install method.
