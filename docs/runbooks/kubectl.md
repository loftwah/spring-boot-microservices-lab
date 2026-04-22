# kubectl Runbook

kubectl is the main CLI for interacting with Kubernetes.

## Current Context

```bash
kubectl config current-context
kubectx
kubectx k3d-enterprise-lab
```

## Namespaces

```bash
kubectl get namespaces
kubectl create namespace enterprise-lab
kubectl create namespace observability
kubectl config set-context --current --namespace=enterprise-lab
```

## Core Inspection

```bash
kubectl get nodes
kubectl get pods -A
kubectl get pods -n enterprise-lab
kubectl get deployments -n enterprise-lab
kubectl get services -n enterprise-lab
kubectl get ingress -A
kubectl get events -n enterprise-lab --sort-by=.lastTimestamp
```

## Describe Resources

```bash
kubectl describe pod POD_NAME -n enterprise-lab
kubectl describe deployment document-service -n enterprise-lab
kubectl describe ingress -n enterprise-lab
```

## Logs

```bash
kubectl logs deployment/document-service -n enterprise-lab
kubectl logs deployment/document-service -n enterprise-lab -f
kubectl logs deployment/document-service -n enterprise-lab --previous
```

## Exec

```bash
kubectl exec -it deployment/document-service -n enterprise-lab -- sh
```

## Port Forward

```bash
kubectl port-forward -n enterprise-lab svc/document-service 8083:80
curl http://localhost:8083/actuator/health
```

## Apply And Delete

```bash
kubectl apply -f deploy/k8s/namespace.yaml
kubectl delete -f deploy/k8s/namespace.yaml
```

## Rollouts

```bash
kubectl rollout status deployment/document-service -n enterprise-lab
kubectl rollout history deployment/document-service -n enterprise-lab
kubectl rollout undo deployment/document-service -n enterprise-lab
```

## Debug Pod

```bash
kubectl run netshoot \
  --rm -it \
  --restart=Never \
  --image=nicolaka/netshoot \
  -- sh
```

Inside:

```bash
curl -v http://document-service.enterprise-lab.svc.cluster.local/actuator/health
nc -vz host.k3d.internal 9094
```

## Things To Break And Fix

1. Deploy an image that does not exist and inspect `ImagePullBackOff`.
2. Break a readiness probe and inspect pod events.
3. Create a ConfigMap change and restart a deployment.
4. Scale a deployment to zero and back up.

```bash
kubectl scale deployment document-service -n enterprise-lab --replicas=0
kubectl scale deployment document-service -n enterprise-lab --replicas=1
```

## Know As A DevOps Engineer

- Pods are disposable.
- Deployments manage ReplicaSets, which manage pods.
- Services provide stable networking for pods.
- Ingress routes external HTTP traffic.
- ConfigMaps are for config; Secrets are for sensitive values.
- Events are often the fastest path to the real failure.
