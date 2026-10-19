variable "project_name" {
  description = "The project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where the ALB target group is registered"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs across at least 2 Availability Zones for ALB deployment"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "An Application Load Balancer requires at least 2 subnets in different Availability Zones."
  }
}

variable "alb_security_group_id" {
  description = "The Security Group ID attached to the ALB"
  type        = string
}

variable "app_port" {
  description = "The port on which the target EC2 application listens"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "The HTTP endpoint path for ALB target health checks"
  type        = string
  default     = "/"
}

variable "enable_deletion_protection" {
  description = "If true, deletion of the load balancer will be disabled via the AWS API"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "Optional ARN of an ACM SSL/TLS certificate for HTTPS listener. If empty, HTTP forwards directly to the target group; if provided, HTTP redirects to HTTPS."
  type        = string
  default     = ""
}
