# Hello World Spring Boot Blog API

This lab rebuilds the classic Rails blog tutorial as a Spring Boot REST API.

You will build:

- A root health-style JSON endpoint
- Articles with CRUD actions
- Validation errors
- Nested comments
- A Docker image
- An optional GHCR publish step

The app uses Java 25, Spring Boot 4, Gradle, Spring Web MVC, Spring Data JPA, Bean Validation, Actuator, PostgreSQL, and Docker.

---

## Lab Layout

```text
spring-boot-microservices-lab/
  supporting-services/
    docker-compose.yml
  hello-world/
    README.md
    build.gradle
    settings.gradle
    gradlew
    gradlew.bat
    gradle/
    src/
```

---

## Ports

```text
Jenkins:     http://localhost:8080
hello-world: http://localhost:8088
Postgres:    localhost:5432
Redis:       localhost:6379
Kafka:       localhost:9092
Vault:       http://localhost:8200
RustFS:      http://localhost:9000
```

Spring Boot normally uses port `8080`, but Jenkins already owns `8080` in this lab, so this app runs on `8088`.

---

## Database

The app uses the shared lab Postgres database.

```text
host: localhost
port: 5432
database: app
username: app
password: app
```

Start the supporting services before running the API:

```bash
cd /Users/deanlofts/gits/labs/spring-boot-microservices-lab/supporting-services
docker compose up -d postgres
```

Check Postgres is ready:

```bash
docker exec postgres pg_isready -U app -d app
```

Expected:

```text
app:5432 - accepting connections
```

---

# 1. Generate The App

Start inside this directory:

```bash
cd /Users/deanlofts/gits/labs/spring-boot-microservices-lab/hello-world
```

Generate the Spring Boot app into a temporary directory:

```bash
tmpdir="$(mktemp -d)"

curl https://start.spring.io/starter.tgz \
  -d type=gradle-project \
  -d language=java \
  -d bootVersion=4.0.6 \
  -d groupId=xyz.deanlofts \
  -d artifactId=hello-world \
  -d name=hello-world \
  -d packageName=xyz.deanlofts.helloworld \
  -d javaVersion=25 \
  -d dependencies=web,data-jpa,postgresql,validation,actuator \
  | tar -xz -C "$tmpdir"
```

Copy the generated app into this directory without replacing this README:

```bash
rsync -av --exclude README.md "$tmpdir"/ ./
```

Expected files:

```text
README.md
HELP.md
build.gradle
settings.gradle
gradlew
gradlew.bat
gradle/
src/
```

---

# 2. Configure The App

Open this file:

```text
src/main/resources/application.properties
```

Replace the contents with:

```properties
spring.application.name=hello-world

server.port=8088

spring.datasource.url=jdbc:postgresql://localhost:5432/app
spring.datasource.username=app
spring.datasource.password=app

spring.jpa.hibernate.ddl-auto=update
spring.jpa.open-in-view=false

management.endpoints.web.exposure.include=health,info
```

---

# 3. Run The App

From inside `hello-world/`:

```bash
chmod +x ./gradlew
./gradlew bootRun
```

Expected terminal output includes:

```text
Tomcat started on port 8088
Started HelloWorldApplication
```

The Gradle terminal may sit at something like:

```text
80% EXECUTING
```

That is normal. The server is running, so the task stays open.

Stop the app with:

```text
Ctrl+C
```

When later sections add Java files, stop the running `bootRun` process and start it again so Spring Boot loads the new code.

---

# 4. Health Check

Run the app:

```bash
./gradlew bootRun
```

In another terminal:

```bash
curl -s http://localhost:8088/actuator/health
```

Expected:

```json
{"status":"UP"}
```

---

# 5. Build The App

From inside `hello-world/`:

```bash
./gradlew build
```

Expected:

```text
BUILD SUCCESSFUL
```

---

# 6. Add The First Controller

This is the API version of the Rails tutorial's first "Hello" page.

Create the package directory:

```bash
mkdir -p src/main/java/xyz/deanlofts/helloworld/home
```

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/home/HomeController.java
```

Paste:

```java
package xyz.deanlofts.helloworld.home;

import java.time.Instant;
import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HomeController {
    @GetMapping("/")
    public Map<String, Object> index() {
        return Map.of(
            "message", "Hello, Spring Boot blog",
            "time", Instant.now().toString()
        );
    }
}
```

Run the app:

```bash
./gradlew bootRun
```

Test in another terminal:

```bash
curl -s http://localhost:8088/
```

Expected shape:

```json
{"time":"2026-05-17T08:30:00Z","message":"Hello, Spring Boot blog"}
```

The field order can differ. JSON object order does not matter.

---

# 7. Add Articles

An article has:

```text
id
title
body
createdAt
updatedAt
```

This is the Spring Boot REST equivalent of the Rails tutorial's first blog model and controller.

Create the package directory:

```bash
mkdir -p src/main/java/xyz/deanlofts/helloworld/articles
```

---

## 7.1 Article Entity

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/articles/Article.java
```

Paste:

```java
package xyz.deanlofts.helloworld.articles;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

@Entity
@Table(name = "articles")
public class Article {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false, columnDefinition = "text")
    private String body;

    @Column(nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant updatedAt;

    protected Article() {
    }

    public Article(String title, String body) {
        this.title = title;
        this.body = body;
    }

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        this.createdAt = now;
        this.updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }

    public Long getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public String getBody() {
        return body;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void update(String title, String body) {
        this.title = title;
        this.body = body;
    }
}
```

---

## 7.2 Article Repository

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/articles/ArticleRepository.java
```

Paste:

```java
package xyz.deanlofts.helloworld.articles;

import org.springframework.data.jpa.repository.JpaRepository;

public interface ArticleRepository extends JpaRepository<Article, Long> {
}
```

---

## 7.3 Article Request DTO

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/articles/ArticleRequest.java
```

Paste:

```java
package xyz.deanlofts.helloworld.articles;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ArticleRequest(
    @NotBlank
    @Size(max = 200)
    String title,

    @NotBlank
    String body
) {
}
```

---

## 7.4 Article Response DTO

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/articles/ArticleResponse.java
```

Paste:

```java
package xyz.deanlofts.helloworld.articles;

import java.time.Instant;

public record ArticleResponse(
    Long id,
    String title,
    String body,
    Instant createdAt,
    Instant updatedAt
) {
    public static ArticleResponse from(Article article) {
        return new ArticleResponse(
            article.getId(),
            article.getTitle(),
            article.getBody(),
            article.getCreatedAt(),
            article.getUpdatedAt()
        );
    }
}
```

---

# 8. Add API Errors

Create the package directory:

```bash
mkdir -p src/main/java/xyz/deanlofts/helloworld/common
```

---

## 8.1 Not Found Exception

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/common/NotFoundException.java
```

Paste:

```java
package xyz.deanlofts.helloworld.common;

public class NotFoundException extends RuntimeException {
    public NotFoundException(String message) {
        super(message);
    }
}
```

---

## 8.2 Global Exception Handler

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/common/ApiExceptionHandler.java
```

Paste:

```java
package xyz.deanlofts.helloworld.common;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {
    @ExceptionHandler(NotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public Map<String, Object> handleNotFound(NotFoundException exception) {
        return Map.of(
            "timestamp", Instant.now().toString(),
            "status", 404,
            "error", "Not Found",
            "message", exception.getMessage()
        );
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.UNPROCESSABLE_ENTITY)
    public Map<String, Object> handleValidation(MethodArgumentNotValidException exception) {
        List<Map<String, String>> errors = exception.getBindingResult()
            .getFieldErrors()
            .stream()
            .map(this::fieldError)
            .toList();

        return Map.of(
            "timestamp", Instant.now().toString(),
            "status", 422,
            "error", "Validation Failed",
            "errors", errors
        );
    }

    private Map<String, String> fieldError(FieldError error) {
        return Map.of(
            "field", error.getField(),
            "message", error.getDefaultMessage() == null ? "is invalid" : error.getDefaultMessage()
        );
    }
}
```

---

# 9. Add The Articles Controller

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/articles/ArticleController.java
```

Paste:

```java
package xyz.deanlofts.helloworld.articles;

import java.net.URI;
import java.util.List;

import jakarta.validation.Valid;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import xyz.deanlofts.helloworld.common.NotFoundException;

@RestController
@RequestMapping("/api/articles")
public class ArticleController {
    private final ArticleRepository articles;

    public ArticleController(ArticleRepository articles) {
        this.articles = articles;
    }

    @GetMapping
    public List<ArticleResponse> index() {
        return articles.findAll()
            .stream()
            .map(ArticleResponse::from)
            .toList();
    }

    @PostMapping
    public ResponseEntity<ArticleResponse> create(@Valid @RequestBody ArticleRequest request) {
        Article article = new Article(request.title(), request.body());
        Article saved = articles.save(article);

        return ResponseEntity
            .created(URI.create("/api/articles/" + saved.getId()))
            .body(ArticleResponse.from(saved));
    }

    @GetMapping("/{id}")
    public ArticleResponse show(@PathVariable Long id) {
        Article article = findArticle(id);
        return ArticleResponse.from(article);
    }

    @PatchMapping("/{id}")
    public ArticleResponse update(
        @PathVariable Long id,
        @Valid @RequestBody ArticleRequest request
    ) {
        Article article = findArticle(id);
        article.update(request.title(), request.body());
        Article saved = articles.save(article);

        return ArticleResponse.from(saved);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> destroy(@PathVariable Long id) {
        Article article = findArticle(id);
        articles.delete(article);

        return ResponseEntity.noContent().build();
    }

    private Article findArticle(Long id) {
        return articles.findById(id)
            .orElseThrow(() -> new NotFoundException("Article " + id + " was not found"));
    }
}
```

Build:

```bash
./gradlew build
```

---

# 10. Test Articles

Run the app:

```bash
./gradlew bootRun
```

In another terminal, create an article and capture its ID:

```bash
ARTICLE_ID=$(
  curl -s -X POST http://localhost:8088/api/articles \
    -H 'Content-Type: application/json' \
    -d '{"title":"Hello Spring Boot","body":"This is the first article in the blog tutorial."}' \
  | jq -r '.id'
)

echo "$ARTICLE_ID"
```

List articles:

```bash
curl -s http://localhost:8088/api/articles | jq
```

Show one article:

```bash
curl -s "http://localhost:8088/api/articles/$ARTICLE_ID" | jq
```

Update the article:

```bash
curl -s -X PATCH "http://localhost:8088/api/articles/$ARTICLE_ID" \
  -H 'Content-Type: application/json' \
  -d '{"title":"Hello Spring Boot REST","body":"Now this feels like a Rails blog as an API."}' \
  | jq
```

Try a validation error:

```bash
curl -s -X POST http://localhost:8088/api/articles \
  -H 'Content-Type: application/json' \
  -d '{"title":"","body":""}' \
  | jq
```

Expected shape:

```json
{
  "status": 422,
  "error": "Validation Failed",
  "errors": [
    {
      "field": "title",
      "message": "must not be blank"
    }
  ]
}
```

Delete the article:

```bash
curl -i -X DELETE "http://localhost:8088/api/articles/$ARTICLE_ID"
```

Expected status:

```text
HTTP/1.1 204
```

---

# 11. Prove Postgres Has The Table

From any terminal:

```bash
docker exec postgres psql -U app -d app -c '\dt'
```

Expected table:

```text
articles
```

Inspect rows:

```bash
docker exec postgres psql -U app -d app -c 'select id, title, created_at, updated_at from articles order by id;'
```

---

# 12. Add Comments

Now add comments.

This matches the Rails tutorial relationship:

```text
Article has many comments
Comment belongs to article
```

In this API version, comments are nested under articles:

```text
/api/articles/{articleId}/comments
```

Create the package directory:

```bash
mkdir -p src/main/java/xyz/deanlofts/helloworld/comments
```

---

## 12.1 Comment Entity

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/comments/Comment.java
```

Paste:

```java
package xyz.deanlofts.helloworld.comments;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import xyz.deanlofts.helloworld.articles.Article;

@Entity
@Table(name = "comments")
public class Comment {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, columnDefinition = "text")
    private String body;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "article_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private Article article;

    @Column(nullable = false)
    private Instant createdAt;

    protected Comment() {
    }

    public Comment(Article article, String body) {
        this.article = article;
        this.body = body;
    }

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
    }

    public Long getId() {
        return id;
    }

    public String getBody() {
        return body;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
```

---

## 12.2 Comment Repository

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/comments/CommentRepository.java
```

Paste:

```java
package xyz.deanlofts.helloworld.comments;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface CommentRepository extends JpaRepository<Comment, Long> {
    List<Comment> findByArticleIdOrderByCreatedAtAsc(Long articleId);

    Optional<Comment> findByArticleIdAndId(Long articleId, Long id);
}
```

---

## 12.3 Comment Request DTO

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/comments/CommentRequest.java
```

Paste:

```java
package xyz.deanlofts.helloworld.comments;

import jakarta.validation.constraints.NotBlank;

public record CommentRequest(
    @NotBlank
    String body
) {
}
```

---

## 12.4 Comment Response DTO

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/comments/CommentResponse.java
```

Paste:

```java
package xyz.deanlofts.helloworld.comments;

import java.time.Instant;

public record CommentResponse(
    Long id,
    Long articleId,
    String body,
    Instant createdAt
) {
    public static CommentResponse from(Comment comment, Long articleId) {
        return new CommentResponse(
            comment.getId(),
            articleId,
            comment.getBody(),
            comment.getCreatedAt()
        );
    }
}
```

---

# 13. Add The Comments Controller

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/comments/CommentController.java
```

Paste:

```java
package xyz.deanlofts.helloworld.comments;

import java.net.URI;
import java.util.List;

import jakarta.validation.Valid;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import xyz.deanlofts.helloworld.articles.Article;
import xyz.deanlofts.helloworld.articles.ArticleRepository;
import xyz.deanlofts.helloworld.common.NotFoundException;

@RestController
@RequestMapping("/api/articles/{articleId}/comments")
public class CommentController {
    private final ArticleRepository articles;
    private final CommentRepository comments;

    public CommentController(ArticleRepository articles, CommentRepository comments) {
        this.articles = articles;
        this.comments = comments;
    }

    @GetMapping
    public List<CommentResponse> index(@PathVariable Long articleId) {
        ensureArticleExists(articleId);

        return comments.findByArticleIdOrderByCreatedAtAsc(articleId)
            .stream()
            .map(comment -> CommentResponse.from(comment, articleId))
            .toList();
    }

    @PostMapping
    public ResponseEntity<CommentResponse> create(
        @PathVariable Long articleId,
        @Valid @RequestBody CommentRequest request
    ) {
        Article article = findArticle(articleId);
        Comment comment = new Comment(article, request.body());
        Comment saved = comments.save(comment);

        return ResponseEntity
            .created(URI.create("/api/articles/" + articleId + "/comments/" + saved.getId()))
            .body(CommentResponse.from(saved, articleId));
    }

    @DeleteMapping("/{commentId}")
    public ResponseEntity<Void> destroy(
        @PathVariable Long articleId,
        @PathVariable Long commentId
    ) {
        ensureArticleExists(articleId);

        Comment comment = comments.findByArticleIdAndId(articleId, commentId)
            .orElseThrow(() -> new NotFoundException(
                "Comment " + commentId + " was not found for article " + articleId
            ));

        comments.delete(comment);

        return ResponseEntity.noContent().build();
    }

    private void ensureArticleExists(Long articleId) {
        findArticle(articleId);
    }

    private Article findArticle(Long articleId) {
        return articles.findById(articleId)
            .orElseThrow(() -> new NotFoundException("Article " + articleId + " was not found"));
    }
}
```

Build:

```bash
./gradlew build
```

---

# 14. Test Comments

Run the app:

```bash
./gradlew bootRun
```

In another terminal, create a new article and capture the ID:

```bash
ARTICLE_ID=$(
  curl -s -X POST http://localhost:8088/api/articles \
    -H 'Content-Type: application/json' \
    -d '{"title":"Article with comments","body":"This article will have comments."}' \
  | jq -r '.id'
)

echo "$ARTICLE_ID"
```

Create a comment and capture its ID:

```bash
COMMENT_ID=$(
  curl -s -X POST "http://localhost:8088/api/articles/$ARTICLE_ID/comments" \
    -H 'Content-Type: application/json' \
    -d '{"body":"This is the first comment."}' \
  | jq -r '.id'
)

echo "$COMMENT_ID"
```

Create another comment:

```bash
curl -s -X POST "http://localhost:8088/api/articles/$ARTICLE_ID/comments" \
  -H 'Content-Type: application/json' \
  -d '{"body":"This is the second comment."}' \
  | jq
```

List comments for the article:

```bash
curl -s "http://localhost:8088/api/articles/$ARTICLE_ID/comments" | jq
```

Try a validation error:

```bash
curl -s -X POST "http://localhost:8088/api/articles/$ARTICLE_ID/comments" \
  -H 'Content-Type: application/json' \
  -d '{"body":""}' \
  | jq
```

Delete one comment:

```bash
curl -i -X DELETE "http://localhost:8088/api/articles/$ARTICLE_ID/comments/$COMMENT_ID"
```

Expected status:

```text
HTTP/1.1 204
```

List comments again:

```bash
curl -s "http://localhost:8088/api/articles/$ARTICLE_ID/comments" | jq
```

---

# 15. Check The Database

List tables:

```bash
docker exec postgres psql -U app -d app -c '\dt'
```

Expected tables:

```text
articles
comments
```

Inspect articles:

```bash
docker exec postgres psql -U app -d app -c 'select id, title, created_at, updated_at from articles order by id;'
```

Inspect comments:

```bash
docker exec postgres psql -U app -d app -c 'select id, article_id, body, created_at from comments order by id;'
```

Delete an article:

```bash
curl -i -X DELETE "http://localhost:8088/api/articles/$ARTICLE_ID"
```

Then confirm its comments are gone too:

```bash
docker exec postgres psql -U app -d app -c "select id, article_id, body from comments where article_id = $ARTICLE_ID;"
```

Expected:

```text
(0 rows)
```

---

# 16. API Route Summary

```text
GET    /                                Root JSON response
GET    /actuator/health                 Health check

GET    /api/articles                    List articles
POST   /api/articles                    Create article
GET    /api/articles/{id}               Show article
PATCH  /api/articles/{id}               Update article
DELETE /api/articles/{id}               Delete article

GET    /api/articles/{articleId}/comments              List comments
POST   /api/articles/{articleId}/comments              Create comment
DELETE /api/articles/{articleId}/comments/{commentId}  Delete comment
```

---

# 17. Build A Docker Image

Create this file:

```text
Dockerfile
```

Paste:

```dockerfile
FROM eclipse-temurin:25-jre

WORKDIR /app

ARG JAR_FILE=build/libs/*-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar

EXPOSE 8088

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

Build the jar:

```bash
./gradlew clean bootJar
```

Build the image:

```bash
docker build -t hello-world:dev .
```

Stop any running `./gradlew bootRun` process before starting the container, because both use port `8088`.

Run the container against the Postgres service on your Mac:

```bash
docker run --rm \
  --name hello-world \
  -p 8088:8088 \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://host.docker.internal:5432/app \
  -e SPRING_DATASOURCE_USERNAME=app \
  -e SPRING_DATASOURCE_PASSWORD=app \
  hello-world:dev
```

Test it from another terminal:

```bash
curl -s http://localhost:8088/actuator/health
```

Expected:

```json
{"status":"UP"}
```

Stop the container with:

```text
Ctrl+C
```

---

# 18. Publish To GHCR

You need a GitHub token with package write permission.

Set your GitHub username or organization:

```bash
export GHCR_OWNER=your-github-username
```

Log in:

```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GHCR_OWNER" --password-stdin
```

Tag the image:

```bash
docker tag hello-world:dev "ghcr.io/$GHCR_OWNER/hello-world:0.0.1"
docker tag hello-world:dev "ghcr.io/$GHCR_OWNER/hello-world:latest"
```

Push:

```bash
docker push "ghcr.io/$GHCR_OWNER/hello-world:0.0.1"
docker push "ghcr.io/$GHCR_OWNER/hello-world:latest"
```

Pull it back to prove it exists:

```bash
docker pull "ghcr.io/$GHCR_OWNER/hello-world:latest"
```

---

# 19. Reset The Lab Database

Use this only when you intentionally want to wipe the blog tables:

```bash
docker exec postgres psql -U app -d app -c 'drop table if exists comments;'
docker exec postgres psql -U app -d app -c 'drop table if exists articles;'
```

The next `./gradlew bootRun` will recreate the tables because this lab uses:

```properties
spring.jpa.hibernate.ddl-auto=update
```

---

# 20. Troubleshooting

If `./gradlew bootRun` cannot connect to Postgres, start the database:

```bash
cd /Users/deanlofts/gits/labs/spring-boot-microservices-lab/supporting-services
docker compose up -d postgres
docker exec postgres pg_isready -U app -d app
```

If port `8088` is already in use:

```bash
lsof -nP -iTCP:8088 -sTCP:LISTEN
```

Stop the process using that port, or temporarily change:

```properties
server.port=8089
```

If `jq` is missing, install it:

```bash
brew install jq
```

If Docker cannot find the jar, build it first:

```bash
./gradlew clean bootJar
```
