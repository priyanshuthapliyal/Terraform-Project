variable "aws_region" {
  description = "The AWS region to deploy infrastructure into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project used for naming and resource tagging"
  type        = string
  default     = "three-tier"
}

variable "environment" {
  description = "The target deployment environment"
  type        = string
  default     = "prod"
}
