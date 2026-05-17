# Story 9: Containers And k3d

## Goal

Build container images for the API, analytics worker, media worker, and web service, then deploy only those application workloads into k3d while supporting services stay in Docker Compose.

## Why

This is the platform loop: locally built services become portable images, and Kubernetes runs the application without owning the backing services.

## Where It Goes

```text
services/linkarooie-api/Dockerfile
services/linkarooie-analytics-worker/Dockerfile
services/linkarooie-web/Dockerfile
services/linkarooie-media-worker/Dockerfile
deploy/k8s/local/
```

## Build Steps

1. Add Dockerfile for `linkarooie-api`.
2. Add Dockerfile for `linkarooie-analytics-worker`.
3. Add Dockerfile for `linkarooie-web`.
4. Add Dockerfile for `linkarooie-media-worker`.
5. Add Kubernetes namespace manifest.
6. Add ConfigMap with non-secret local k3d values using `host.k3d.internal`.
7. Add Secret manifest or secret creation script for database, S3, and session secrets.
8. Add Deployments and Services for API and web.
9. Add Deployment for analytics worker.
10. Add Deployment for media worker after story 10 exists, or keep it disabled until then.
11. Add Ingress so browser traffic reaches the web service and `/api`.
12. Build images locally, load them into k3d, and apply manifests.

## Verification

Check pod-to-host connectivity first:

```bash
./scripts/doctor.sh
```

Build and load images:

```bash
docker build -t linkarooie-api:local -f services/linkarooie-api/Dockerfile .
docker build -t linkarooie-analytics-worker:local -f services/linkarooie-analytics-worker/Dockerfile .
docker build -t linkarooie-web:local services/linkarooie-web
k3d image import linkarooie-api:local linkarooie-analytics-worker:local linkarooie-web:local -c enterprise-lab
```

Deploy:

```bash
kubectl apply -f deploy/k8s/local
kubectl get pods -n linkarooie
curl -i http://localhost:8888/api/health
```

## Tangible Result

- k3d runs Linkarooie application pods.
- Pods reach Postgres, Redis, Kafka, and RustFS through host bridge addresses.
- Browser traffic reaches the web service and API through one local entry point.

## Test Coverage

- Container smoke tests for each image.
- Kubernetes readiness probe checks.
- Black-box HTTP tests against the k3d ingress.
- Kafka event smoke from API pod to analytics worker pod.
