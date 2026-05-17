# Local k3d Deployment

This directory will hold Kubernetes manifests for running Linkarooie application workloads in k3d.

## Important Boundary

k3d runs:

- `linkarooie-api`
- `linkarooie-analytics-worker`
- `linkarooie-web`
- `linkarooie-media-worker` after it exists

Docker Compose continues to run:

- Postgres
- Redis
- Kafka
- RustFS
- Vault
- Jenkins

Application pods use `host.k3d.internal` to reach those supporting services.

## Expected Resources

```text
namespace.yaml
configmap.yaml
secret.example.yaml
api-deployment.yaml
api-service.yaml
analytics-worker-deployment.yaml
web-deployment.yaml
web-service.yaml
media-worker-deployment.yaml
ingress.yaml
```

## Verification

```bash
kubectl apply -f deploy/k8s/local
kubectl get pods -n linkarooie
curl -i http://localhost:8888/api/health
```

Run `./scripts/doctor.sh` before deploying if pods cannot reach supporting services.
