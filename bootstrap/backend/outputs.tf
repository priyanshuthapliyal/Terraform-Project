output "state_bucket_name" {
  description = "The name of the S3 bucket storing Terraform remote state"
  value       = aws_s3_bucket.state_bucket.id
}

output "state_bucket_arn" {
  description = "The ARN of the S3 state bucket"
  value       = aws_s3_bucket.state_bucket.arn
}

output "kms_key_arn" {
  description = "The ARN of the KMS key encrypting state files"
  value       = aws_kms_key.state_key.arn
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table managing state locking"
  value       = aws_dynamodb_table.locks.name
}

output "backend_config_instructions" {
  description = "Backend configuration template to paste into environments/<env>/versions.tf"
  value = <<-EOT
    # Paste into environments/<env>/versions.tf inside the terraform {} block:
    backend "s3" {
      bucket         = "${aws_s3_bucket.state_bucket.id}"
      key            = "three-tier/<env>/terraform.tfstate"
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.locks.name}"
      encrypt        = true
      kms_key_id     = "${aws_kms_key.state_key.arn}"
    }
  EOT
}
