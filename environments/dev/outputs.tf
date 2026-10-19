output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs"
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "Private database subnet IDs"
  value       = module.vpc.private_db_subnet_ids
}

output "nat_gateway_public_ips" {
  description = "Public Elastic IPs associated with the NAT Gateways"
  value       = module.vpc.nat_gateway_public_ips
}

output "alb_security_group_id" {
  description = "Application Load Balancer Security Group ID"
  value       = module.security_groups.alb_security_group_id
}

output "app_security_group_id" {
  description = "Application EC2 Security Group ID"
  value       = module.security_groups.app_security_group_id
}

output "db_security_group_id" {
  description = "Database RDS Security Group ID"
  value       = module.security_groups.db_security_group_id
}

output "iam_instance_profile_name" {
  description = "IAM Instance Profile attached to EC2 instances"
  value       = module.iam.instance_profile_name
}

output "alb_dns_name" {
  description = "The public DNS endpoint of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "target_group_arn" {
  description = "The Target Group ARN for EC2 registration"
  value       = module.alb.target_group_arn
}

output "asg_name" {
  description = "The Auto Scaling Group Name"
  value       = module.autoscaling.asg_name
}

output "launch_template_id" {
  description = "The Launch Template ID"
  value       = module.autoscaling.launch_template_id
}

output "db_instance_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = module.rds.db_instance_endpoint
}

output "db_instance_address" {
  description = "The hostname for the RDS database"
  value       = module.rds.db_instance_address
}

output "db_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret holding database credentials"
  value       = module.rds.secret_arn
}

output "sns_alerts_topic_arn" {
  description = "The ARN of the SNS topic for infrastructure alarms"
  value       = module.monitoring.sns_topic_arn
}
