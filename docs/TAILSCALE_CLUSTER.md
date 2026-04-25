# Tailscale On The Cluster

This document describes the implemented Tailscale path for this cluster and the boundary it should keep.

## Goal

Use Tailscale for:

- SSH access to the k3s server
- Kubernetes API access from your local machine
- operator access when your public IP changes

Do not use Tailscale for:

- public website traffic
- Traefik ingress for public domains
- Let's Encrypt HTTP validation

Public web traffic should continue to enter through the normal public ingress path.

## Correct Architecture Boundary

Treat Tailscale as an admin-access layer.

That means:

1. infrastructure still creates the VM and networking
2. k3s bootstrap still installs and configures k3s
3. Tailscale is added as a node access component
4. kubeconfig is updated to use the Tailscale address

Do not install cluster add-ons or application workloads through Tailscale logic.

## Environment Variables

The current implementation uses these `.env` variables:

```bash
TAILSCALE_ENABLE="true"
TAILSCALE_AUTH_KEY="tskey-auth-..."
TAILSCALE_HOSTNAME="k3s-server-1"
TAILSCALE_ACCEPT_DNS="false"
KUBECONFIG_ENDPOINT_MODE="tailscale"
```

Meaning:

- `TAILSCALE_ENABLE`
  turns on Tailscale installation during server bootstrap

- `TAILSCALE_AUTH_KEY`
  auth key used for non-interactive join to the tailnet

- `TAILSCALE_HOSTNAME`
  hostname used when the server joins the tailnet

- `TAILSCALE_ACCEPT_DNS`
  whether the server should accept Tailscale-managed DNS settings

- `KUBECONFIG_ENDPOINT_MODE`
  determines whether kubeconfig points to:
  - `public`
  - `tailscale`

- `K8S_SERVICE_ACCOUNT_ISSUER_ENABLE`
  when `true`, also configures a Kubernetes service-account issuer URL for Workload Identity Federation

- `K8S_SERVICE_ACCOUNT_ISSUER_URL`
  the stable HTTPS issuer URL embedded in projected service account tokens

- `K8S_SERVICE_ACCOUNT_JWKS_URI`
  optional explicit JWKS URL advertised by the Kubernetes API server for issuer discovery

## Implemented Flow

### 1. Enable Tailscale In `.env`

Update `.env`:

```bash
TAILSCALE_ENABLE="true"
TAILSCALE_AUTH_KEY="tskey-auth-..."
TAILSCALE_HOSTNAME="k3s-server-1"
TAILSCALE_ACCEPT_DNS="false"
KUBECONFIG_ENDPOINT_MODE="tailscale"
```

### 2. Re-run Server Setup

Run:

```bash
sh scripts/infra.sh server-setup
```

This now:

- installs Tailscale on the server
- joins the tailnet using the auth key
- gets the server Tailscale IPv4 address
- adds that Tailscale IP as a `tls-san` for k3s
- restarts k3s

### 3. Re-fetch Kubeconfig

Run:

```bash
sh scripts/infra.sh kubeconfig
```

With `KUBECONFIG_ENDPOINT_MODE="tailscale"`, the kubeconfig fetch now rewrites the API endpoint to the server Tailscale IP instead of the public IP.

### 4. Verify Access

From your local machine:

```bash
tailscale status
kubectl get nodes -o wide
kubectl cluster-info
```

You can also verify the server side:

```bash
gcloud compute ssh "$SERVER_NAME" --zone="$ZONE" --command="tailscale status && tailscale ip -4"
```

## Recommended Rollout Order

### Step 1. Add Tailscale To The Server

Start with the server only.

That gives you:

- stable SSH access
- stable Kubernetes API access
- less dependence on `SSH_SOURCE_RANGE`

Do not start with the worker. The server is the important first admin entrypoint.

### Step 2. Join The Server To Your Tailnet

This is now handled by `scripts/k3s_server_setup.sh` when `TAILSCALE_ENABLE="true"` and `TAILSCALE_AUTH_KEY` is present.

### Step 3. Test SSH Over Tailscale

From your local machine:

```bash
ssh <tailscale-user>@<server-tailscale-ip>
```

or with MagicDNS if enabled:

```bash
ssh <server-tailscale-name>
```

Do not change kubeconfig until this works.

### Step 4. Move Kubeconfig To Tailscale

This is now handled by `scripts/fetch_kubeconfig.sh` when:

```bash
KUBECONFIG_ENDPOINT_MODE="tailscale"
```

After that, `kubectl` no longer depends on your public location.

### Step 5. Reduce Public Admin Exposure

After Tailscale access is proven:

- reduce or remove public SSH access
- consider reducing public access to `6443`

Do this only after Tailscale-based SSH and kubeconfig access are working reliably.

## Repo State

The repo now includes:

- `.env` inputs for Tailscale
- `scripts/k3s_server_setup.sh` support for Tailscale install and join
- `scripts/fetch_kubeconfig.sh` support for Tailscale kubeconfig endpoints

The next refinement later would be:

- optional worker-side Tailscale
- reducing public admin exposure after Tailscale access is proven

## Recommended Final Access Model

- public ingress:
  - `danielmtzbarba.com`
  - Traefik
  - Let's Encrypt

- private admin access:
  - SSH over Tailscale
  - `kubectl` over Tailscale

That split is the clean pattern for this cluster.
