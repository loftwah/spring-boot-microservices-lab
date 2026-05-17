# Jenkins Runbook

Jenkins is the lab CI/CD controller. In this lab it runs in Docker Compose, outside the k3d application cluster.

That is intentional: it simulates a centralized Jenkins service in a shared tooling account that can reach the application cluster over an approved network path. Do not install Jenkins into k3d for the main lab path unless the goal is specifically to practise operating Jenkins on Kubernetes.

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
- Jenkins deploys to k3d from outside the cluster using kubeconfig, `kubectl`, and `helm`.

## Recommended Jobs

| Job | Jenkinsfile |
| --- | --- |
| `linkarooie-api` | `services/linkarooie-api/Jenkinsfile` |
| `linkarooie-analytics-worker` | `services/linkarooie-analytics-worker/Jenkinsfile` |
| `linkarooie-web` | `services/linkarooie-web/Jenkinsfile` |
| `linkarooie-media-worker` | `services/linkarooie-media-worker/Jenkinsfile` |

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
        dir('services/linkarooie-api') {
          sh './gradlew test'
        }
      }
    }

    stage('Build Jar') {
      steps {
        dir('services/linkarooie-api') {
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
- Network access to the k3d API server and Compose-backed services.

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
