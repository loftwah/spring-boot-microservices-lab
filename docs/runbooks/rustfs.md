# RustFS Runbook

RustFS is the lab S3-compatible object store. Treat it like a local stand-in for S3.

## Connection Details

```text
S3 endpoint: http://localhost:9000
Console:     http://localhost:9001
Access key:  rustfsadmin
Secret key:  rustfsadmin
```

From k3d pods:

```text
endpoint: http://host.k3d.internal:9000
```

## Console Drill

Open:

```bash
open http://localhost:9001
```

Log in with:

```text
rustfsadmin / rustfsadmin
```

Practise:

1. Create a bucket.
2. Upload an object.
3. Download it.
4. Delete it.
5. Inspect object metadata.

## AWS CLI Setup

Install if needed:

```bash
brew install awscli
```

Configure a local profile:

```bash
aws configure --profile rustfs
```

Use:

```text
AWS Access Key ID: rustfsadmin
AWS Secret Access Key: rustfsadmin
Default region name: us-east-1
Default output format: json
```

## Bucket And Object Drill

```bash
aws --profile rustfs --endpoint-url http://localhost:9000 s3 mb s3://lab-documents

echo "hello rustfs" > /tmp/rustfs-demo.txt

aws --profile rustfs --endpoint-url http://localhost:9000 \
  s3 cp /tmp/rustfs-demo.txt s3://lab-documents/rustfs-demo.txt

aws --profile rustfs --endpoint-url http://localhost:9000 \
  s3 ls s3://lab-documents/

aws --profile rustfs --endpoint-url http://localhost:9000 \
  s3 cp s3://lab-documents/rustfs-demo.txt -

aws --profile rustfs --endpoint-url http://localhost:9000 \
  s3 rm s3://lab-documents/rustfs-demo.txt
```

## What The Microservices Should Use

Document Service should:

1. Receive plaintext content.
2. Encrypt content through Vault Transit.
3. Store encrypted bytes in RustFS.
4. Store object key and metadata in Postgres.
5. Publish a Kafka event.

Object key pattern:

```text
documents/{documentId}/content.bin
```

Metadata to store in Postgres:

```text
document_id
bucket
object_key
content_type
size_bytes
checksum
encryption_key_name
created_at
```

## Things To Break And Fix

1. Upload an object with the wrong bucket name and inspect the error.
2. Delete an object and confirm the Document Service handles missing content.
3. Change credentials and confirm the app fails readiness or emits clear errors.
4. Store plaintext once, then replace the flow so only ciphertext is stored.

## Know As A DevOps Engineer

- S3 is object storage, not a filesystem.
- Buckets contain objects identified by keys.
- Object writes are usually whole-object writes.
- Apps should track object metadata outside S3 when business queries matter.
- Local S3-compatible storage is useful, but AWS S3 IAM, encryption, and lifecycle policies are deeper topics.
