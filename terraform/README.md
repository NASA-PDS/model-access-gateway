# ai-gateway Terraform

Deploys the LiteLLM proxy ("ai-gateway") that fronts Amazon Bedrock models for developer tools such as Claude Code.

Resources are named `<venue>-<application>[-<purpose>]`, for example `pds-cds-dev-ai-gateway`. Shared values are published to SSM under `/pds/<component>/<service>/<parameter_name>`, and the LiteLLM master key lives in Secrets Manager at `/pds/<component>/ecs/master_key`. `<component>` is the GitHub repository name (`ai-gateway`).

| Root module | Owns | State key |
|---|---|---|
| `infra/` | Config S3 bucket, Aurora PostgreSQL, master key secret container, database security group | `ai-gateway/infra.tfstate` |
| `iam/` | ECS task and task-execution roles (IAM is isolated per P19) | `ai-gateway/iam.tfstate` |
| `service/` | ALB, target group, ECS cluster/service/task definition, security groups, log group | `ai-gateway/service.tfstate` |

Apply order: `infra`, `iam`, then `service`. Modules exchange values through SSM, never through state.

## Deploy

All variable values live in the Terragrunt configuration in `cds-infra-deploy` (`venues/<venue>/ai-gateway/`), not in this repository. The S3 backend settings come from that repository's `root.hcl`.

```bash
cd $CDS_INFRA_DEPLOY_DIR/venues/dev/ai-gateway
terragrunt run --all plan
terragrunt run --all apply
```

To work on a single module, run `terragrunt plan` / `terragrunt apply` from `venues/dev/ai-gateway/<module>`.

## Set the master key

Terraform creates the Secrets Manager secret but not its value, so the key never enters Terraform state. After applying `infra`, and before applying `service`:

```bash
aws secretsmanager put-secret-value \
  --secret-id /pds/ai-gateway/ecs/master_key \
  --secret-string "sk-$(openssl rand -hex 24)"
```

This is also the `admin` password for the LiteLLM UI.

## Smoke test

After `service` is applied (the first start applies database migrations and can take a few minutes):

```bash
bash scripts/smoke-test.sh dev
```

## Destroy and recreate

`infra` enables Aurora deletion protection and takes a final snapshot on delete. Set `db_deletion_protection = false` and apply before `terraform destroy`. Secrets are deleted with a recovery window (`secret_recovery_window_days`, default 7); set it to `0` before destroying if the name must be reused immediately.
