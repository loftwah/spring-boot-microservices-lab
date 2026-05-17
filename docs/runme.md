# Linkarooie Lab Runbook

Run commands from `spring-boot-microservices-lab` unless a step says otherwise.

This is the linear path for the lab. Start with local services and application processes. Move to k3d only after the local application behaviour works.

## Step 1 - Verify The Repo Scaffold

```bash
./scripts/verify-repo-layout.sh
```

Read the implementation plan:

```bash
open docs/implementation-plan.md
```

## Step 2 - Start Docker Compose Supporting Services

This starts Postgres, Redis, Kafka, RustFS, Vault, and Jenkins.

```bash
cd supporting-services
docker compose up -d
./verify-supporting-services.sh
cd ..
```

If something fails:

```bash
cd supporting-services
docker compose ps
docker compose logs postgres
docker compose logs redis
docker compose logs kafka
docker compose logs rustfs
docker compose logs vault
docker compose logs jenkins
cd ..
```

## Step 3 - Run The Local Doctor

```bash
./scripts/doctor.sh
```

The doctor checks local tooling, repo layout, container health, host ports, and Kafka tooling.

## Step 4 - Prepare Linkarooie Supporting-Service State

```bash
./supporting-services/scripts/prepare-linkarooie-supporting-services.sh
```

This creates the Kafka topics and the RustFS bucket the app will use.

Expected topics:

```text
linkarooie.analytics.events.v1
linkarooie.media.events.v1
linkarooie.audit.events.v1
linkarooie.profile.events.v1
linkarooie.dead-letter.v1
```

Only analytics is required for the first worker milestone. The others are created early so local infrastructure is predictable.

## Step 5 - Build The Application Locally First

Follow the stories in order:

```text
docs/stories/01-api-foundation.md
docs/stories/02-auth-and-workspaces.md
docs/stories/03-profiles-and-public-reads.md
docs/stories/04-profile-content.md
docs/stories/05-media-uploads.md
docs/stories/06-analytics-pipeline.md
docs/stories/07-linkarooie-web-public.md
docs/stories/08-linkarooie-web-dashboard.md
```

Expected local application commands once code exists:

```bash
cd services/linkarooie-api
./gradlew clean test
./gradlew bootRun
```

```bash
cd services/linkarooie-analytics-worker
./gradlew clean test
./gradlew bootRun
```

```bash
cd services/linkarooie-web
bun install
bun run dev
```

```bash
cd services/linkarooie-media-worker
bun install
bun run dev
```

## Step 6 - Start Or Recreate k3d

Do this after the local application works.

If the cluster already exists and you want to keep it:

```bash
k3d cluster start enterprise-lab || true
k3d kubeconfig merge enterprise-lab --switch-context
kubectl get nodes
```

If you want a fresh cluster:

```bash
k3d cluster delete enterprise-lab || true

k3d cluster create enterprise-lab \
  --servers 1 \
  --agents 2 \
  --port "8888:80@loadbalancer" \
  --api-port 6550 \
  --wait

kubectl get nodes
```

## Step 7 - Verify k3d Pods Can Reach Compose Services

These checks use unique pod names so an interrupted run does not block the next one.

```bash
kubectl run "netcheck-postgres-$(date +%s)" \
  --rm -i \
  --restart=Never \
  --labels=app.kubernetes.io/part-of=enterprise-lab-netcheck \
  --image=nicolaka/netshoot \
  -- nc -vz -w 5 host.k3d.internal 5432

kubectl run "netcheck-redis-$(date +%s)" \
  --rm -i \
  --restart=Never \
  --labels=app.kubernetes.io/part-of=enterprise-lab-netcheck \
  --image=nicolaka/netshoot \
  -- nc -vz -w 5 host.k3d.internal 6379

kubectl run "netcheck-kafka-$(date +%s)" \
  --rm -i \
  --restart=Never \
  --labels=app.kubernetes.io/part-of=enterprise-lab-netcheck \
  --image=nicolaka/netshoot \
  -- nc -vz -w 5 host.k3d.internal 9094

kubectl run "netcheck-rustfs-$(date +%s)" \
  --rm -i \
  --restart=Never \
  --labels=app.kubernetes.io/part-of=enterprise-lab-netcheck \
  --image=nicolaka/netshoot \
  -- nc -vz -w 5 host.k3d.internal 9000
```

Clean up interrupted netchecks:

```bash
kubectl delete pod \
  -l app.kubernetes.io/part-of=enterprise-lab-netcheck \
  --ignore-not-found
```

## Step 8 - Containerize And Deploy App Workloads

Follow:

```text
docs/stories/09-containers-and-k3d.md
```

At this point:

- Linkarooie app workloads run in k3d.
- Supporting services still run in Docker Compose.
- Pods use `host.k3d.internal` to reach the supporting services.

## Step 9 - Add Generated Media Worker

Follow:

```text
docs/stories/10-linkarooie-media-worker.md
```

This adds the Node.js media worker, image variants, and generated OG images.

## Stop Or Reset

Stop supporting services without deleting data:

```bash
cd supporting-services
docker compose down
```

Only wipe data when you intentionally want a clean slate:

```bash
cd supporting-services
docker compose down -v
```
