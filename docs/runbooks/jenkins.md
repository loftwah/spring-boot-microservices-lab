# Jenkins Runbook

Jenkins is the lab CI/CD controller.

## URL

```text
http://localhost:8080
```

Initial admin password:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## What To Know

- A Jenkins job can point at a repo and run a Jenkinsfile.
- You can have multiple jobs pointing at the same monorepo.
- Credentials should be stored in Jenkins credentials, not hardcoded in Jenkinsfiles.
- Build logs are one of the main debugging surfaces.

## Recommended Jobs

| Job                | Jenkinsfile                             |
| ------------------ | --------------------------------------- |
| `document-service` | `services/document-service/Jenkinsfile` |
| `audit-service`    | `services/audit-service/Jenkinsfile`    |
| `workflow-service` | `services/workflow-service/Jenkinsfile` |

## First Pipeline Shape

```groovy
pipeline {
  agent any

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Test') {
      steps {
        dir('services/document-service') {
          sh './gradlew test'
        }
      }
    }

    stage('Build Jar') {
      steps {
        dir('services/document-service') {
          sh './gradlew bootJar'
        }
      }
    }
  }
}
```

## Credentials To Add Later

- kubeconfig for `k3d-enterprise-lab`.
- Docker registry credentials, if using a registry.
- Vault token, only if Jenkins needs to read secrets directly.
- GitHub credentials, if needed.

## Tooling Jenkins Eventually Needs

- JDK 21.
- Docker CLI access or a build alternative.
- kubectl.
- helm.
- k3d, if using `k3d image import`.

## Common Admin Tasks

- Create a Pipeline job.
- Configure "Pipeline script from SCM".
- Set Script Path to a service Jenkinsfile.
- Add credentials.
- Replay a failed build.
- Inspect console output.
- Clean workspace.

## Things To Break And Fix

1. Make a test fail and read the Jenkins console log.
2. Point a job at the wrong Jenkinsfile path and fix it.
3. Remove a credential and confirm the failure is clear.
4. Fail a Helm deploy and inspect rollout status.

## Know As A DevOps Engineer

- Jenkins controller vs agents.
- Jenkinsfile stages and post actions.
- Credentials binding.
- Workspace cleanup.
- Build artifacts.
- Pipeline as code.
- Why CI should not depend on manual local machine state long term.
