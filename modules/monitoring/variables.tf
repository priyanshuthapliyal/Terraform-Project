variable "project_name" {
  description = "The project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "asg_name" {
  description = "The name of the Auto Scaling Group to monitor"
  type        = string
}

variable "alb_arn_suffix" {
  description = "The ARN suffix of the Application Load Balancer for CloudWatch metrics"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "The ARN suffix of the ALB Target Group for CloudWatch metrics"
  type        = string
}

variable "db_instance_id" {
  description = "The RDS Database Instance identifier to monitor"
  type        = string
}

variable "notification_email" {
  description = "Optional email address to receive SNS alert notifications"
  type        = string
  default     = ""
}
