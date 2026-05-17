# k3d Runbook

k3d runs k3s clusters inside Docker. This lab uses it as the local Kubernetes runtime.

The cluster is for application workloads and Kubernetes-native observability. Jenkins remains outside the cluster in Docker Compose to model centralized CI/CD.

## Current Cluster

The cluster was created with:

```bash
k3d cluster create enterprise-lab \
  --servers 1 \
  --agents 2 \
  --port "8888:80@loadbalancer" \
  --api-port 6550 \
  --wait
```

## Basic Commands

```bash
k3d cluster list
k3d node list
kubectx k3d-enterprise-lab
kubectl get nodes
```

## Stop And Start Cluster

```bash
k3d cluster stop enterprise-lab
k3d cluster start enterprise-lab
```

## Delete Cluster

This removes the cluster:

```bash
k3d cluster delete enterprise-lab
```

## Import Local Images

If Jenkins or your shell builds an image locally:

```bash
docker build -t linkarooie-api:local -f services/linkarooie-api/Dockerfile .
k3d image import linkarooie-api:local -c enterprise-lab
```

Then use this image in Kubernetes:

```yaml
image:
  repository: linkarooie-api
  tag: local
  pullPolicy: IfNotPresent
```

## Ingress

Your cluster maps load balancer port `80` to host port `8888`:

```text
http://localhost:8888
```

Planned app routes:

```text
http://localhost:8888/
http://localhost:8888/api/health
http://localhost:8888/directory
```

## Reach Host Services From Pods

Use:

```text
host.k3d.internal
```

Example:

```bash
kubectl run netshoot \
  --rm -it \
  --restart=Never \
  --image=nicolaka/netshoot \
  -- nc -vz host.k3d.internal 5432
```

## Things To Break And Fix

1. Stop the cluster and watch kubectl fail.
2. Import an image, deploy it, then change the tag and redeploy.
3. Create a bad ingress path and inspect Traefik behavior.
4. Delete a pod and watch Kubernetes recreate it.

## Know As A DevOps Engineer

- k3d is not production Kubernetes, but it is useful for local workflow.
- k3s includes Traefik by default.
- Local image handling is different from registry-based deployment.
- Load balancer port mappings are defined at cluster creation time.
- k3d clusters are disposable; manifests and Helm charts should recreate the desired state.
