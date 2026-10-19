variable "project_name" {
  description = "The project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where the security groups will be created"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "The vpc_id must be a valid AWS VPC identifier starting with 'vpc-'."
  }
}

variable "app_port" {
  description = "The port on which the application EC2 instances receive traffic from the ALB"
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port > 0 && var.app_port <= 65535
    error_message = "The app_port must be a valid TCP port number (1-65535)."
  }
}

variable "db_port" {
  description = "The port on which the RDS database accepts connections (5432 for PostgreSQL, 3306 for MySQL)"
  type        = number
  default     = 5432

  validation {
    condition     = var.db_port > 0 && var.db_port <= 65535
    error_message = "The db_port must be a valid TCP port number (1-65535)."
  }
}
