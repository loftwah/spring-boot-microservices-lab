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

Create an encryption key for a later lab drill:

```bash
docker exec vault vault write -f transit/keys/linkarooie-lab
```

Encrypt:

```bash
docker exec vault sh -lc 'vault write transit/encrypt/linkarooie-lab plaintext=$(printf "hello vault" | base64)'
```

Decrypt a ciphertext:

```bash
docker exec vault vault write transit/decrypt/linkarooie-lab ciphertext='vault:v1:...'
```

Decode the plaintext:

```bash
printf 'base64-value' | base64 --decode
```

## Policy Drill

Create a narrow policy:

```bash
docker exec -i vault sh -lc 'cat > /tmp/linkarooie-policy.hcl && vault policy write linkarooie-api /tmp/linkarooie-policy.hcl' <<'HCL'
path "transit/encrypt/linkarooie-lab" {
  capabilities = ["update"]
}

path "transit/decrypt/linkarooie-lab" {
  capabilities = ["update"]
}

path "secret/data/linkarooie-api/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
HCL
```

Create a token for that policy:

```bash
docker exec vault vault token create -policy=linkarooie-api
```

## Linkarooie V1 Decision

Vault is present as a platform lab dependency, but Linkarooie V1 explicitly excludes Vault integration.

Use this runbook to practise Vault separately. Do not block the Linkarooie API, analytics worker, web service, or media worker on Vault.

Do not store the encryption key in the app. The app asks Vault to encrypt/decrypt.

## Things To Break And Fix

1. Use a token without decrypt permission and inspect the error.
2. Disable Transit and watch a small test client fail clearly.
3. Rotate the Transit key and verify old ciphertext can still decrypt.
4. Restart Vault dev mode and understand what data disappears.

## Know As A DevOps Engineer

- Root tokens are dangerous.
- Policies define capabilities on paths.
- Transit lets apps encrypt without owning keys.
- Sealing/unsealing matters outside dev mode.
- Production Vault needs durable storage, auth methods, audit logs, backup, and recovery plans.
