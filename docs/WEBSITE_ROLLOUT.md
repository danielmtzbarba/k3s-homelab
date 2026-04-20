# Website Rollout

This document defines the repeatable rollout path for `danielmtz-website`.

Current model:

- image tag: `stable`
- deployment source: `kubernetes/apps/danielmtz-website-tls/`
- normal public path: HTTPS

Because `stable` is a mutable tag, the rollout process must force new pods to start so Kubernetes pulls the current image again.

## Why A Script Exists

With a mutable tag like `stable`, this is not enough:

```bash
kubectl apply -k kubernetes/apps/danielmtz-website-tls
```

That updates resources, but it does not guarantee existing running pods will be replaced.

The correct rollout path is:

1. apply manifests
2. force a rollout restart
3. wait for rollout status
4. verify pods, ingress, and certificate state

## Current Rollout Script

Use:

```bash
sh scripts/website_rollout.sh apply
sh scripts/website_rollout.sh status
```

### `apply`

- applies `kubernetes/apps/danielmtz-website-tls`
- forces a deployment restart
- waits for the rollout to finish
- prints deployment, pod, ingress, and certificate status

### `status`

- shows the current app deployment state without changing anything

## Recommended Normal Flow

For the current website setup, the normal update path should be:

1. build and push the new `stable` image from the website repo
2. run:

```bash
sh scripts/website_rollout.sh apply
```

3. verify:

```bash
curl -I https://danielmtzbarba.com
curl -I https://www.danielmtzbarba.com
```

Expected result:

- apex returns `200`
- `www` returns a `308` redirect

## Why Not Argo CD Yet

Argo CD is a good next step, but it solves a different maturity level:

- Git-driven reconciliation
- automatic drift correction
- declarative app sync
- cluster app inventory and health in one place

That is stronger than a shell rollout script, but it also adds:

- another platform component
- application definitions
- GitOps repo conventions
- sync policy decisions

For your current cluster, the right order is:

1. clean app manifests
2. clean rollout process
3. stable image build/push flow
4. then GitOps if you want continuous reconciliation

## When To Move To Argo CD

It becomes worth it when:

- you have more than one or two real apps
- you want declarative cluster reconciliation
- you want app state visible in the cluster itself
- you want to stop running imperative `kubectl apply` as the main deployment method

So yes, Argo CD is the right long-term direction.

But the correct immediate step is this:

- keep the current app layout
- use the rollout script for repeatable updates
- move to Argo CD after the application structure settles
