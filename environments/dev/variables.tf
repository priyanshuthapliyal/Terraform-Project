variable "aws_region" {
  description = "The AWS region to deploy infrastructure into"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d{1}$", var.aws_region))
    error_message = "The aws_region must be a valid AWS region identifier (e.g., us-east-1, eu-west-1)."
  }
}

variable "project_name" {
  description = "The name of the project used for naming and resource tagging"
  type        = string
  default     = "three-tier"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "The project_name must only contain lowercase alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "The target deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment must be one of: dev, staging, prod."
  }
}
