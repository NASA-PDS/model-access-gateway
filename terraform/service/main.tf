locals {
  name_prefix  = "${var.venue}-${var.application}"
  ssm_prefix   = "/pds/${var.component}"
  litellm_port = 4000

  # Values published by the infra and iam modules.
  upstream_names = toset([
    "s3/config_bucket_name",
    "rds/db_endpoint",
    "rds/db_name",
    "rds/db_secret_arn",
    "rds/db_security_group_id",
    "ecs/master_key_secret_arn",
    "iam/ecs_task_role_arn",
    "iam/ecs_task_execution_role_arn",
  ])
  upstream = { for k, p in data.aws_ssm_parameter.upstream : k => p.insecure_value }
}

data "aws_ssm_parameter" "upstream" {
  for_each = local.upstream_names

  name = "${local.ssm_prefix}/${each.key}"
}

# Load balancer: reachable only from the allowed CIDR blocks, forwards to the tasks on the LiteLLM port.
# TODO: switch to HTTPS:443 and restrict to the CloudFront managed prefix list once CloudFront/DNS is in place.
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "HTTP access to the ${local.name_prefix} load balancer"
  vpc_id      = var.vpc_id

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset(var.alb_ingress_cidr_blocks)

  security_group_id = aws_security_group.alb.id
  description       = "HTTP from ${each.key}"
  cidr_ipv4         = each.key
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To the ECS tasks"
  referenced_security_group_id = aws_security_group.ecs_task.id
  ip_protocol                  = "tcp"
  from_port                    = local.litellm_port
  to_port                      = local.litellm_port
}

resource "aws_security_group" "ecs_task" {
  name        = "${local.name_prefix}-ecs-task"
  description = "${local.name_prefix} ECS tasks"
  vpc_id      = var.vpc_id

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_task_from_alb" {
  security_group_id            = aws_security_group.ecs_task.id
  description                  = "LiteLLM port from the load balancer"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = local.litellm_port
  to_port                      = local.litellm_port
}

# Tasks need outbound access to Bedrock, Secrets Manager, S3, the image registry and the database.
resource "aws_vpc_security_group_egress_rule" "ecs_task_all" {
  security_group_id = aws_security_group.ecs_task.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Added to the database security group owned by the infra module.
resource "aws_vpc_security_group_ingress_rule" "db_from_ecs_task" {
  security_group_id            = local.upstream["rds/db_security_group_id"]
  description                  = "PostgreSQL from the ${local.name_prefix} ECS tasks"
  referenced_security_group_id = aws_security_group.ecs_task.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_lb" "this" {
  name                       = local.name_prefix
  internal                   = var.alb_internal
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.alb_subnet_ids
  idle_timeout               = var.alb_idle_timeout_seconds
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "this" {
  name        = local.name_prefix
  port        = local.litellm_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  # /health/readiness is unauthenticated and cheap. Do not point the health check at /health:
  # it calls every configured model and incurs Bedrock costs.
  health_check {
    path                = "/health/readiness"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_cluster" "this" {
  name = local.name_prefix
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.name_prefix
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = local.upstream["iam/ecs_task_execution_role_arn"]
  task_role_arn            = local.upstream["iam/ecs_task_role_arn"]

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([
    {
      name      = "litellm"
      image     = var.container_image
      essential = true

      portMappings = [
        { containerPort = local.litellm_port, protocol = "tcp" }
      ]

      environment = [
        { name = "DB_SECRET_ARN", value = local.upstream["rds/db_secret_arn"] },
        { name = "DB_HOST", value = local.upstream["rds/db_endpoint"] },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_NAME", value = local.upstream["rds/db_name"] },
        { name = "LITELLM_CONFIG_BUCKET_NAME", value = local.upstream["s3/config_bucket_name"] },
        { name = "LITELLM_CONFIG_BUCKET_OBJECT_KEY", value = "config.yaml" },
        # boto3 uses this for Bedrock calls; removes the need to hardcode region in config.yaml.
        { name = "AWS_DEFAULT_REGION", value = var.aws_region },
        # Safe: ecs_task SG only allows ingress from the ALB SG, so the ALB is always the XFF source.
        { name = "FORWARDED_ALLOW_IPS", value = "*" }
      ]

      secrets = [
        { name = "LITELLM_MASTER_KEY", valueFrom = local.upstream["ecs/master_key_secret_arn"] }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "litellm"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "this" {
  name                              = local.name_prefix
  cluster                           = aws_ecs_cluster.this.id
  task_definition                   = aws_ecs_task_definition.this.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "litellm"
    container_port   = local.litellm_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http, aws_vpc_security_group_ingress_rule.db_from_ecs_task]
}
