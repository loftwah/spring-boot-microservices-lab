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
aws --profile rustfs --endpoint-url http://localhost:9000 s3 mb s3://linkarooie-media-local

echo "hello rustfs" > /tmp/rustfs-demo.txt

aws --profile rustfs --endpoint-url http://localhost:9000 \
  s3 mb s3://linkarooie-media-local

aws --profile rustfs --endpoint-url http://localhost:9000 \
  s3 cp /tmp/rustfs-demo.txt s3://linkarooie-media-local/rustfs-demo.txt

aws --profile rustfs --endpoint-url http://localhost:9000 \
  s3 ls s3://linkarooie-media-local/

aws --profile rustfs --endpoint-url http://localhost:9000 \
  s3 cp s3://linkarooie-media-local/rustfs-demo.txt -

aws --profile rustfs --endpoint-url http://localhost:9000 \
  s3 rm s3://linkarooie-media-local/rustfs-demo.txt
```

## What Linkarooie Should Use

`linkarooie-api` should:

1. Receive avatar and banner uploads.
2. Validate file size, content type, and decoded image dimensions.
3. Store original media objects privately in RustFS.
4. Store object key and metadata in Postgres.
5. Publish media events when variants or generated OG images are needed.

`linkarooie-media-worker` should:

1. Read original media objects.
2. Generate web-safe variants with Sharp.
3. Upload generated variants and OG images.
4. Call the API completion endpoints.

Object key pattern:

```text
profiles/{profileId}/{purpose}/{mediaId}/original.{ext}
profiles/{profileId}/{purpose}/{mediaId}/{variant}.{ext}
profiles/{profileId}/og/{mediaId}/og.jpg
```

Metadata to store in Postgres:

```text
media_id
profile_id
bucket
object_key
content_type
size_bytes
checksum
width
height
purpose
status
created_at
```

## Things To Break And Fix

1. Upload an object with the wrong bucket name and inspect the error.
2. Delete an object and confirm Linkarooie returns a clear media error or fallback.
3. Change credentials and confirm the app fails readiness or emits clear errors.
4. Upload an unoptimized original and confirm the media worker writes optimized variants.

## Know As A DevOps Engineer

- S3 is object storage, not a filesystem.
- Buckets contain objects identified by keys.
- Object writes are usually whole-object writes.
- Apps should track object metadata outside S3 when business queries matter.
- Local S3-compatible storage is useful, but AWS S3 IAM, encryption, and lifecycle policies are deeper topics.
