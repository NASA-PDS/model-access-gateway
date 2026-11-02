# ai-gateway: iam

ECS task execution role and ECS task role. Role ARNs are computed from the naming convention, so this module has no dependency on the others. Publishes the role ARNs to SSM under `/pds/<component>/iam/`.

See [../README.md](../README.md) for apply order, deployment commands and the smoke test. Inputs are documented in `variables.tf`; their values are set in `cds-infra-deploy` (`venues/<venue>/ai-gateway/iam/terragrunt.hcl`).
