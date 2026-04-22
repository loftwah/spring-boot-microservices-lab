# Terraform Runbook

Terraform is not required for the current local lab, but it becomes important when you move these ideas to AWS.

## What Terraform Would Own In AWS

```text
VPC and subnets
EKS cluster
RDS Postgres
ElastiCache Redis
MSK Kafka
S3 buckets
IAM roles and policies
KMS keys
ECR repositories
Route53 records
Security groups
```

It should not own individual Kubernetes app releases at first. Keep those in Helm/Jenkins until you intentionally practise Terraform-managed Kubernetes resources.

## Install

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version
```

## Basic Workflow

```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
terraform destroy
```

## Minimal Local Practice

Create a scratch directory outside the app path:

```bash
mkdir -p /tmp/tf-lab
cd /tmp/tf-lab
```

Create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.6.0"
}

variable "environment" {
  type    = string
  default = "lab"
}

output "environment" {
  value = var.environment
}
```

Run:

```bash
terraform init
terraform plan
terraform apply
terraform output
terraform destroy
```

## State

State maps real resources to Terraform configuration.

Local state:

```text
terraform.tfstate
```

Remote state in real environments is usually S3 plus DynamoDB locking on AWS.

## Modules

A useful AWS shape later:

```text
infra/
  envs/
    dev/
      main.tf
      variables.tf
      outputs.tf
  modules/
    network/
    eks/
    rds/
    redis/
    kafka/
    s3/
    vault/
```

## Things To Break And Fix

1. Change an output and inspect the plan.
2. Create a variable with no value and pass it using `-var`.
3. Run `terraform fmt` on badly formatted code.
4. Move a resource address and learn about `terraform state mv`.

## Know As A DevOps Engineer

- Terraform manages infrastructure lifecycle.
- State is sensitive and important.
- Plans should be reviewed before apply.
- Providers talk to APIs.
- Modules are reusable units, not magic.
- Avoid mixing too many ownership models for the same resource.
