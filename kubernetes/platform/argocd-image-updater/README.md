# Argo CD Image Updater

This directory contains the install and configuration scaffolding for Argo CD Image Updater.

Current purpose:

- install Argo CD Image Updater in the `argocd` namespace
- configure automatic image detection for dev workloads
- keep production outside of image-driven auto-advance
- keep the updater on `k3s-server-1` with the rest of the Argo control plane

## Current Layout

- `image-updater-dev.yaml`
  Dev-only `ImageUpdater` resource for `danielmtz-website-dev`

Quant `ImageUpdater` resources are now owned by:

- `/home/danielmtz/Projects/kubernetes/quant-server-config/argocd/image-updaters`

## Current Model

- `prod`
  stays PR-driven and Git-approved

- `dev`
  auto-detects new images and writes the updated image tag back to Git

The dev updater only tracks branch-aware tags in the form:

- `dev-<40-char-sha>`

That keeps dev automation from selecting images built from other branches. The quant
services rely on this, because both `dev` and `prod` publish to the same GHCR image
repositories.

## Important Credential Boundary

The dev updaters need two kinds of access:

- read access to the private GHCR image
- write access to the owning Git repository for Git write-back

Those credentials should be configured explicitly and kept separate from production release approval.
