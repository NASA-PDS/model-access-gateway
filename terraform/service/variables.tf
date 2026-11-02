variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-west-2"
}

variable "tenant" {
  description = "Owner discipline node (tag value)."
  type        = string

  validation {
    condition     = contains(["en", "img", "atm", "sbn"], var.tenant)
    error_message = "tenant must be one of: en, img, atm, sbn."
  }
}

variable "venue" {
  description = "Full venue identifier, used as the resource name prefix and the venue tag (pds-cds-dev, pds-cds-test or pds-cds-prod)."
  type        = string

  validation {
    condition     = contains(["pds-cds-dev", "pds-cds-test", "pds-cds-prod"], var.venue)
    error_message = "venue must be one of: pds-cds-dev, pds-cds-test, pds-cds-prod."
  }
}

variable "component" {
  description = "Component name (tag value and SSM/Secrets Manager path segment). Matches the GitHub repository name."
  type        = string
}

variable "application" {
  description = "Application name used to build resource names, as <venue>-<application>."
  type        = string
  default     = "ai-gateway"
}

variable "managedby" {
  description = "Email address of the person (or team distribution list when cicd is cd) managing the resources."
  type        = string
}

variable "cicd" {
  description = "Deployment method tag."
  type        = string
  default     = "iac"

  validation {
    condition     = contains(["con", "cli", "iac", "manual", "cd"], var.cicd)
    error_message = "cicd must be one of: con, cli, iac, manual, cd."
  }
}

variable "vpc_id" {
  description = "ID of the VPC hosting the load balancer and ECS tasks."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID beginning with vpc-."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the ECS tasks (no public IP is assigned)."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 1 && alltrue([for id in var.private_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id))])
    error_message = "private_subnet_ids must contain at least one subnet ID beginning with subnet-."
  }
}

variable "alb_subnet_ids" {
  description = "Subnet IDs (in at least two AZs) for the load balancer: public subnets when alb_internal is false, otherwise private."
  type        = list(string)

  validation {
    condition     = length(var.alb_subnet_ids) >= 2 && alltrue([for id in var.alb_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id))])
    error_message = "alb_subnet_ids must contain at least two subnet IDs beginning with subnet-."
  }
}

variable "alb_internal" {
  description = "Whether the load balancer is internal (true) or internet-facing (false)."
  type        = bool
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the load balancer on port 80 (for example the JPLnet ranges)."
  type        = list(string)

  validation {
    condition     = length(var.alb_ingress_cidr_blocks) > 0 && alltrue([for c in var.alb_ingress_cidr_blocks : can(cidrhost(c, 0))])
    error_message = "alb_ingress_cidr_blocks must be a non-empty list of valid CIDR blocks."
  }
}

variable "alb_idle_timeout_seconds" {
  description = "Load balancer idle timeout; long enough for slow streamed model responses."
  type        = number
  default     = 300
}

variable "container_image" {
  description = "Container image for the LiteLLM service, including tag (built from the docker/ directory of this repository)."
  type        = string
}

variable "cpu_architecture" {
  description = "CPU architecture of the container image (X86_64 or ARM64)."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

variable "task_cpu" {
  description = "CPU units for the ECS Fargate task (1024 = 1 vCPU)."
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Memory in MiB for the ECS Fargate task."
  type        = number
  default     = 3072
}

variable "desired_count" {
  description = "Desired number of running tasks."
  type        = number
  default     = 1
}

variable "health_check_grace_period_seconds" {
  description = "Seconds ECS ignores load balancer health checks after a task starts, to cover database migrations on first boot."
  type        = number
  default     = 180
}

variable "log_retention_days" {
  description = "Retention, in days, of the container log group."
  type        = number
  default     = 30
}
