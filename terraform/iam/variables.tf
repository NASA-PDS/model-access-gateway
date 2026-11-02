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

variable "permission_boundary_arn" {
  description = "ARN of the IAM permissions boundary policy to attach to the roles, or null when none is required."
  type        = string
  default     = null
}

variable "bedrock_model_ids" {
  description = "Bedrock foundation model IDs (without ARN prefix) the task role may invoke, directly or through inference profiles."
  type        = list(string)
  default = [
    "anthropic.claude-3-7-sonnet-20250219-v1:0",
    "anthropic.claude-sonnet-4-5-20250929-v1:0",
    "anthropic.claude-opus-4-5-20251101-v1:0",
    "anthropic.claude-haiku-4-5-20251001-v1:0",
    "anthropic.claude-sonnet-4-6",
    "anthropic.claude-sonnet-5-5",
    "anthropic.claude-opus-5-5",
    "anthropic.claude-fable-5-1",
  ]
}
