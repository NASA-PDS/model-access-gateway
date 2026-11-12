resource "aws_ssm_parameter" "ecs_task_role_arn" {
  name        = "${local.ssm_prefix}/iam/ecs_task_role_arn"
  type        = "String"
  value       = aws_iam_role.ecs_task.arn
  description = "ARN of the ECS task role."
}

resource "aws_ssm_parameter" "ecs_task_execution_role_arn" {
  name        = "${local.ssm_prefix}/iam/ecs_task_execution_role_arn"
  type        = "String"
  value       = aws_iam_role.ecs_task_execution.arn
  description = "ARN of the ECS task execution role."
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role, published to /pds/<component>/iam/ecs_task_role_arn."
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role, published to /pds/<component>/iam/ecs_task_execution_role_arn."
  value       = aws_iam_role.ecs_task_execution.arn
}
