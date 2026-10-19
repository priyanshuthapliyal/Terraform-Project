variable "project_name" {
  description = "The project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the application tier"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 2

  validation {
    condition     = var.min_size >= 1
    error_message = "Minimum ASG size must be at least 1."
  }
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 2

  validation {
    condition     = var.desired_capacity >= 1
    error_message = "Desired ASG capacity must be at least 1."
  }
}

variable "max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 4

  validation {
    condition     = var.max_size >= 2
    error_message = "Maximum ASG size must be at least 2 for scaling headroom."
  }
}

variable "private_subnet_ids" {
  description = "List of private application subnet IDs where EC2 instances will be launched"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "High availability requires at least 2 private application subnets."
  }
}

variable "app_security_group_id" {
  description = "The Security Group ID attached to EC2 application instances"
  type        = string
}

variable "instance_profile_name" {
  description = "The IAM instance profile name for EC2 role attachment"
  type        = string
}

variable "target_group_arn" {
  description = "The ARN of the ALB Target Group to attach the Auto Scaling Group to"
  type        = string
}

variable "app_port" {
  description = "The application HTTP port"
  type        = number
  default     = 8080
}
