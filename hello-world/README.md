# Hello World Spring Boot Blog API

This is a Spring Boot REST API version of the classic Rails blog tutorial.

The goal is to build a tiny blog API with:

- Java 25
- Spring Boot 4
- Gradle
- PostgreSQL
- Spring Web
- Spring Data JPA
- Bean Validation
- Actuator
- Docker
- GHCR

This tutorial assumes the supporting services are already running from the root `docker-compose.yml`.

---

## Lab layout

```text
spring-boot-microservices-lab/
  docker-compose.yml
  .gitignore
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

The supporting Postgres service was created with:

```yaml
POSTGRES_DB: app
POSTGRES_USER: app
POSTGRES_PASSWORD: app
```

---

# 1. Generate the app

Start inside this directory:

```bash
cd /Users/deanlofts/gits/labs/spring-boot-microservices-lab/hello-world
```

This directory should already contain this `README.md`.

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

Copy the generated app into this directory:

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

# 2. Configure the app

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

# 3. Run the app

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

---

# 4. Health check

In another terminal:

```bash
curl -s http://localhost:8088/actuator/health | jq
```

Expected:

```json
{
  "groups": [
    "liveness",
    "readiness"
  ],
  "status": "UP"
}
```

---

# 5. Build the app

From inside `hello-world/`:

```bash
./gradlew build
```

Expected:

```text
BUILD SUCCESSFUL
```

---

# 6. Add the first controller

Create this directory:

```text
src/main/java/xyz/deanlofts/helloworld/home
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
curl -s http://localhost:8088/ | jq
```

Expected shape:

```json
{
  "message": "Hello, Spring Boot blog",
  "time": "2026-05-17T08:30:00Z"
}
```

---

# 7. Articles

An article has:

```text
id
title
body
createdAt
updatedAt
```

This is the Spring Boot REST equivalent of the first Rails blog model and controller.

Create this directory:

```text
src/main/java/xyz/deanlofts/helloworld/articles
```

---

## 7.1 Article entity

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

## 7.2 Article repository

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

## 7.3 Article request DTO

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

## 7.4 Article response DTO

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

# 8. API errors

Create this directory:

```text
src/main/java/xyz/deanlofts/helloworld/common
```

---

## 8.1 Not found exception

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

## 8.2 Global exception handler

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

# 9. Articles controller

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

---

# 10. Test articles

Run the app:

```bash
./gradlew bootRun
```

In another terminal, create an article:

```bash
curl -s -X POST http://localhost:8088/api/articles \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Hello Spring Boot",
    "body": "This is the first article in the blog tutorial."
  }' | jq
```

List articles:

```bash
curl -s http://localhost:8088/api/articles | jq
```

Show one article:

```bash
curl -s http://localhost:8088/api/articles/1 | jq
```

Update an article:

```bash
curl -s -X PATCH http://localhost:8088/api/articles/1 \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Hello Spring Boot REST",
    "body": "Now this feels more like enterprise Rails."
  }' | jq
```

Delete an article:

```bash
curl -i -X DELETE http://localhost:8088/api/articles/1
```

Expected delete response:

```text
HTTP/1.1 204
```

---

# 11. Prove Postgres has the table

From any terminal:

```bash
docker exec -it postgres psql -U app -d app -c '\dt'
```

Expected table:

```text
articles
```

Inspect rows:

```bash
docker exec -it postgres psql -U app -d app -c 'select * from articles;'
```

---

# 12. Comments

Now add comments.

This matches:

```text
Article has many comments
Comment belongs to article
```

Create this directory:

```text
src/main/java/xyz/deanlofts/helloworld/comments
```

---

## 12.1 Comment entity

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

    public Article getArticle() {
        return article;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
```

---

## 12.2 Comment repository

Create this file:

```text
src/main/java/xyz/deanlofts/helloworld/comments/CommentRepository.java
```

Paste:

```java
package xyz.deanlofts.helloworld.comments;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface CommentRepository extends JpaRepository<Comment, Long> {
    List<Comment> findByArticleIdOrderByCreatedAtAsc(Long articleId);
}
```

---

## 12.3 Comment request DTO

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

## 12.4 Comment response DTO

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
    public static CommentResponse from(Comment comment) {
        return new CommentResponse(
            comment.getId(),
            comment.getArticle().getId(),
            comment.getBody(),
            comment.getCreatedAt()
        );
    }
}
```

---

# 13. Comments controller

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
            .map(CommentResponse::from)
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
            .body(CommentResponse.from(saved));
    }

    @DeleteMapping("/{commentId}")
    public ResponseEntity<Void> destroy(
        @PathVariable Long articleId,
        @PathVariable Long commentId
    ) {
        ensureArticleExists(articleId);

        Comment comment = comments.findById(commentId)
            .filter(existing -> existing.getArticle().getId().equals(articleId))
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

---

# 14. Test comments

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

Create a comment:

```bash
curl -s -X POST "http://localhost:8088
```
