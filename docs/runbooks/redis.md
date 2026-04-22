# Redis Runbook

Redis is the lab cache. Treat it like a local stand-in for ElastiCache.

## Connection Details

```text
host: localhost
port: 6379
auth: none
```

From k3d pods:

```text
host: host.k3d.internal
port: 6379
```

## Connect

```bash
docker exec -it redis redis-cli
```

Ping:

```bash
docker exec redis redis-cli ping
```

## Basic Key Drill

```bash
docker exec redis redis-cli SET lab:hello world
docker exec redis redis-cli GET lab:hello
docker exec redis redis-cli DEL lab:hello
```

## TTL Drill

```bash
docker exec redis redis-cli SETEX lab:temp 30 value
docker exec redis redis-cli TTL lab:temp
docker exec redis redis-cli GET lab:temp
```

## Data Structures To Know

Strings:

```bash
docker exec redis redis-cli SET doc:1:title "hello"
docker exec redis redis-cli GET doc:1:title
```

Hashes:

```bash
docker exec redis redis-cli HSET doc:1 title hello status READY
docker exec redis redis-cli HGETALL doc:1
```

Lists:

```bash
docker exec redis redis-cli LPUSH queue:jobs job-1
docker exec redis redis-cli RPOP queue:jobs
```

Sets:

```bash
docker exec redis redis-cli SADD tags urgent internal
docker exec redis redis-cli SMEMBERS tags
```

Streams:

```bash
docker exec redis redis-cli XADD stream:events '*' type document-created id 123
docker exec redis redis-cli XRANGE stream:events - +
```

## Inspect Redis

```bash
docker exec redis redis-cli INFO server
docker exec redis redis-cli INFO memory
docker exec redis redis-cli DBSIZE
docker exec redis redis-cli CONFIG GET appendonly
```

Avoid `KEYS *` in production. Use `SCAN`:

```bash
docker exec redis redis-cli SCAN 0 MATCH 'doc:*' COUNT 100
```

## What The Microservices Should Use

- Cache document metadata by ID.
- Use TTLs for cache entries.
- Use Redis locks or idempotency keys in workflow processing.
- Delete or refresh cache entries after writes.

Example cache keys:

```text
document:{id}
document:list:first-page
workflow-lock:{documentId}
idempotency:{eventId}
```

## Things To Break And Fix

1. Set a cache key, delete it, and confirm the app falls back to Postgres.
2. Create a lock key with TTL, then wait for it to expire.
3. Restart Redis and confirm append-only persistence keeps data.
4. Fill memory with test keys, then inspect `INFO memory`.

## Know As A DevOps Engineer

- Redis is fast but memory-backed.
- TTLs are part of cache design, not an afterthought.
- Persistence modes: RDB snapshots and AOF.
- Cache invalidation is usually harder than cache reads.
- Avoid unbounded keys and large values.
- Do not run blocking commands casually in production.
