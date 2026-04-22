# kubectx Runbook

kubectx and kubens make Kubernetes context and namespace switching safer and faster.

## List Contexts

```bash
kubectx
```

## Switch To k3d

```bash
kubectx k3d-enterprise-lab
kubectl config current-context
```

## Rename A Context

Use this if a context name is awkward:

```bash
kubectx enterprise-lab=k3d-enterprise-lab
```

## Delete A Context

```bash
kubectx -d old-context-name
```

## Namespaces With kubens

If `kubens` is installed:

```bash
kubens
kubens enterprise-lab
kubens observability
```

Equivalent kubectl command:

```bash
kubectl config set-context --current --namespace=enterprise-lab
```

## Safety Habit

Before destructive commands:

```bash
kubectl config current-context
kubectl config view --minify --output 'jsonpath={..namespace}'; echo
```

## Things To Break And Fix

1. Switch to the wrong namespace and fail to find a pod.
2. Set the namespace back to `enterprise-lab`.
3. Rename the k3d context to a shorter name.

## Know As A DevOps Engineer

- Context is cluster plus user plus namespace.
- Many production mistakes come from running commands in the wrong context.
- Always check context before delete, apply, or Helm operations.
