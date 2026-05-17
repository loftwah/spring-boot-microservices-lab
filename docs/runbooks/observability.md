# Observability Runbook

The lab observability stack should run in k3d, not Docker Compose.

## Stack

```text
Grafana      dashboards and querying
Prometheus   metrics storage and querying
Alertmanager alert routing
Loki         log storage and querying
Alloy        telemetry collection
```

Use one shared Grafana for the cluster. Do not create one Grafana per microservice.

## Namespaces

```bash
kubectl create namespace observability
kubectl create namespace enterprise-lab
```

## Helm Repos

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

## Install Shape

These values files will be added later:

```text
deploy/observability/values-kube-prometheus-stack.yaml
deploy/observability/values-loki.yaml
deploy/observability/values-alloy.yaml
```

Install commands:

```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --values deploy/observability/values-kube-prometheus-stack.yaml

helm upgrade --install loki grafana/loki \
  --namespace observability \
  --values deploy/observability/values-loki.yaml

helm upgrade --install alloy grafana/alloy \
  --namespace observability \
  --values deploy/observability/values-alloy.yaml
```

## Access Grafana

```bash
kubectl -n observability port-forward svc/monitoring-grafana 3000:80
```

Open:

```text
http://localhost:3000
```

## Microservice Requirements

Each Spring Boot service should expose:

```text
/actuator/health
/actuator/info
/actuator/prometheus
```

Dependencies:

```text
spring-boot-starter-actuator
micrometer-registry-prometheus
```

Config:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    health:
      probes:
        enabled: true
  metrics:
    tags:
      application: ${spring.application.name}
```

Each service should log to stdout. Structured JSON logs can come after the first working deployment.

## Prometheus Checks

Port-forward Prometheus:

```bash
kubectl -n observability port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Open:

```text
http://localhost:9090
```

Queries to try:

```promql
up
target_info
http_server_requests_seconds_count
process_uptime_seconds
```

## Loki Checks

In Grafana Explore, select Loki and query:

```logql
{namespace="enterprise-lab"}
```

For one service:

```logql
{namespace="enterprise-lab", app="linkarooie-api"}
```

## First Alerts

Useful alert ideas:

```text
ServiceDown
HighErrorRate
HighLatencyP95
KafkaConsumerLag
VaultRequestFailures
RustFSWriteFailures
PostgresConnectionFailures
```

## Dashboard Folders

```text
Platform
Kubernetes
Linkarooie API
Linkarooie Analytics Worker
Linkarooie Web
Linkarooie Media Worker
Kafka
Backing Services
```

## Things To Break And Fix

1. Deploy a service with a bad readiness probe and watch alerts.
2. Generate 500 errors and build an error-rate panel.
3. Log a correlation ID and find it in Loki.
4. Stop a service and confirm Prometheus target state changes.

## Know As A DevOps Engineer

- Metrics, logs, and traces answer different questions.
- Prometheus pulls metrics from targets.
- Loki indexes labels, not full log text.
- High-cardinality labels can hurt metrics and logs.
- Alerts should be actionable.
- Dashboards should show service health, saturation, errors, and latency.
