# Spring Boot Microservices Lab

Backend-only lab for building Spring Boot microservices with Gradle, Jenkins, Kafka, Postgres, Redis, RustFS/S3, Vault, and a local k3d Kubernetes cluster.

The goal is not to build a perfect product. The goal is to practise the full platform loop:

1. Run supporting services locally with Docker Compose.
2. Build a few Spring Boot microservices.
3. Publish and consume Kafka events between services.
4. Store relational data in Postgres.
5. Cache useful reads in Redis.
6. Encrypt file content with Vault before storing it in RustFS.
7. Build and deploy the services to k3d using Jenkins pipelines.
8. Observe the services with Prometheus, Loki, Alloy, Alertmanager, and Grafana.

## Current Supporting Stack

This Docker Compose stack is complete for standalone backing services. Treat it like the local version of managed platform services:

```text
Postgres -> RDS-like relational database
Redis    -> ElastiCache-like cache
Kafka    -> MSK-like event streaming
RustFS   -> S3-like object storage
Vault    -> secrets and encryption service
Jenkins  -> centralized CI/CD control plane
```

Do not put the Kubernetes observability stack in this Compose file for the main lab path. Observability should live inside k3d so it can discover pods, scrape services, attach Kubernetes labels, collect pod logs, and alert on cluster/app state.

Keep Jenkins in Docker Compose for this lab. It represents a centralized Jenkins service outside the application cluster, like a shared CI/CD service in a tooling account that reaches the cluster over an allowed network path. Do not install Jenkins into k3d unless you intentionally want to practise operating Jenkins itself on Kubernetes.

Start the backing services:

```bash
docker compose up -d
./verify-supporting-services.sh
```

Services:

| Service | Local URL / Port | Purpose |
| --- | --- | --- |
| Postgres | `localhost:5432` | Relational database, simulating RDS |
| Redis | `localhost:6379` | Cache, simulating ElastiCache |
| Kafka | `localhost:9092` | Host clients |
| Kafka | `host.k3d.internal:9094` | Kubernetes pods in k3d |
| RustFS | `http://localhost:9000` | S3-compatible object storage |
| RustFS Console | `http://localhost:9001` | Object storage GUI |
| Vault | `http://localhost:8200` | Secrets and transit encryption |
| Jenkins | `http://localhost:8080` | Centralized build and deploy controller |

Development credentials:

| Service | Username / Token | Password |
| --- | --- | --- |
| Postgres | `app` | `app` |
| RustFS | `rustfsadmin` | `rustfsadmin` |
| Vault | `root` | token auth |
| Jenkins | created during setup | created during setup |

Jenkins initial admin password, if needed:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

When the backing-service verification is done and before starting microservice work, stop the standalone stack:

```bash
docker compose down
```

This stops and removes the containers but keeps named volumes, so Postgres, Kafka, RustFS, and Jenkins data remain available for the next `docker compose up -d`.

Only wipe all local backing-service data when you intentionally want a clean slate:

```bash
docker compose down -v
```

Do not use `down -v` casually. It deletes the named volumes.

## Kubernetes Cluster

This lab uses the existing k3d cluster:

```bash
k3d cluster create enterprise-lab \
  --servers 1 \
  --agents 2 \
  --port "8888:80@loadbalancer" \
  --api-port 6550 \
  --wait
```

Useful checks:

```bash
kubectx k3d-enterprise-lab
kubectl get nodes
kubectl create namespace enterprise-lab
kubectl get pods -n enterprise-lab
```

The backing services and Jenkins run in Docker Compose on the host. The microservices run in k3d. From inside k3d pods, use `host.k3d.internal` to reach the Compose services.

This models a common enterprise split:

```text
shared services / tooling account -> Docker Compose
application Kubernetes cluster    -> k3d
application workloads             -> Spring Boot pods
```

Planned runtime endpoints from pods:

```text
postgres: host.k3d.internal:5432
redis:    host.k3d.internal:6379
kafka:    host.k3d.internal:9094
rustfs:   http://host.k3d.internal:9000
vault:    http://host.k3d.internal:8200
```

Verify pod-to-host connectivity before deploying apps:

```bash
kubectl run netshoot \
  --rm -it \
  --restart=Never \
  --image=nicolaka/netshoot \
  -- nc -vz host.k3d.internal 5432
```

Repeat for ports `6379`, `9094`, `9000`, and `8200`.

## Local Tooling Needed

Already installed:

```text
docker / orbstack
kubectl
kubectx
helm
k3d
```

Install Java and Gradle:

```bash
brew install openjdk@21 gradle

OPENJDK_PREFIX="$(brew --prefix openjdk@21)"
sudo ln -sfn "$OPENJDK_PREFIX/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk-21.jdk

echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 21)' >> ~/.zshrc
echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

java -version
gradle -v
```

Use the Gradle wrapper in each service once the services are generated:

```bash
./gradlew test
./gradlew bootRun
./gradlew bootJar
```

## Repo Shape

Use this as a monorepo. That is the right call for this lab because the services, Jenkinsfiles, Helm charts, and local platform config should move together.

Planned layout:

```text
spring-boot-microservices-lab/
  docker-compose.yml
  verify-supporting-services.sh
  README.md

  docs/
    runbooks/
      README.md
      docker-compose.md
      postgres.md
      redis.md
      kafka.md
      rustfs.md
      vault.md
      jenkins.md
      k3d.md
      kubectl.md
      kubectx.md
      helm.md
      terraform.md
      observability.md

  services/
    document-service/
      Jenkinsfile
      build.gradle
      src/

    audit-service/
      Jenkinsfile
      build.gradle
      src/

    workflow-service/
      Jenkinsfile
      build.gradle
      src/

  deploy/
    helm/
      document-service/
      audit-service/
      workflow-service/

    k8s/
      namespace.yaml
      external-services.yaml

    observability/
      values-kube-prometheus-stack.yaml
      values-loki.yaml
      values-alloy.yaml
```

Split into multiple repos later only if you specifically want to practise multi-repo release coordination. For now, one repo is simpler and better.

## Runbooks

Use the runbooks as practical cheat sheets and walkthroughs:

```text
docs/runbooks/
```

Start with [the runbook index](docs/runbooks/README.md), then round-robin through the backing services and Kubernetes tools before building the microservices.

## Microservice Plan

Build three services. Each one should expose REST endpoints, actuator health, and Kafka integration.

### 1. Document Service

Owns uploaded document metadata and object storage.

Responsibilities:

- CRUD document metadata in Postgres.
- Cache document metadata in Redis.
- Encrypt document content using Vault Transit.
- Store encrypted bytes in RustFS.
- Publish document lifecycle events to Kafka.

Suggested endpoints:

```text
GET    /actuator/health
GET    /actuator/info

POST   /documents
GET    /documents
GET    /documents/{id}
PUT    /documents/{id}
DELETE /documents/{id}

PUT    /documents/{id}/content
GET    /documents/{id}/content
DELETE /documents/{id}/content
```

Events produced:

```text
documents.v1.document-created
documents.v1.document-updated
documents.v1.document-deleted
documents.v1.document-content-stored
```

Backing services used:

| Service | Use |
| --- | --- |
| Postgres | `documents` table |
| Redis | document read cache |
| Vault | transit encrypt/decrypt |
| RustFS | encrypted object storage |
| Kafka | document events |

### 2. Audit Service

Consumes document events and records what happened.

Responsibilities:

- Subscribe to document lifecycle events.
- Write immutable audit rows to Postgres.
- Cache recent audit lookups in Redis.
- Publish an audit event after each row is recorded.

Suggested endpoints:

```text
GET    /actuator/health
GET    /audits
GET    /audits/{id}
GET    /audits/documents/{documentId}
DELETE /audits/{id}
```

Events consumed:

```text
documents.v1.document-created
documents.v1.document-updated
documents.v1.document-deleted
documents.v1.document-content-stored
```

Events produced:

```text
audits.v1.audit-recorded
```

Backing services used:

| Service | Use |
| --- | --- |
| Postgres | `audit_events` table |
| Redis | recent audit cache |
| Kafka | consume document events, publish audit events |

### 3. Workflow Service

Consumes audit events and tracks processing state.

Responsibilities:

- Subscribe to audit events.
- Track workflow state in Postgres.
- Use Redis for short-lived processing locks/idempotency.
- Publish workflow completion events.
- Optionally read document metadata from Document Service over HTTP.

Suggested endpoints:

```text
GET    /actuator/health
GET    /workflows
GET    /workflows/{id}
GET    /workflows/documents/{documentId}
POST   /workflows/{id}/retry
DELETE /workflows/{id}
```

Events consumed:

```text
audits.v1.audit-recorded
```

Events produced:

```text
workflows.v1.workflow-completed
workflows.v1.workflow-failed
```

Backing services used:

| Service | Use |
| --- | --- |
| Postgres | `workflows` table |
| Redis | locks, idempotency keys, status cache |
| Kafka | consume audit events, publish workflow events |

## Kafka Topics

Create explicit topics rather than relying on auto-create:

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
```

Use a simple JSON envelope first:

```json
{
  "eventId": "uuid",
  "eventType": "document-created",
  "version": 1,
  "occurredAt": "2026-04-22T00:00:00Z",
  "source": "document-service",
  "correlationId": "uuid",
  "payload": {}
}
```

## Vault And RustFS Design

Use Vault Transit for encryption. The Document Service should never store plaintext in RustFS.

Initial Vault setup:

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root

docker exec vault vault secrets enable transit
docker exec vault vault write -f transit/keys/document-content
```

Document write flow:

```text
client -> document-service
document-service -> Vault Transit encrypt
document-service -> RustFS put encrypted object
document-service -> Postgres save metadata
document-service -> Redis evict/cache
document-service -> Kafka publish document-content-stored
```

Document read flow:

```text
client -> document-service
document-service -> Postgres read metadata
document-service -> RustFS get encrypted object
document-service -> Vault Transit decrypt
document-service -> return plaintext to caller
```

For the first pass, keep the Vault token and RustFS credentials in Kubernetes Secrets. Later, replace this with a stronger auth pattern.

## Creating The Spring Boot Services

Use Java 21, Spring Boot 3.x, and Gradle.

Create the service directories from the repo root:

```bash
mkdir -p services
```

Generate `document-service`:

```bash
curl -sS https://start.spring.io/starter.zip \
  -d type=gradle-project \
  -d language=java \
  -d javaVersion=21 \
  -d groupId=com.example.lab \
  -d artifactId=document-service \
  -d name=document-service \
  -d packageName=com.example.lab.document \
  -d dependencies=web,actuator,validation,data-jpa,postgresql,data-redis,kafka,testcontainers,flyway \
  -o /tmp/document-service.zip

unzip /tmp/document-service.zip -d services/document-service
```

Generate `audit-service`:

```bash
curl -sS https://start.spring.io/starter.zip \
  -d type=gradle-project \
  -d language=java \
  -d javaVersion=21 \
  -d groupId=com.example.lab \
  -d artifactId=audit-service \
  -d name=audit-service \
  -d packageName=com.example.lab.audit \
  -d dependencies=web,actuator,validation,data-jpa,postgresql,data-redis,kafka,testcontainers,flyway \
  -o /tmp/audit-service.zip

unzip /tmp/audit-service.zip -d services/audit-service
```

Generate `workflow-service`:

```bash
curl -sS https://start.spring.io/starter.zip \
  -d type=gradle-project \
  -d language=java \
  -d javaVersion=21 \
  -d groupId=com.example.lab \
  -d artifactId=workflow-service \
  -d name=workflow-service \
  -d packageName=com.example.lab.workflow \
  -d dependencies=web,actuator,validation,data-jpa,postgresql,data-redis,kafka,testcontainers,flyway \
  -o /tmp/workflow-service.zip

unzip /tmp/workflow-service.zip -d services/workflow-service
```

Smoke test each generated service before adding integrations:

```bash
cd services/document-service
./gradlew test
./gradlew bootRun
```

In another shell:

```bash
curl http://localhost:8080/actuator/health
```

Only one service can use port `8080` locally at a time unless you change `server.port` in each service. Suggested local ports:

```text
document-service: 8083
audit-service:    8084
workflow-service: 8085
```

For each service, generate a Spring Boot Gradle project with these dependencies:

```text
Spring Web
Spring Boot Actuator
Validation
Spring Data JPA
PostgreSQL Driver
Spring Data Redis
Spring for Apache Kafka
Testcontainers
```

Add these manually where needed:

```text
AWS SDK v2 S3 client: document-service
Vault client or Spring Vault: document-service
Flyway or Liquibase: all services that own Postgres tables
```

Suggested first implementation order:

1. Create `services/document-service`.
2. Add `/actuator/health` and one `/documents` CRUD controller.
3. Add Postgres persistence.
4. Add Redis caching.
5. Add Kafka producer.
6. Add Vault Transit encryption.
7. Add RustFS object storage.
8. Create `services/audit-service`.
9. Add Kafka consumer for document events.
10. Add Postgres audit persistence.
11. Create `services/workflow-service`.
12. Add Kafka consumer for audit events and workflow state.
13. Add Dockerfiles.
14. Add Helm charts.
15. Add Jenkins pipelines.

Do not start with all integrations at once. Get each service booting locally first, then add one backing service at a time.

## Local App Configuration

Local host configuration for Spring Boot:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/app
    username: app
    password: app
  data:
    redis:
      host: localhost
      port: 6379
  kafka:
    bootstrap-servers: localhost:9092

vault:
  uri: http://localhost:8200
  token: root

rustfs:
  endpoint: http://localhost:9000
  access-key: rustfsadmin
  secret-key: rustfsadmin
  bucket: lab-documents
```

k3d pod configuration:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://host.k3d.internal:5432/app
    username: app
    password: app
  data:
    redis:
      host: host.k3d.internal
      port: 6379
  kafka:
    bootstrap-servers: host.k3d.internal:9094

vault:
  uri: http://host.k3d.internal:8200
  token: root

rustfs:
  endpoint: http://host.k3d.internal:9000
  access-key: rustfsadmin
  secret-key: rustfsadmin
  bucket: lab-documents
```

## Observability Plan

Use one shared observability stack for the Kubernetes cluster, not one Grafana per microservice.

Recommended placement:

| Component | Runs In | Why |
| --- | --- | --- |
| Grafana | k3d | One dashboard/query UI for the whole lab |
| Prometheus | k3d | Scrapes Kubernetes and Spring Boot metrics |
| Alertmanager | k3d | Handles alerts from Prometheus |
| Loki | k3d | Stores pod and application logs |
| Alloy | k3d | Collects pod logs and can collect/forward metrics and traces |
| Spring Boot apps | k3d | Expose health, metrics, and logs |
| Postgres, Redis, Kafka, RustFS, Vault | Docker Compose | Standalone backing services |
| Jenkins | Docker Compose | Centralized CI/CD controller outside the app cluster |

This is closer to how Grafana Cloud or a central enterprise observability platform works: many services and teams send telemetry into one shared observability platform. You do not create a separate Grafana for every service. You create service-specific dashboards, folders, alerts, and labels inside the shared Grafana.

The first observability stack should be:

```text
kube-prometheus-stack:
  Prometheus
  Alertmanager
  Grafana
  kube-state-metrics
  node-exporter
  Prometheus Operator

Loki:
  log storage

Alloy:
  pod log collection
  optional OTLP collection later
```

Do not add Grafana, Prometheus, Loki, or Alloy to the Docker Compose backing-service stack for the main path. A Compose-based Grafana is fine for a quick toy demo, but it does not teach the Kubernetes-native pieces this lab is meant to practise.

Install observability after the first microservice exists. That gives Prometheus and Loki something real to collect.

Suggested namespaces:

```bash
kubectl create namespace observability
kubectl create namespace enterprise-lab
```

Suggested Helm repos:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

Initial install shape:

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

Start with Grafana port-forwarding:

```bash
kubectl -n observability port-forward svc/monitoring-grafana 3000:80
```

Then open:

```text
http://localhost:3000
```

Later, expose Grafana through k3d ingress:

```text
http://localhost:8888/grafana
```

### Microservice Observability Contract

Every Spring Boot service should expose:

```text
GET /actuator/health
GET /actuator/info
GET /actuator/prometheus
```

Every Spring Boot service should log to stdout. Prefer structured JSON logs once the basic services work.

Add these dependencies to each service:

```text
spring-boot-starter-actuator
micrometer-registry-prometheus
```

Add this application config:

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

In Kubernetes, each service should include annotations or a `ServiceMonitor` so Prometheus can scrape it.

Recommended first pass:

```text
Use ServiceMonitor resources created by each Helm chart.
```

Each microservice Helm chart should eventually include:

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

Useful first alerts:

```text
service down
high error rate
high p95 latency
Kafka consumer lag
Postgres connection failures
RustFS object write failures
Vault encryption/decryption failures
```

### How Many Grafanas?

Use one Grafana for the lab cluster.

```text
one cluster -> one shared Grafana
many microservices -> many dashboards inside that Grafana
```

Per-service Grafana instances are unusual and create avoidable admin work. They make sense only when teams need hard isolation, separate tenants, separate auth boundaries, or separate environments. For this lab, use one Grafana with:

```text
folder: Document Service
folder: Audit Service
folder: Workflow Service
folder: Platform
folder: Kafka
folder: Kubernetes
```

That is also closer to the Grafana Cloud mental model: one shared observability platform with multiple data sources, dashboards, teams, folders, labels, and alerts.

## Jenkins Plan

Jenkins stays outside k3d. Treat it as a centralized CI service with network access to the cluster API and backing services, not as an application workload owned by this cluster.

Use three Jenkins pipeline jobs pointing at the same Git repo:

| Jenkins Job | Jenkinsfile Path |
| --- | --- |
| `document-service` | `services/document-service/Jenkinsfile` |
| `audit-service` | `services/audit-service/Jenkinsfile` |
| `workflow-service` | `services/workflow-service/Jenkinsfile` |

Each pipeline should eventually run:

```text
checkout
./gradlew test
./gradlew bootJar
docker build
docker push or k3d image import
helm upgrade --install
kubectl rollout status
smoke test deployed service
```

Jenkins still needs a little more setup before it can deploy:

1. JDK 21 available to Jenkins.
2. Gradle wrapper committed in each service.
3. Docker build capability.
4. `kubectl` and `helm` available to the pipeline.
5. A kubeconfig credential for `k3d-enterprise-lab`.
6. A local image strategy.
7. Network access from the Jenkins container to the k3d API and Docker-backed services.

Local image strategy options:

| Option | Notes |
| --- | --- |
| `k3d image import` | Easiest for a local lab. No registry needed. |
| Local Docker registry | Better CI simulation. Requires adding a registry to k3d. |
| Remote registry | Most realistic. Requires auth and push/pull credentials. |

Recommended first pass:

```text
Jenkins builds image -> Jenkins runs k3d image import -> Helm deploys image into k3d
```

Later, switch to a local registry.

## Helm And Kubernetes Plan

Each service gets one Helm chart with:

```text
Deployment
Service
Ingress
ConfigMap
Secret
readinessProbe
livenessProbe
```

The k3d cluster maps load balancer port `8888` to port `80`, so ingress routes should be reachable through:

```text
http://localhost:8888
```

Suggested hostless paths:

```text
http://localhost:8888/documents
http://localhost:8888/audits
http://localhost:8888/workflows
```

## Definition Of Done

The lab is working when:

1. `./verify-supporting-services.sh` passes.
2. All three Spring Boot services pass local tests.
3. Each service runs locally against Compose services.
4. Each service builds a container image.
5. Each service deploys to k3d with Helm.
6. Jenkins has three independent pipelines.
7. The observability stack is deployed in k3d.
8. Grafana can query Prometheus and Loki.
9. Alertmanager receives Prometheus alerts.
10. Each service exposes `/actuator/prometheus`.
11. Each service logs are visible in Loki.
12. Creating a document triggers:

```text
document-service -> Kafka -> audit-service -> Kafka -> workflow-service
```

13. Downloading document content proves:

```text
RustFS stores encrypted content
Vault decrypts on read
Postgres stores metadata
Redis caches useful reads
Kafka records lifecycle events
```

## Useful Commands

Supporting services:

```bash
docker compose up -d
docker compose ps
./verify-supporting-services.sh
docker compose logs -f kafka
```

k3d and Kubernetes:

```bash
kubectx k3d-enterprise-lab
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A
```

Kafka:

```bash
docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list
```

Vault:

```bash
docker exec vault vault status
docker exec vault vault secrets list
```

RustFS:

```bash
open http://localhost:9001
```

Jenkins:

```bash
open http://localhost:8080
```
