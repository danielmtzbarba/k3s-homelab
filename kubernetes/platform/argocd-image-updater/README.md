# Argo CD Image Updater

This directory contains the install and configuration scaffolding for Argo CD Image Updater.

Current purpose:

- install Argo CD Image Updater in the `argocd` namespace
- configure automatic image detection for the dev website app
- keep production outside of image-driven auto-advance

## Current Layout

- `image-updater-dev.yaml`
  Dev-only `ImageUpdater` resource for `danielmtz-website-dev`

## Current Model

- `prod`
  stays PR-driven and Git-approved

- `dev`
  auto-detects new images and writes the updated image tag back to Git

## Important Credential Boundary

The dev updater needs two kinds of access:

- read access to the private GHCR image
- write access to the `k3s-homelab` repository for Git write-back

Those credentials should be configured explicitly and kept separate from production release approval.
