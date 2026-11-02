data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ARNs are computed from the naming convention, not read from live resources, so this module
# can be applied before (or independently of) the infra and service modules (P30).
locals {
  name_prefix = "${var.venue}-${var.application}"
  ssm_prefix  = "/pds/${var.component}"
  partition   = data.aws_partition.current.partition
  account_id  = data.aws_caller_identity.current.account_id

  config_bucket_arn  = "arn:${local.partition}:s3:::${local.name_prefix}-config"
  master_key_arn     = "arn:${local.partition}:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.ssm_prefix}/ecs/master_key-*"
  # RDS auto-generates the secret name (rds!cluster-<uuid>) so the exact ARN is unknown until the
  # cluster exists. The wildcard is scoped to this account and region; tighten after first apply
  # by replacing with the actual ARN from aws_rds_cluster.master_user_secret[0].secret_arn via SSM.
  rds_managed_secret = "arn:${local.partition}:secretsmanager:${var.aws_region}:${local.account_id}:secret:rds!cluster-*"
  log_group_arn      = "arn:${local.partition}:logs:${var.aws_region}:${local.account_id}:log-group:/ecs/${local.name_prefix}"

  ecs_tasks_assume_role = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_execution" {
  name                 = "${local.name_prefix}-ecs-task-execution"
  assume_role_policy   = local.ecs_tasks_assume_role
  permissions_boundary = var.permission_boundary_arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Lets ECS inject LITELLM_MASTER_KEY into the container.
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "master-key-secret"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = local.master_key_arn
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task" {
  name                 = "${local.name_prefix}-ecs-task"
  assume_role_policy   = local.ecs_tasks_assume_role
  permissions_boundary = var.permission_boundary_arn
}

resource "aws_iam_role_policy" "ecs_task" {
  name = "ai-gateway-runtime"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadDatabaseCredentials"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = local.rds_managed_secret
      },
      {
        Sid      = "ReadLiteLLMConfig"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${local.config_bucket_arn}/config.yaml"
      },
      {
        Sid    = "WriteLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${local.log_group_arn}:*"
      },
      {
        Sid    = "InvokeBedrockModels"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = concat(
          ["arn:${local.partition}:bedrock:${var.aws_region}:${local.account_id}:inference-profile/*"],
          [for id in var.bedrock_model_ids : "arn:${local.partition}:bedrock:*::foundation-model/${id}"]
        )
      }
    ]
  })
}
