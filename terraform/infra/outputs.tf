output "config_bucket_name" {
  description = "Name of the S3 bucket holding the LiteLLM config.yaml."
  value       = module.config_bucket.bucket_name
}

output "db_endpoint" {
  description = "Writer endpoint of the Aurora cluster."
  value       = aws_rds_cluster.this.endpoint
}

output "db_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager secret holding the database master credentials."
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}

output "master_key_secret_name" {
  description = "Name of the Secrets Manager secret that must be populated with the LiteLLM master key."
  value       = aws_secretsmanager_secret.master_key.name
}

output "ssm_parameter_names" {
  description = "SSM parameter names published for the iam and service modules."
  value       = [for p in aws_ssm_parameter.published : p.name]
}
