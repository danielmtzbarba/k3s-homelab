# Observability

This directory contains the Helm values and GitOps scaffolding for the observability stack.

Current scope:

- Prometheus and Grafana via `kube-prometheus-stack`
- Loki via the Loki Helm chart

Current design choices:

- keep the stack private inside the cluster
- use Helm for third-party platform software
- let Argo CD reconcile the chart releases from Git
- keep the first logging path small and understandable

## Components

- `kube-prometheus-stack-values.yaml`
  Values for Prometheus, Grafana, kube-state-metrics, and node exporter.

- `loki-values.yaml`
  Values for a small single-binary Loki install.

- `dashboards/`
  Provisioned Grafana dashboards that are loaded through the Grafana dashboard sidecar.

## Node Exporter

Keep node exporter enabled.

Reason:

- Prometheus needs host-level metrics such as CPU, memory, disk, filesystem, and network usage
- kube-state-metrics only exposes Kubernetes object state, not host health
- on a small k3s cluster, node exporter is a low-cost DaemonSet and is worth running

It is not strictly required to make Prometheus work, but it is required for useful node-level observability.

## Current Loki Mode

This repository starts Loki in single-binary mode for a small self-managed cluster.

That is the right first step here:

- simpler to operate
- enough for a small lab and meta-monitoring stack
- easier to debug than a distributed Loki install

For a later production-grade version, move Loki to object storage you trust operationally, such as GCS, instead of an in-cluster dependency.
