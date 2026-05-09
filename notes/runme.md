# My Lab

Run this from `spring-boot-microservices-lab`.

```bash
docker compose down
k3d cluster delete enterprise-lab || true

k3d cluster create enterprise-lab \
  --servers 1 \
  --agents 2 \
  --port "8888:80@loadbalancer" \
  --api-port 6550 \
  --wait

docker compose up -d
./verify-supporting-services.sh

kubectl create namespace enterprise-lab --dry-run=client -o yaml | kubectl apply -f -

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

docker exec \
  -e VAULT_ADDR=http://127.0.0.1:8200 \
  -e VAULT_TOKEN=root \
  vault sh -lc 'vault secrets list | grep -q "^transit/" || vault secrets enable transit'

docker exec \
  -e VAULT_ADDR=http://127.0.0.1:8200 \
  -e VAULT_TOKEN=root \
  vault vault write -f transit/keys/document-content

kubectl run netcheck-postgres \
  --rm -i \
  --restart=Never \
  --image=nicolaka/netshoot \
  -- nc -vz -w 5 host.k3d.internal 5432

kubectl run netcheck-redis \
  --rm -i \
  --restart=Never \
  --image=nicolaka/netshoot \
  -- nc -vz -w 5 host.k3d.internal 6379

kubectl run netcheck-kafka \
  --rm -i \
  --restart=Never \
  --image=nicolaka/netshoot \
  -- nc -vz -w 5 host.k3d.internal 9094

kubectl run netcheck-rustfs \
  --rm -i \
  --restart=Never \
  --image=nicolaka/netshoot \
  -- nc -vz -w 5 host.k3d.internal 9000

kubectl run netcheck-vault \
  --rm -i \
  --restart=Never \
  --image=nicolaka/netshoot \
  -- nc -vz -w 5 host.k3d.internal 8200

docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list

docker exec \
  -e VAULT_ADDR=http://127.0.0.1:8200 \
  -e VAULT_TOKEN=root \
  vault vault read transit/keys/document-content
```

