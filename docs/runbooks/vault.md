# Vault Runbook

Vault is the lab secret and encryption service. This Compose setup runs Vault in dev mode.

## Connection Details

```text
URL:   http://localhost:8200
Token: root
UI:    http://localhost:8200/ui
```

From k3d pods:

```text
http://host.k3d.internal:8200
```

## Important Dev Mode Warning

Dev mode is intentionally insecure:

- Vault starts unsealed.
- Root token is static.
- Storage is in-memory.
- It is for local learning only.

## CLI Basics

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root

docker exec vault vault status
docker exec vault vault secrets list
```

## KV Secret Drill

```bash
docker exec vault vault kv put secret/lab username=demo password=demo-pass
docker exec vault vault kv get secret/lab
docker exec vault vault kv get -field=password secret/lab
docker exec vault vault kv delete secret/lab
```

## Transit Encryption Drill

Enable Transit:

```bash
docker exec vault vault secrets enable transit
```

Create an encryption key:

```bash
docker exec vault vault write -f transit/keys/document-content
```

Encrypt:

```bash
docker exec vault sh -lc 'vault write transit/encrypt/document-content plaintext=$(printf "hello vault" | base64)'
```

Decrypt a ciphertext:

```bash
docker exec vault vault write transit/decrypt/document-content ciphertext='vault:v1:...'
```

Decode the plaintext:

```bash
printf 'base64-value' | base64 --decode
```

## Policy Drill

Create a narrow policy:

```bash
docker exec -i vault sh -lc 'cat > /tmp/document-policy.hcl && vault policy write document-service /tmp/document-policy.hcl' <<'HCL'
path "transit/encrypt/document-content" {
  capabilities = ["update"]
}

path "transit/decrypt/document-content" {
  capabilities = ["update"]
}

path "secret/data/document-service/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
HCL
```

Create a token for that policy:

```bash
docker exec vault vault token create -policy=document-service
```

## What The Microservices Should Use

Document Service:

- Transit encrypt before writing to RustFS.
- Transit decrypt after reading from RustFS.
- Optional KV config for service-specific settings.

Do not store the encryption key in the app. The app asks Vault to encrypt/decrypt.

## Things To Break And Fix

1. Use a token without decrypt permission and inspect the error.
2. Disable Transit and watch the Document Service fail clearly.
3. Rotate the Transit key and verify old ciphertext can still decrypt.
4. Restart Vault dev mode and understand what data disappears.

## Know As A DevOps Engineer

- Root tokens are dangerous.
- Policies define capabilities on paths.
- Transit lets apps encrypt without owning keys.
- Sealing/unsealing matters outside dev mode.
- Production Vault needs durable storage, auth methods, audit logs, backup, and recovery plans.
