output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "The public DNS endpoint of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "asg_name" {
  description = "The Auto Scaling Group Name"
  value       = module.autoscaling.asg_name
}

output "db_instance_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = module.rds.db_instance_endpoint
}

output "sns_alerts_topic_arn" {
  description = "The ARN of the SNS topic for infrastructure alarms"
  value       = module.monitoring.sns_topic_arn
}
