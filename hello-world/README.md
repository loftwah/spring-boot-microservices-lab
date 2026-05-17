# Spring Boot Hello World

I am new to Spring Boot (or at least not overly experienced) so I am creating the equivalent of DHH's Rails blog tutorial.

Make sure the supporting services are up and running (you will need the database).

```bash
docker exec -it postgres psql -U app -d app -c 'select version();'

(╯°□°)╯︵ ┻━┻ spring-boot-microservices-lab on  main on ☁️  (us-east-1) 
❯ docker exec -it postgres psql -U app -d app -c 'select version();'
                                            version                                             
------------------------------------------------------------------------------------------------
 PostgreSQL 16.13 on aarch64-unknown-linux-musl, compiled by gcc (Alpine 15.2.0) 15.2.0, 64-bit
(1 row)
```

Then run the command to generate our project.

```bash
curl https://start.spring.io/starter.tgz \
  -d type=gradle-project \
  -d language=java \
  -d bootVersion=3.5.14 \
  -d baseDir=. \
  -d groupId=xyz.deanlofts \
  -d artifactId=hello-world \
  -d name=hello-world \
  -d packageName=xyz.deanlofts.helloworld \
  -d javaVersion=21 \
  -d dependencies=web,data-jpa,postgresql,validation,actuator \
  | tar -xz --strip-components=1
```