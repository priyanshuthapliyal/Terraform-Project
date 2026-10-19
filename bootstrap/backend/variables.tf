variable "aws_region" {
  description = "The AWS region to deploy the remote state infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The project name prefix"
  type        = string
  default     = "three-tier"
}

variable "environment" {
  description = "The environment designation for shared resources"
  type        = string
  default     = "shared"
}
