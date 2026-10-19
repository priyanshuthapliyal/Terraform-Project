output "db_instance_id" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "The connection endpoint in address:port format"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "The hostname of the RDS database instance"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "The database port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "The database name"
  value       = aws_db_instance.main.db_name
}

output "secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret containing database master credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}
