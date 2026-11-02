# ai-gateway: service

Application load balancer, target group, ECS cluster, service and task definition, security groups, log group. Reads the values published by `infra` and `iam` from SSM and adds the ECS-to-database ingress rule to the database security group.

See [../README.md](../README.md) for apply order, deployment commands and the smoke test. Inputs are documented in `variables.tf`; their values are set in `cds-infra-deploy` (`venues/<venue>/ai-gateway/service/terragrunt.hcl`).
