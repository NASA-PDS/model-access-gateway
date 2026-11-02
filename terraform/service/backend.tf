# S3 backend. Bucket, region and encryption come from cds-infra-deploy's root.hcl via Terragrunt.
terraform {
  backend "s3" {
    key          = "ai-gateway/service.tfstate"
    use_lockfile = true
  }
}
