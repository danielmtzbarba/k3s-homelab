# Promtail

This package deploys a pragmatic first Kubernetes log collector for the cluster.

It tails pod log files from the nodes and forwards them to the existing Loki gateway in the `observability` namespace.

This is intentionally a practical first step so Loki becomes useful for debugging migrated workloads now.

Longer term, this collector can be replaced with Grafana Alloy if you want a more consolidated Grafana-native telemetry pipeline.
