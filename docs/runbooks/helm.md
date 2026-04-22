# Helm Runbook

Helm is the package manager and templating tool for Kubernetes.

## What To Know

- A chart defines Kubernetes resources.
- A release is an installed instance of a chart.
- `values.yaml` configures a chart.
- Helm does not replace kubectl; it renders and manages manifests.

## Repos

```bash
helm repo list
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

## List Releases

```bash
helm list -A
helm list -n enterprise-lab
```

## Create A Service Chart

```bash
mkdir -p deploy/helm
helm create deploy/helm/document-service
```

Then remove templates you do not need and keep the chart small.

## Render Locally

```bash
helm template document-service deploy/helm/document-service \
  --namespace enterprise-lab \
  --values deploy/helm/document-service/values.yaml
```

## Install Or Upgrade

```bash
helm upgrade --install document-service deploy/helm/document-service \
  --namespace enterprise-lab \
  --create-namespace \
  --values deploy/helm/document-service/values.yaml
```

## Inspect A Release

```bash
helm status document-service -n enterprise-lab
helm get values document-service -n enterprise-lab
helm get manifest document-service -n enterprise-lab
helm history document-service -n enterprise-lab
```

## Rollback

```bash
helm rollback document-service 1 -n enterprise-lab
```

## Uninstall

```bash
helm uninstall document-service -n enterprise-lab
```

## What The Microservice Charts Should Include

```text
Deployment
Service
Ingress
ConfigMap
Secret
ServiceMonitor
PrometheusRule
readinessProbe
livenessProbe
```

## Things To Break And Fix

1. Render a chart with `helm template` and find a YAML error.
2. Install a release, change an image tag, upgrade it.
3. Break readiness in values, then roll back.
4. Use `helm diff` later to inspect changes before applying.

## Know As A DevOps Engineer

- Helm values are part of release configuration.
- Render locally before blaming Kubernetes.
- Rollbacks only work if previous revisions are retained.
- Secrets in Helm values can leak through release history; use care.
- Keep charts boring and predictable for app services.
