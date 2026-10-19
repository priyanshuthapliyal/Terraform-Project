output "sns_topic_arn" {
  description = "The ARN of the SNS topic for infrastructure alert notifications"
  value       = aws_sns_topic.alerts.arn
}

output "alarm_arns" {
  description = "Map of CloudWatch Alarm names to their ARNs"
  value = {
    alb_target_5xx     = aws_cloudwatch_metric_alarm.alb_target_5xx.arn
    alb_unhealthy_hosts = aws_cloudwatch_metric_alarm.alb_unhealthy_hosts.arn
    asg_high_cpu       = aws_cloudwatch_metric_alarm.asg_high_cpu.arn
    rds_low_storage    = aws_cloudwatch_metric_alarm.rds_low_storage.arn
    rds_high_cpu       = aws_cloudwatch_metric_alarm.rds_high_cpu.arn
    rds_high_connections = aws_cloudwatch_metric_alarm.rds_high_connections.arn
  }
}
