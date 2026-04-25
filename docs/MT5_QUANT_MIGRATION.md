# MT5 Quant Server Migration Design

This document defines the first migration design for moving the app currently deployed from `/home/danielmtz/Projects/algotrading/mt5-quant-server` into this k3s cluster.

The goal is not a 1:1 lift-and-shift of the current VM layout. The goal is to:

- centralize observability in the cluster
- move service lifecycle from SSH + Docker Compose to Argo CD + Kubernetes
- move app secrets from GitHub Actions runtime env injection to GCP Secret Manager + ESO
- reduce VM-specific networking and host assumptions
- keep the migration low-risk by moving the easier services first

## Current State

The current app is split across two GCP VMs and two separate Terraform stacks:

- control VM:
  - `core-service`
  - `messaging-service`
  - `caddy`
  - `prometheus`
  - `loki`
  - `promtail`
  - `node-exporter`
  - `grafana`
- execution VM:
  - `mt5-service`
  - `sync-service`
  - `influxdb-mt5`
  - `promtail`
  - `node-exporter`

The deployment path is:

- GitHub Actions runs `terraform apply`
- GitHub Actions SSHes into each VM
- Docker Compose is reconciled on the VM
- service configuration is injected through workflow env vars and generated env files

The relevant current sources are:

- control VM Terraform: `/home/danielmtz/Projects/algotrading/mt5-quant-server/infra/terraform/control-vm/main.tf`
- execution VM Terraform: `/home/danielmtz/Projects/algotrading/mt5-quant-server/infra/terraform/execution-vm/main.tf`
- control VM Compose: `/home/danielmtz/Projects/algotrading/mt5-quant-server/infra/docker/control-vm/docker-compose.yml`
- execution VM Compose: `/home/danielmtz/Projects/algotrading/mt5-quant-server/infra/docker/execution-vm/docker-compose.yml`
- control workflow: `/home/danielmtz/Projects/algotrading/mt5-quant-server/.github/workflows/ci-cd-control-vm.yml`
- execution workflow: `/home/danielmtz/Projects/algotrading/mt5-quant-server/.github/workflows/ci-cd-execution-vm.yml`

## Target State

The target architecture should be:

- this repo owns the cluster and platform services
- the app repo builds and pushes images
- this repo owns the Kubernetes manifests for the migrated app
- Argo CD reconciles the app into the cluster
- ESO delivers secrets from GCP Secret Manager
- cluster-wide Prometheus, Loki, Grafana, and Alertmanager replace the VM-local observability stack

GitHub Actions should move from:

- `terraform apply` for app VMs
- SSH-based Compose deploys

to:

- image build and push
- manifest PR creation or manifest update automation
- optional `terraform plan` for shared infra

## Service Classification

### Tier 1: straightforward Kubernetes services

These are the best first migration targets:

- `core-service`
- `messaging-service`

Why:

- standard Python container entrypoints
- explicit HTTP readiness endpoints
- no host networking
- no local durable data requirement
- simple service-to-service dependencies

Recommended Kubernetes resources:

- `Deployment`
- `Service`
- `ConfigMap` for non-secret settings
- `ExternalSecret` for secret env
- `Ingress` only if public or tailnet-private access is needed
- `ServiceMonitor` if explicit scraping is needed beyond default discovery

### Tier 2: moderate complexity

- `sync-service`

Why it is moderate:

- depends on both app services and execution-side components
- currently coupled to local InfluxDB and MT5 endpoints
- probably stateless, but its dependency graph is wider

Recommended Kubernetes resources:

- `Deployment`
- `Service`
- `ConfigMap`
- `ExternalSecret`
- possibly `NetworkPolicy` later if you want tighter east-west boundaries

### Tier 3: high-risk service

- `mt5-service`

Why it is high-risk:

- custom Wine/MT5 runtime
- currently uses host networking
- likely sensitive to runtime, display, filesystem, and timing assumptions
- may need persistent state and dedicated placement

Recommended eventual Kubernetes resources:

- start with a dedicated `Deployment`
- possibly move to `StatefulSet` if runtime state must survive rescheduling
- dedicated `PersistentVolumeClaim` if MT5 runtime state matters
- `nodeAffinity` or taints/tolerations if you later isolate MT5 workloads to a dedicated worker class

This service should be migrated last.

### Stateful supporting component

- `influxdb-mt5`

This is not the first migration target. First decide whether it should:

- remain as a required internal datastore
- be replaced by Prometheus + Loki + app metrics/log changes
- be migrated as a cluster `StatefulSet`

Do not move it just because it exists today.

## What Should Not Be Lifted As-Is

The current VM-local observability stack should not be recreated per app inside Kubernetes:

- `prometheus`
- `loki`
- `promtail`
- `grafana`
- `node-exporter`

These responsibilities already exist in this cluster and should stay platform-owned under `kubernetes/platform/`.

The app should instead:

- expose Prometheus metrics from services
- emit logs that can be scraped or collected into Loki
- use cluster Grafana dashboards
- use cluster Alertmanager routing

Likewise, these VM assumptions must be removed:

- fixed VM IPs
- `extra_hosts`
- `network_mode: host`
- SSH-based deployment as the normal runtime path
- app-specific GCP east-west firewall rules for service-to-service traffic

## Service Mapping

### `core-service`

Current assumptions:

- serves HTTP on container port `8001`
- readiness endpoint at `/ready`
- depends on:
  - PostgreSQL/Supabase
  - `messaging-service`
  - `mt5-service`

Current env shape:

- `CORE_DATABASE_URL`
- `CORE_ADMIN_TOKEN`
- `CORE_MT5_SERVICE_URL`
- `CORE_MESSAGING_SERVICE_URL`
- `CORE_MAX_POSITIONS`

Kubernetes target:

- `Deployment`
- `Service` exposing `8001`
- `ExternalSecret` for:
  - `CORE_DATABASE_URL`
  - `CORE_ADMIN_TOKEN`
- `ConfigMap` for:
  - `CORE_MT5_SERVICE_URL`
  - `CORE_MESSAGING_SERVICE_URL`
  - `CORE_MAX_POSITIONS`

### `messaging-service`

Current assumptions:

- serves HTTP on `8003`
- depends on `core-service`
- calls external WhatsApp and OpenAI APIs

Current env shape:

- `MSG_CORE_SERVICE_URL`
- `MSG_SYNC_SERVICE_URL`
- `MSG_MT5_SERVICE_URL`
- `MSG_WHATSAPP_API_TOKEN`
- `MSG_WHATSAPP_AUTH_TOKEN`
- `MSG_WHATSAPP_URL`
- `MSG_APP_URL`
- `MSG_OPENAI_API_KEY`

Kubernetes target:

- `Deployment`
- `Service` exposing `8003`
- `Ingress` only if webhook ingress is required
- `ExternalSecret` for:
  - WhatsApp tokens
  - OpenAI key
- `ConfigMap` for:
  - internal service URLs
  - `MSG_APP_URL` if that becomes environment-specific

### `sync-service`

Current assumptions:

- serves HTTP on `8080`
- talks to:
  - `mt5-service`
  - `core-service`
  - `messaging-service`
  - `influxdb-mt5`

Current env shape includes:

- `SYNC_MT5_SERVICE_URL`
- `SYNC_CORE_SERVICE_URL`
- `SYNC_CORE_ADMIN_TOKEN`
- `SYNC_BACKEND_URL`
- `SYNC_MESSAGING_SERVICE_URL`
- `SYNC_INFLUX_URL`
- `SYNC_INFLUX_TOKEN`
- `SYNC_INFLUX_ORG`
- `SYNC_INFLUX_BUCKET`
- trading/execution strategy controls

Kubernetes target:

- `Deployment`
- `Service` exposing `8080`
- `ExternalSecret` for:
  - `SYNC_CORE_ADMIN_TOKEN`
  - `SYNC_INFLUX_TOKEN`
- `ConfigMap` for:
  - internal service URLs
  - strategy tuning knobs
  - execution mode settings

### `mt5-service`

Current assumptions:

- serves on `8000`
- Wine-based runtime
- currently host-networked
- likely sensitive to restart timing and runtime bootstrap

Current env shape:

- `MT5_PATH`
- `MT5_LOGIN`
- `MT5_PASSWORD`
- `MT5_SERVER`
- `MT5_GMT_OFFSET`

Kubernetes target:

- isolated workload package
- `ExternalSecret` for credentials
- `ConfigMap` for non-secret runtime settings
- possible dedicated PVC
- possible node isolation policy

This should be treated as a dedicated migration project after the other services are already in-cluster.

## Secrets Design

The current app injects a large number of runtime values directly from GitHub Actions secrets. The cluster target should replace that with:

- GCP Secret Manager as source of truth
- ESO for delivery
- one Kubernetes namespace for the app
- `ExternalSecret` resources per service or per secret domain

Suggested secret grouping:

- `mt5-quant/core/*`
  - `database-url`
  - `admin-token`
- `mt5-quant/messaging/*`
  - `whatsapp-api-token`
  - `whatsapp-auth-token`
  - `openai-api-key`
- `mt5-quant/sync/*`
  - `core-admin-token`
  - `influx-token`
- `mt5-quant/mt5/*`
  - `login`
  - `password`
  - `server`
- `mt5-quant/influx/*`
  - bootstrap/admin values only if InfluxDB remains part of the design

Recommended namespace:

- `mt5-quant`

## Observability Design

The app currently ships its own Prometheus, Loki, Promtail, Grafana, and node exporters. After migration:

- platform Prometheus scrapes app metrics
- platform Loki receives app logs
- platform Grafana hosts app dashboards
- platform Alertmanager routes app alerts

Migration implications:

- preserve the useful app-level alert semantics from `/home/danielmtz/Projects/algotrading/mt5-quant-server/infra/prometheus/alert_rules.yml`
- rewrite those rules as cluster `PrometheusRule` resources
- attach alerts to the existing Slack path already running in this cluster

First alerts to preserve:

- `CoreDatabaseDisconnected`
- `SyncInfluxDisconnected`
- `SyncMT5ClientDisconnected`
- `MT5TerminalDisconnected`
- `MessagingMetaApiDisconnected`
- `ExecutionServiceDown`
- `MT5HeartbeatStale`

## CI/CD Transition

### Current model

- app repo builds images
- app repo runs `terraform apply`
- app repo SSH deploys to VMs

### Target model

- app repo builds images
- app repo publishes branch-aware tags to GHCR
- this repo holds the app manifests
- Argo CD syncs dev automatically
- prod follows the same Git-approved merge promotion model already used here

Recommended GitHub Actions transition:

1. keep build-and-push in the app repo
2. remove SSH deploy steps
3. remove app-VM Terraform apply steps
4. add manifest update automation into this repo
5. let Argo CD own rollout

## Migration Order

### Phase 1: app package design

Create a new workload package in this repo for:

- `core-service`
- `messaging-service`

Suggested path:

- `kubernetes/apps/mt5-quant-dev/`
- `kubernetes/apps/mt5-quant-prod/`

Keep Kustomize for this app because the services are still relatively simple and you explicitly want simple app workloads to remain on Kustomize.

### Phase 2: secrets and config

- define `ExternalSecret` resources for core and messaging
- define `ConfigMap` resources for service URLs and non-secret settings
- define `Deployment` + `Service` resources

### Phase 3: dev rollout

- deploy `core-service` and `messaging-service` to dev
- validate:
  - health endpoints
  - service discovery
  - metrics scraping
  - logs in Loki
  - Slack alerts

### Phase 4: sync integration

- migrate `sync-service`
- decide whether `influxdb-mt5` remains required
- if yes, add it as a separate stateful workload

### Phase 5: MT5 spike

- run a focused Kubernetes compatibility spike for `mt5-service`
- validate:
  - Wine startup
  - MT5 binary/runtime stability
  - persistent filesystem needs
  - network assumptions
  - restart behavior

### Phase 6: prod cutover

- promote the first three services to prod
- switch external/webhook routing if needed
- keep the old VMs as rollback until confidence is established

### Phase 7: decommission

- remove VM-local observability
- remove VM-local deploy workflows
- remove control/execution VM Terraform stacks

## First Implementation Slice

The first implementation slice should be:

1. create the `mt5-quant` namespace and app package skeleton in this repo
2. implement `core-service` and `messaging-service`
3. define `ExternalSecret` resources for their secret env
4. define `PrometheusRule` and dashboard additions for the migrated services
5. keep `sync-service`, `mt5-service`, and `influxdb-mt5` on the old VMs until the first slice is stable

This keeps the first cut small and removes the riskiest runtime from the initial migration.
