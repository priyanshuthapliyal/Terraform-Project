output "alb_security_group_id" {
  description = "The ID of the Application Load Balancer security group"
  value       = aws_security_group.alb.id
}

output "alb_security_group_arn" {
  description = "The ARN of the Application Load Balancer security group"
  value       = aws_security_group.alb.arn
}

output "app_security_group_id" {
  description = "The ID of the EC2 Application security group"
  value       = aws_security_group.app.id
}

output "app_security_group_arn" {
  description = "The ARN of the EC2 Application security group"
  value       = aws_security_group.app.arn
}

output "db_security_group_id" {
  description = "The ID of the RDS Database security group"
  value       = aws_security_group.db.id
}

output "db_security_group_arn" {
  description = "The ARN of the RDS Database security group"
  value       = aws_security_group.db.arn
}
