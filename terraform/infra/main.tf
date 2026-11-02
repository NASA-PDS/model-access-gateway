locals {
  name_prefix = "${var.venue}-${var.application}"
  ssm_prefix  = "/pds/${var.component}"
}

# Bucket holding the LiteLLM config.yaml read by the container at startup.
# Server access logging is intentionally disabled (no log bucket is provisioned for this component).
module "config_bucket" {
  source = "git@github.com:NASA-PDS/pdc-tf-modules.git//terraform/modules/s3/bucket?ref=v0.1.0"

  bucket_name = "${local.name_prefix}-config"
  versioning  = "Enabled"

  required_tags = {
    tenant    = var.tenant
    venue     = var.venue
    component = var.component
    managedby = var.managedby
    cicd      = var.cicd
  }
}

module "config_object" {
  source = "git@github.com:NASA-PDS/pdc-tf-modules.git//terraform/modules/s3/object?ref=v0.1.0"

  bucket      = module.config_bucket.bucket_id
  key         = "config.yaml"
  source_path = "${path.module}/config.yaml"
}

# Container only: the value is set out-of-band so it never lands in Terraform state.
# See README.md ("Set the master key") for the command.
resource "aws_secretsmanager_secret" "master_key" {
  name                    = "${local.ssm_prefix}/ecs/master_key"
  description             = "LiteLLM master key (admin password and root API key) for ${local.name_prefix}."
  recovery_window_in_days = var.secret_recovery_window_days
}

# Ingress from the ECS tasks is added by the service module, which owns the tasks' security group.
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds"
  description = "Aurora PostgreSQL for ${local.name_prefix}"
  vpc_id      = var.vpc_id

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_db_subnet_group" "this" {
  name       = local.name_prefix
  subnet_ids = var.private_subnet_ids
}

resource "aws_rds_cluster" "this" {
  cluster_identifier          = local.name_prefix
  engine                      = "aurora-postgresql"
  engine_version              = var.db_engine_version
  database_name               = var.db_name
  master_username             = var.db_master_username
  manage_master_user_password = true
  storage_encrypted           = true
  backup_retention_period     = var.db_backup_retention_days
  deletion_protection         = var.db_deletion_protection
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = [aws_security_group.rds.id]

  # A unique, creation-time snapshot name keeps destroy/recreate cycles from colliding with older final snapshots.
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name_prefix}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

resource "aws_rds_cluster_instance" "writer" {
  identifier           = "${local.name_prefix}-writer"
  cluster_identifier   = aws_rds_cluster.this.id
  instance_class       = var.db_instance_class
  engine               = aws_rds_cluster.this.engine
  engine_version       = aws_rds_cluster.this.engine_version
  db_subnet_group_name = aws_db_subnet_group.this.name
  publicly_accessible  = false
}
