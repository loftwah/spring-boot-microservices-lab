# My Lab

Run commands from `spring-boot-microservices-lab`.

This is the linear path. Start at Step 1 and keep going down.

## Step 1 - Clean Up Previous Debug Pods

Do this first if you interrupted any `kubectl run` command.

```bash
kubectl delete pod \
  -l app.kubernetes.io/part-of=enterprise-lab-netcheck \
  --ignore-not-found

kubectl delete pod \
  netcheck-postgres \
  netcheck-redis \
  netcheck-kafka \
  netcheck-rustfs \
  netcheck-vault \
  --ignore-not-found
```

Check what is left:

```bash
kubectl get pods
```

If Kubernetes is pointing at the wrong cluster:

```bash
kubectl config current-context
k3d kubeconfig merge enterprise-lab --switch-context
kubectl get nodes
```

## Step 2 - Start Or Recreate k3d

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

## Step 3 - Start Docker Compose Services

This starts Postgres, Redis, Kafka, RustFS, Vault, and Jenkins.

```bash
docker compose up -d
./verify-supporting-services.sh
```

If something fails:

```bash
docker compose ps
docker compose logs postgres
docker compose logs redis
docker compose logs kafka
docker compose logs rustfs
docker compose logs vault
docker compose logs jenkins
```

Stop services without deleting data:

```bash
docker compose down
```

Only wipe data when you intentionally want a clean slate:

```bash
docker compose down -v
```

## Step 4 - Create The Kubernetes Namespace

```bash
kubectl create namespace enterprise-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl get namespace enterprise-lab
```

## Step 5 - Create Kafka Topics

Use hyphens in topic names. Kafka can warn about metric-name collisions when topic names use periods or underscores.

```bash
docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --if-not-exists \
  --topic documents-v1-events \
  --partitions 3 \
  --replication-factor 1

docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --if-not-exists \
  --topic audits-v1-events \
  --partitions 3 \
  --replication-factor 1

docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --if-not-exists \
  --topic workflows-v1-events \
  --partitions 3 \
  --replication-factor 1

docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --if-not-exists \
  --topic lab-v1-dead-letter \
  --partitions 3 \
  --replication-factor 1

docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list
```

If old dotted topics exist, delete them:

```bash
docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --delete \
  --topic audits.v1.events

docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --delete \
  --topic documents.v1.events

docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --delete \
  --topic workflows.v1.events

docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --delete \
  --topic lab.v1.dead-letter
```

## Step 6 - Initialise Vault Transit

Set `VAULT_ADDR` explicitly inside the container. Without it, the Vault CLI may try HTTPS on `127.0.0.1:8200`.

```bash
docker exec \
  -e VAULT_ADDR=http://127.0.0.1:8200 \
  -e VAULT_TOKEN=root \
  vault sh -lc 'vault secrets list | grep -q "^transit/" || vault secrets enable transit'

docker exec \
  -e VAULT_ADDR=http://127.0.0.1:8200 \
  -e VAULT_TOKEN=root \
  vault vault write -f transit/keys/document-content

docker exec \
  -e VAULT_ADDR=http://127.0.0.1:8200 \
  -e VAULT_TOKEN=root \
  vault vault read transit/keys/document-content
```

## Step 7 - Verify k3d Pods Can Reach Compose Services

`kubectl run` starts a temporary pod in Kubernetes, similar to `docker run` starting a container in Docker.

These checks use unique pod names so a previous interrupted run does not block the next one.

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

kubectl run "netcheck-vault-$(date +%s)" \
  --rm -i \
  --restart=Never \
  --labels=app.kubernetes.io/part-of=enterprise-lab-netcheck \
  --image=nicolaka/netshoot \
  -- nc -vz -w 5 host.k3d.internal 8200
```

If a netcheck hangs or you interrupt it:

```bash
kubectl get pods

kubectl delete pod \
  -l app.kubernetes.io/part-of=enterprise-lab-netcheck \
  --ignore-not-found

kubectl get pod -o wide
```

If you need to inspect one stuck pod before deleting it:

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

## Step 8 - Confirm The Runtime Endpoints

From your Mac:

```text
Postgres: localhost:5432
Redis:    localhost:6379
Kafka:    localhost:9092
RustFS:   http://localhost:9000
Vault:    http://localhost:8200
Jenkins:  http://localhost:8080
```

From k3d pods:

```text
Postgres: host.k3d.internal:5432
Redis:    host.k3d.internal:6379
Kafka:    host.k3d.internal:9094
RustFS:   http://host.k3d.internal:9000
Vault:    http://host.k3d.internal:8200
```

## Step 9 - Next Lab Move

Start with `document-service`.

It should use:

```text
Postgres: document metadata
Redis:    document read cache
Kafka:    publish document events to documents-v1-events
Vault:    encrypt/decrypt content with transit/keys/document-content
RustFS:   store encrypted document content
```
