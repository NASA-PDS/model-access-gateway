# Cross-component interface (P13/P26): the iam and service modules read these instead of this module's state.
locals {
  published = {
    "s3/config_bucket_name"     = module.config_bucket.bucket_name
    "s3/config_bucket_arn"      = module.config_bucket.bucket_arn
    "rds/db_endpoint"           = aws_rds_cluster.this.endpoint
    "rds/db_name"               = var.db_name
    "rds/db_secret_arn"         = aws_rds_cluster.this.master_user_secret[0].secret_arn
    "rds/db_security_group_id"  = aws_security_group.rds.id
    "ecs/master_key_secret_arn" = aws_secretsmanager_secret.master_key.arn
  }
}

resource "aws_ssm_parameter" "published" {
  for_each = local.published

  name        = "${local.ssm_prefix}/${each.key}"
  type        = "String"
  value       = each.value
  description = "Published by the ${var.component} infra module."
}
