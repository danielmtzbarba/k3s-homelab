# Observability

This document defines the first observability stack for the cluster.

Current target:

- Prometheus
- Grafana
- Loki
- Alertmanager

This stack is intentionally platform-level and Helm-managed.

## Why Helm Here

Use Helm for this stack because these are third-party platform components with many configuration options.

That is the right fit for the current repository model:

- simple business apps stay on `kustomize`
- reusable or vendor platform software uses Helm
- Argo CD owns the actual reconciliation

## Current Repository Layout

Files for the observability stack live in:

- `kubernetes/platform/observability/`
  Helm values for Prometheus/Grafana and Loki

- `kubernetes/platform/argocd/applications/observability-kube-prometheus-stack.yaml`
- `kubernetes/platform/argocd/applications/observability-loki.yaml`
  Argo CD `Application` resources that reconcile the Helm charts

## Current Design

### Metrics

Prometheus and Grafana are installed with `kube-prometheus-stack`.

Current choices:

- `alertmanager` enabled with Slack routing via `AlertmanagerConfig`
- Grafana private inside the cluster
- Prometheus persistence enabled
- Grafana persistence enabled
- Grafana admin credentials sourced from an `ExternalSecret` instead of a chart-generated random secret
- `kube-etcd`, controller-manager, and scheduler scraping disabled because the first k3s target here is a practical working baseline, not full control-plane scraping perfection
- stateful and control-plane observability workloads pinned to `k3s-server-1`

Current placement policy:

- keep Grafana, Alertmanager, Prometheus, Loki, MinIO, kube-state-metrics, the Prometheus operator, and Loki gateway on `k3s-server-1`
- keep only per-node DaemonSets on every node:
  - Promtail
  - node exporter
  - Loki canary

This matters because the first persistence layer here is `local-path`, which uses node-local disk. Worker nodes are treated as more disposable than the server, so observability persistence belongs on the server.

### Logs

Loki is installed as a single-binary deployment.

Current choices:

- single replica
- persistence enabled
- in-cluster MinIO enabled for the first working install
- retention set to 7 days
- ClusterIP access only

This is a practical first step for the current cluster size.

Later, for a stronger production-grade target, move Loki storage to GCS and replace this in-cluster dependency.

## Node Exporter

Keep node exporter enabled.

Why:

- Prometheus alone does not give you host metrics
- `kube-state-metrics` gives object state, not node resource usage
- node exporter is the normal way to get CPU, memory, disk, filesystem, and network metrics from the nodes

It is not optional if you want meaningful node-level monitoring.

## Grafana And Loki Integration

Grafana is configured with a Loki datasource through the Prometheus stack values.

That means once Loki is healthy, Grafana can query logs without manual datasource setup.

## Grafana Dashboards

Custom Grafana dashboards should be provisioned from Git, not created only in the UI.

This repository now uses:

- `kubernetes/platform/observability/dashboards/`
  Kustomize-generated ConfigMaps labeled with `grafana_dashboard=1`

- `kubernetes/platform/argocd/applications/observability-dashboards.yaml`
  Argo CD application for the provisioned dashboards path

The first dashboard is:

- `K3s Cluster Overview`
  Focused on node health, resource pressure, pod scheduling, and restart signals for the server and worker nodes

Grafana also uses:

- `kubernetes/platform/observability/externalsecret-grafana-admin.yaml`
  ESO-managed stable admin credentials

This avoids password churn during Helm reconciliation and keeps login state stable across Grafana pod restarts when persistence is enabled.

Alerting uses:

- `kubernetes/platform/observability/prometheusrule-cluster-alerts.yaml`
  First cluster alert rules for node health, resource pressure, and restart failures

- `kubernetes/platform/observability/alertmanagerconfig-slack.yaml`
  Slack notification routing for Alertmanager

- `kubernetes/platform/observability/externalsecret-alertmanager-slack-webhook.yaml`
  ESO-managed Slack webhook secret for Alertmanager

The observability package also provisions `quant-engine` dashboards for the first migrated app slice:

- `Quant Engine System Overview`
- `Quant Engine Messaging Flow`

These dashboards use Prometheus for service metrics and Loki for log panels.

## Apply Path

After Argo CD is installed and repository credentials are configured, apply:

```bash
kubectl apply -f kubernetes/platform/argocd/applications/observability-loki.yaml
kubectl apply -f kubernetes/platform/argocd/applications/observability-kube-prometheus-stack.yaml
```

Verify:

```bash
kubectl get applications -n argocd
kubectl get pods -n observability
kubectl get pvc -n observability
```

Expect the stateful PVC-backed workloads to land on `k3s-server-1`.

## Log Collection

This repository now uses Promtail as the first log collector.

Promtail runs as a DaemonSet and tails node-local pod logs on each node, then forwards them to Loki.

That means:

- Loki stores and serves logs
- Promtail performs node-local collection
- Grafana can query Loki once both are healthy

Promtail remains a per-node DaemonSet by design and should not be pinned to the server only, because doing so would stop worker-node log collection.
