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
  description = "ID of the VPC that hosts the database."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID beginning with vpc-."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (at least two, in different AZs) for the database subnet group."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2 && alltrue([for id in var.private_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id))])
    error_message = "private_subnet_ids must contain at least two subnet IDs beginning with subnet-."
  }
}

variable "db_engine_version" {
  description = "Aurora PostgreSQL engine version."
  type        = string
  default     = "17"
}

variable "db_instance_class" {
  description = "Instance class of the Aurora writer instance."
  type        = string
  default     = "db.t4g.medium"
}

variable "db_name" {
  description = "Name of the initial database created in the cluster."
  type        = string
  default     = "litellm"
}

variable "db_master_username" {
  description = "Master username of the Aurora cluster. The password is generated and rotated by RDS in Secrets Manager."
  type        = string
  default     = "litellm"
}

variable "db_backup_retention_days" {
  description = "Number of days automated Aurora backups are retained."
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Whether deletion protection is enabled on the Aurora cluster. Set to false before terraform destroy."
  type        = bool
  default     = true
}

variable "secret_recovery_window_days" {
  description = "Recovery window, in days, applied when the master key secret is deleted (0 deletes immediately, otherwise 7 to 30)."
  type        = number
  default     = 7
}
