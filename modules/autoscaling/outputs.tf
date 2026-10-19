output "asg_id" {
  description = "The Auto Scaling Group ID"
  value       = aws_autoscaling_group.app.id
}

output "asg_name" {
  description = "The Auto Scaling Group Name (used for CloudWatch alarms and scaling policies)"
  value       = aws_autoscaling_group.app.name
}

output "asg_arn" {
  description = "The Auto Scaling Group ARN"
  value       = aws_autoscaling_group.app.arn
}

output "launch_template_id" {
  description = "The Launch Template ID"
  value       = aws_launch_template.app.id
}

output "launch_template_latest_version" {
  description = "The latest version of the Launch Template"
  value       = aws_launch_template.app.latest_version
}
