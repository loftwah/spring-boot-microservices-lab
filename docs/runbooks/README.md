# Runbook Index

These notes are hands-on references for exploring the lab services and tools before wiring the Spring Boot microservices together.

Use them as a round-robin:

1. Start the stack or select the cluster.
2. Connect to one tool.
3. Create something.
4. Inspect it.
5. Break something small.
6. Recover it.
7. Write down what changed.

## Backing Services

| Runbook                             | What To Practise                                                 |
| ----------------------------------- | ---------------------------------------------------------------- |
| [Docker Compose](docker-compose.md) | Start/stop the standalone stack, inspect logs, volumes, networks |
| [Postgres](postgres.md)             | Users, databases, schemas, SQL, DBeaver, backups                 |
| [Redis](redis.md)                   | Keys, TTLs, lists, streams, persistence, cache debugging         |
| [Kafka](kafka.md)                   | Topics, producers, consumers, consumer groups, offsets           |
| [RustFS](rustfs.md)                 | Buckets, objects, S3 clients, access keys, object lifecycle      |
| [Vault](vault.md)                   | Tokens, KV secrets, Transit encryption, policies                 |
| [Jenkins](jenkins.md)               | Jobs, credentials, Jenkinsfiles, agents, build logs              |

## Kubernetes And Platform Tools

| Runbook                           | What To Practise                                      |
| --------------------------------- | ----------------------------------------------------- |
| [k3d](k3d.md)                     | Local cluster lifecycle, image imports, registries    |
| [kubectl](kubectl.md)             | Pods, deployments, services, logs, exec, events       |
| [kubectx](kubectx.md)             | Context and namespace switching                       |
| [Helm](helm.md)                   | Charts, values, releases, upgrades, rollbacks         |
| [Terraform](terraform.md)         | Init, plan, apply, state, modules, AWS-style workflow |
| [Observability](observability.md) | Grafana, Prometheus, Alertmanager, Loki, Alloy        |

## Suggested Learning Order

1. Docker Compose
2. Postgres
3. Redis
4. Kafka
5. RustFS
6. Vault
7. k3d
8. kubectl
9. Helm
10. Jenkins
11. Observability
12. Terraform

Terraform is last for this lab because the current environment is local. It becomes more important when you move from local simulation to AWS resources.
