output "instance_profile_name" {
  description = "The name of the IAM instance profile to attach to Launch Template"
  value       = aws_iam_instance_profile.ec2.name
}

output "instance_profile_arn" {
  description = "The ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2.arn
}

output "role_name" {
  description = "The name of the IAM execution role"
  value       = aws_iam_role.ec2.name
}

output "role_arn" {
  description = "The ARN of the IAM execution role"
  value       = aws_iam_role.ec2.arn
}
