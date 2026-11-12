resource "aws_ssm_parameter" "alb_dns_name" {
  name        = "${local.ssm_prefix}/alb/dns_name"
  type        = "String"
  value       = aws_lb.this.dns_name
  description = "DNS name of the ${local.name_prefix} load balancer."
}

resource "aws_ssm_parameter" "ecs_cluster_name" {
  name        = "${local.ssm_prefix}/ecs/cluster_name"
  type        = "String"
  value       = aws_ecs_cluster.this.name
  description = "Name of the ${local.name_prefix} ECS cluster."
}

resource "aws_ssm_parameter" "ecs_service_name" {
  name        = "${local.ssm_prefix}/ecs/service_name"
  type        = "String"
  value       = aws_ecs_service.this.name
  description = "Name of the ${local.name_prefix} ECS service."
}

output "alb_dns_name" {
  description = "DNS name of the load balancer, published to /pds/<component>/alb/dns_name."
  value       = aws_lb.this.dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster, published to /pds/<component>/ecs/cluster_name."
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Name of the ECS service, published to /pds/<component>/ecs/service_name."
  value       = aws_ecs_service.this.name
}
