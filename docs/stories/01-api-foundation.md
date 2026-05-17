# Story 1: API Foundation

## Goal

Create the first service: `services/linkarooie-api`.

When this story is done, you can run a real Spring Boot API locally, hit health endpoints, and prove it can talk to the supporting services.

## What You Are Learning

- What Spring Initializr creates.
- What Gradle wrapper files are.
- How a Spring Boot service starts.
- Where Java source files go.
- Where config lives.
- How to run tests.
- How to run the API locally.

Spring Initializr is the official Spring project generator. It can be used through the website or through HTTP. The commands below use the HTTP API so the steps are repeatable.

Official references:

- Spring Initializr exposes endpoints for generating JVM projects.
- Spring Boot's Gradle plugin is the standard way to build and run Spring Boot apps with Gradle.

## Result At The End

You should have:

```text
services/linkarooie-api/
  gradlew
  gradlew.bat
  settings.gradle
  build.gradle
  src/main/java/com/linkarooie/api/LinkarooieApiApplication.java
  src/main/java/com/linkarooie/api/health/HealthController.java
  src/main/java/com/linkarooie/api/health/ReadyController.java
  src/main/resources/application.yml
  src/test/java/com/linkarooie/api/LinkarooieApiApplicationTests.java
```

You should be able to run:

```bash
cd services/linkarooie-api
./gradlew test
./gradlew bootRun
```

And in another terminal:

```bash
curl -i http://localhost:8080/api/health
curl -i http://localhost:8080/api/ready
```

## Step 1: Check Java

From the repo root:

```bash
java -version
```

You want Java 21.

Good enough output looks like:

```text
openjdk version "21..."
```

If Java is not 21, fix that before continuing. Do not debug Spring Boot until Java is correct.

## Step 2: Start The Supporting Services

From the repo root:

```bash
cd supporting-services
docker compose up -d
./verify-supporting-services.sh
cd ..
```

Why:

- Postgres, Redis, Kafka, and RustFS already exist for the app to use.
- The API will connect to these locally through `localhost`.

Then prepare Linkarooie-specific platform state:

```bash
./supporting-services/scripts/prepare-linkarooie-supporting-services.sh
```

This creates:

- Kafka topics.
- RustFS bucket `linkarooie-media-local`.

## Step 3: Generate The Spring Boot Project

From the repo root:

```bash
mkdir -p /tmp/linkarooie-spring

curl -G https://start.spring.io/starter.zip \
  -d type=gradle-project \
  -d language=java \
  -d javaVersion=21 \
  -d groupId=com.linkarooie \
  -d artifactId=linkarooie-api \
  -d name=linkarooie-api \
  -d packageName=com.linkarooie.api \
  -d dependencies=web,actuator,validation,data-jpa,flyway,postgresql,data-redis,kafka,cache \
  -o /tmp/linkarooie-spring/linkarooie-api.zip
```

What this does:

- Downloads a generated Spring Boot project zip.
- Uses Java.
- Uses Gradle with Groovy `build.gradle`.
- Adds the dependencies needed for the API foundation.

Dependencies explained:

| Dependency | Why We Need It |
| --- | --- |
| `web` | REST controllers and HTTP server |
| `actuator` | health/readiness endpoints and production checks |
| `validation` | request validation later |
| `data-jpa` | database access through JPA later |
| `flyway` | database migrations |
| `postgresql` | Postgres driver |
| `data-redis` | Redis connection |
| `kafka` | Kafka producer later |
| `cache` | Spring cache abstraction for public profile cache later |

Unzip it:

```bash
rm -rf /tmp/linkarooie-spring/linkarooie-api
unzip -q /tmp/linkarooie-spring/linkarooie-api.zip -d /tmp/linkarooie-spring/linkarooie-api
```

Copy the generated files into the service directory:

```bash
rsync -a \
  --exclude README.md \
  /tmp/linkarooie-spring/linkarooie-api/ \
  services/linkarooie-api/
```

Why `rsync` and not unzip directly:

- `services/linkarooie-api` already has lab docs and seed assets.
- This copies the generated app without deleting those files.

## Step 4: Inspect What Was Generated

```bash
find services/linkarooie-api -maxdepth 3 -type f | sort
```

Important files:

```text
build.gradle
settings.gradle
gradlew
src/main/java/com/linkarooie/api/LinkarooieApiApplication.java
src/test/java/com/linkarooie/api/LinkarooieApiApplicationTests.java
```

What they mean:

| File | Meaning |
| --- | --- |
| `gradlew` | Gradle wrapper script. Use this instead of system `gradle`. |
| `build.gradle` | Build config and dependencies for this service. |
| `settings.gradle` | Gradle project name. |
| `LinkarooieApiApplication.java` | Main Spring Boot entry point. |
| `LinkarooieApiApplicationTests.java` | Generated startup test. |

## Step 5: Run The Generated Test

```bash
cd services/linkarooie-api
./gradlew test
```

Expected result:

```text
BUILD SUCCESSFUL
```

If this fails, stop and fix it before adding code. At this point the app is still mostly generated, so failures are usually Java version, network, or dependency download issues.

Return to the repo root after the test:

```bash
cd ../..
```

## Step 6: Add Local Configuration

Create:

```text
services/linkarooie-api/src/main/resources/application.yml
```

Content:

```yaml
server:
  port: ${SERVER_PORT:8080}

spring:
  application:
    name: linkarooie-api

  datasource:
    url: ${DATABASE_URL:jdbc:postgresql://localhost:5432/app}
    username: ${DATABASE_USERNAME:app}
    password: ${DATABASE_PASSWORD:app}

  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false

  flyway:
    enabled: true

  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}

  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}

management:
  endpoints:
    web:
      exposure:
        include: health,info
  endpoint:
    health:
      probes:
        enabled: true
```

Why:

- The API can run on your Mac with defaults.
- Later, Docker/k3d can override these values with environment variables.
- `ddl-auto: validate` prevents Hibernate from silently creating tables behind Flyway's back.

## Step 7: Add The First Migration

Create this directory if it does not exist:

```bash
mkdir -p services/linkarooie-api/src/main/resources/db/migration
```

Create:

```text
services/linkarooie-api/src/main/resources/db/migration/V001__api_foundation.sql
```

Content:

```sql
create table if not exists app_schema_marker (
  id integer primary key,
  name text not null,
  created_at timestamptz not null default now()
);

insert into app_schema_marker (id, name)
values (1, 'linkarooie-api-foundation')
on conflict (id) do nothing;
```

Why:

- This proves Flyway is running migrations.
- Later stories replace this tiny marker with real tables.

## Step 8: Add `/api/health`

Create the package directory:

```bash
mkdir -p services/linkarooie-api/src/main/java/com/linkarooie/api/health
```

Create:

```text
services/linkarooie-api/src/main/java/com/linkarooie/api/health/HealthController.java
```

Content:

```java
package com.linkarooie.api.health;

import java.time.Instant;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {
    @GetMapping("/api/health")
    public Map<String, Object> health() {
        return Map.of(
            "status", "UP",
            "service", "linkarooie-api",
            "checkedAt", Instant.now().toString()
        );
    }
}
```

Why:

- This is a simple liveness endpoint.
- It proves the app can receive and return HTTP.

## Step 9: Add `/api/ready`

Use the same package directory from the previous step:

```bash
mkdir -p services/linkarooie-api/src/main/java/com/linkarooie/api/health
```

Create:

```text
services/linkarooie-api/src/main/java/com/linkarooie/api/health/ReadyController.java
```

Content:

```java
package com.linkarooie.api.health;

import java.sql.Connection;
import java.util.Map;
import javax.sql.DataSource;
import org.springframework.data.redis.connection.RedisConnection;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ReadyController {
    private final DataSource dataSource;
    private final RedisConnectionFactory redisConnectionFactory;
    private final KafkaTemplate<String, String> kafkaTemplate;

    public ReadyController(
        DataSource dataSource,
        RedisConnectionFactory redisConnectionFactory,
        KafkaTemplate<String, String> kafkaTemplate
    ) {
        this.dataSource = dataSource;
        this.redisConnectionFactory = redisConnectionFactory;
        this.kafkaTemplate = kafkaTemplate;
    }

    @GetMapping("/api/ready")
    public ResponseEntity<Map<String, Object>> ready() throws Exception {
        try (Connection connection = dataSource.getConnection()) {
            if (!connection.isValid(2)) {
                return ResponseEntity.internalServerError().body(Map.of("status", "DOWN", "database", "DOWN"));
            }
        }

        try (RedisConnection connection = redisConnectionFactory.getConnection()) {
            connection.ping();
        }

        kafkaTemplate.partitionsFor("linkarooie.analytics.events.v1");

        return ResponseEntity.ok(Map.of(
            "status", "UP",
            "database", "UP",
            "redis", "UP",
            "kafka", "UP"
        ));
    }
}
```

Why:

- Readiness means "can this service do useful work?"
- This checks Postgres, Redis, and Kafka from the API process.

## Step 10: Run The API

```bash
cd services/linkarooie-api
./gradlew bootRun
```

Wait for a line like:

```text
Started LinkarooieApiApplication
```

Leave this running.

## Step 11: Call The API

Open a second terminal from the repo root:

```bash
curl -i http://localhost:8080/api/health
```

Expected:

```text
HTTP/1.1 200
```

And JSON containing:

```json
{"status":"UP","service":"linkarooie-api"}
```

Now check readiness:

```bash
curl -i http://localhost:8080/api/ready
```

Expected:

```text
HTTP/1.1 200
```

And JSON containing:

```json
{"status":"UP","database":"UP","redis":"UP","kafka":"UP"}
```

## Step 12: Confirm Flyway Ran

From the repo root:

```bash
docker exec postgres psql -U app -d app -c 'select * from app_schema_marker;'
```

Expected:

```text
 id |          name
----+----------------------------
  1 | linkarooie-api-foundation
```

## Step 13: Stop The API

In the terminal running `./gradlew bootRun`, press:

```text
Ctrl-C
```

## Done When

- `./gradlew test` passes inside `services/linkarooie-api`.
- `./gradlew bootRun` starts the app.
- `GET /api/health` returns `200`.
- `GET /api/ready` returns `200`.
- Postgres contains the `app_schema_marker` row.

## Common Problems

### `Unsupported class file major version`

Your Java version is wrong. Run:

```bash
java -version
```

Use Java 21.

### `Connection refused` for Postgres, Redis, or Kafka

The supporting services are not running.

Run:

```bash
cd supporting-services
docker compose up -d
./verify-supporting-services.sh
cd ..
```

### Kafka readiness fails

Create the topics:

```bash
./supporting-services/scripts/prepare-linkarooie-supporting-services.sh
```

### `Permission denied: ./gradlew`

Make the wrapper executable:

```bash
chmod +x services/linkarooie-api/gradlew
```
