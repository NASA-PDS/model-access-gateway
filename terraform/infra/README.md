# ai-gateway: infra

Config S3 bucket (via pdc-tf-modules), Aurora PostgreSQL cluster and writer, master key secret container, database security group. Publishes bucket, database and secret identifiers to SSM under `/pds/<component>/`.

See [../README.md](../README.md) for apply order, deployment commands and the smoke test. Inputs are documented in `variables.tf`; their values are set in `cds-infra-deploy` (`venues/<venue>/ai-gateway/infra/terragrunt.hcl`).
