# Argo CD

This document installs Argo CD as a cluster platform component using Helm.

Argo CD belongs at the Kubernetes layer:

- not in Terraform
- not in VM bootstrap
- not in `k3s_server_setup.sh`

## What The Install Does

The current repo install path:

- creates the `argocd` namespace
- installs Argo CD with the upstream Helm chart
- installs the Argo CD CRDs through the chart
- keeps the Argo CD server as `ClusterIP`
- expects first access through `kubectl port-forward`

It intentionally does not:

- expose Argo CD publicly yet
- configure ingress or TLS for Argo CD
- apply Argo CD `Application` resources automatically
- configure credentials for the private GitHub repository

Those are separate steps and should stay explicit.

## Install Command

Use the repo wrapper:

```bash
sh scripts/infra.sh deploy-argocd
```

Direct equivalent:

```bash
sh scripts/deploy_argocd.sh
```

## What The Script Runs

At a high level it:

1. verifies `helm`, `kubectl`, and the local kubeconfig
2. applies `kubernetes/platform/argocd/namespace.yaml`
3. adds or updates the upstream Argo Helm repository
4. runs `helm upgrade --install` for `argo/argo-cd`
5. waits for Argo CD pods to become ready

The configuration lives in:

- `kubernetes/platform/argocd/values.yaml`

## Access Argo CD

Start with port-forward:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

Then open:

- [http://localhost:8080](http://localhost:8080)

Get the initial admin password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d && echo
```

After the first login and password change, remove the bootstrap secret:

```bash
kubectl delete secret argocd-initial-admin-secret -n argocd
```

That secret is only for the first login. Remove it after the password change so the one-time bootstrap credential is not left behind in the cluster.

## First Recommended Use

Do not enable automated sync first.

Start with:

- manual sync
- one app
- repo credentials configured first

The current Argo CD app manifests in this repository are:

- `kubernetes/platform/argocd/applications/danielmtz-website-prod.yaml`
- `kubernetes/platform/argocd/applications/danielmtz-website-dev.yaml`

## Private Repository Requirement

This repository is private.

That means Argo CD will need repository credentials before the website `Application` can sync.

Typical options:

- GitHub token-based repository credential
- SSH deploy key

This repository currently uses the SSH deploy key path.

## Configure Repository Credentials

All commands in this section run on your local machine.

### 1. Create A Dedicated Deploy Key

```bash
ssh-keygen -t ed25519 -C "argocd-k3s-homelab" -f ~/.ssh/argocd_k3s_homelab -N ""
```

### 2. Add The Public Key To GitHub

Using GitHub CLI:

```bash
gh repo deploy-key add ~/.ssh/argocd_k3s_homelab.pub \
  --repo danielmtzbarba/k3s-homelab \
  --title "argocd-k3s-homelab"
```

Useful follow-up commands:

```bash
gh repo deploy-key list --repo danielmtzbarba/k3s-homelab
```

### 3. Create The Argo CD Repository Secret

```bash
kubectl create secret generic repo-k3s-homelab \
  -n argocd \
  --from-literal=type=git \
  --from-literal=url=git@github.com:danielmtzbarba/k3s-homelab.git \
  --from-file=sshPrivateKey=$HOME/.ssh/argocd_k3s_homelab
```

Label it so Argo CD treats it as a repository credential:

```bash
kubectl label secret repo-k3s-homelab -n argocd argocd.argoproj.io/secret-type=repository
```

Verify:

```bash
kubectl get secret repo-k3s-homelab -n argocd
```

You do not delete this secret after setup. Argo CD needs it to keep reading the private repository.

## Apply The First Application

Apply the Argo CD `Application` resources:

```bash
kubectl apply -f kubernetes/platform/argocd/applications/danielmtz-website-prod.yaml
kubectl apply -f kubernetes/platform/argocd/applications/danielmtz-website-dev.yaml
```

Verify:

```bash
kubectl get applications -n argocd
```

## First Sync

For production, keep sync manual first. Development can use automatic sync once the Image Updater path is in place.

Use the UI through the existing port-forward:

- [http://localhost:8080](http://localhost:8080)

Then:

1. open `danielmtz-website-prod`
2. inspect health and diff
3. sync manually

You do not need the `argocd` CLI on your local machine for this first step. The UI is enough.

## Verification

```bash
kubectl get pods -n argocd -o wide
kubectl get crds | grep argoproj.io
kubectl get svc -n argocd
```

## Next Step

After Argo CD is installed and reachable:

1. configure repository credentials
2. apply the prod and dev `Application` resources
3. use manual sync first for prod
4. update the website image tag in Git for each prod rollout

For the planned production/development split, see:

- [Argo CD Environment Roadmap](ARGOCD_ENVIRONMENTS.md)
