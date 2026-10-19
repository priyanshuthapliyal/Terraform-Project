data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  bucket_name = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CUSTOMER MANAGED KMS KEY FOR TERRAFORM STATE ENCRYPTION
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_key" "state_key" {
  description             = "KMS CMK for encrypting Terraform remote state files in S3"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${local.name_prefix}-state-kms-key"
  }
}

resource "aws_kms_alias" "state_key_alias" {
  name          = "alias/${var.project_name}-terraform-state"
  target_key_id = aws_kms_key.state_key.key_id
}

# ---------------------------------------------------------------------------------------------------------------------
# S3 REMOTE STATE BUCKET
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "state_bucket" {
  bucket        = local.bucket_name
  force_destroy = false # Safety guard: Prevents catastrophic deletion of state files

  tags = {
    Name = "${local.name_prefix}-state-bucket"
  }
}

# 1. State History & Rollback: Versioning Enabled
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 2. Strong Encryption at Rest via KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.state_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true # Reduces KMS API request costs by ~99%
  }
}

# 3. Block All Public Access (Strict Zero Exposure)
resource "aws_s3_bucket_public_access_block" "state_bucket_block" {
  bucket = aws_s3_bucket.state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 4. Lifecycle Management (Prune Old State Versions After 90 Days)
resource "aws_s3_bucket_lifecycle_configuration" "state_lifecycle" {
  bucket = aws_s3_bucket.state_bucket.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# 5. Enforce TLS 1.2+ in Transit (Deny Insecure Transport)
resource "aws_s3_bucket_policy" "enforce_tls" {
  bucket = aws_s3_bucket.state_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.state_bucket.arn,
          "${aws_s3_bucket.state_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# DYNAMODB TABLE FOR DISTRIBUTED STATE LOCKING
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_dynamodb_table" "locks" {
  name         = "${var.project_name}-terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST" # On-Demand pricing (scales to zero cost when idle)
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.state_key.arn
  }

  tags = {
    Name = "${local.name_prefix}-state-locks"
  }
}
