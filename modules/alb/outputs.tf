output "alb_id" {
  description = "The ID of the Application Load Balancer"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "The ARN suffix of the ALB (used in CloudWatch alarms)"
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the load balancer (used for Route 53 alias records)"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "The ARN of the Target Group (attached to Auto Scaling Group)"
  value       = aws_lb_target_group.app.arn
}

output "target_group_arn_suffix" {
  description = "The ARN suffix of the Target Group (used in CloudWatch alarms)"
  value       = aws_lb_target_group.app.arn_suffix
}

output "target_group_name" {
  description = "The name of the Target Group"
  value       = aws_lb_target_group.app.name
}
