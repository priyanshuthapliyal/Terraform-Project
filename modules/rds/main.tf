locals {
  name_prefix     = "${var.project_name}-${var.environment}"
  parameter_group = var.engine == "postgres" ? "postgres16" : "mysql8.0"
  db_port         = var.engine == "postgres" ? 5432 : 3306
}

# ---------------------------------------------------------------------------------------------------------------------
# SECRETS MANAGEMENT: Secure Random Password & AWS Secrets Manager
# ---------------------------------------------------------------------------------------------------------------------
resource "random_password" "master_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix             = "${var.project_name}/${var.environment}/rds-"
  description             = "Master credentials for RDS ${var.project_name}-${var.environment} database"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = {
    Name = "${local.name_prefix}-rds-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    engine   = var.engine
    host     = aws_db_instance.main.address
    port     = local.db_port
    database = var.db_name
    username = var.db_username
    password = random_password.master_password.result
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# DB SUBNET GROUP (SPANS PRIVATE DATABASE SUBNETS ACROSS AZs)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name_prefix = "${local.name_prefix}-db-subnets-"
  description = "Database subnet group spanning isolated private database subnets"
  subnet_ids  = var.private_db_subnet_ids

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DB PARAMETER GROUP (ENFORCE TLS & DATABASE SETTINGS)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_db_parameter_group" "main" {
  name_prefix = "${local.name_prefix}-pg-"
  family      = local.parameter_group
  description = "Custom parameter group for ${local.name_prefix} ${var.engine}"

  dynamic "parameter" {
    for_each = var.engine == "postgres" ? [1] : []
    content {
      name  = "rds.force_ssl"
      value = "1"
    }
  }

  tags = {
    Name = "${local.name_prefix}-parameter-group"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# RDS DATABASE INSTANCE (MULTI-AZ HIGH AVAILABILITY)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier_prefix = "${local.name_prefix}-db-"

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage # Storage Auto Scaling
  storage_type          = "gp3"
  storage_encrypted     = true

  multi_az            = var.multi_az
  publicly_accessible = false

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_security_group_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  db_name  = var.db_name
  username = var.db_username
  password = random_password.master_password.result

  backup_retention_period   = var.backup_retention_period
  backup_window             = "03:00-04:00"
  maintenance_window        = "Sun:04:30-Sun:05:30"
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot     = true

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = "${local.name_prefix}-db-final-snapshot"

  lifecycle {
    ignore_changes = [
      password,
      latest_restorable_time
    ]
  }

  tags = {
    Name = "${local.name_prefix}-db"
    Tier = "Database"
  }
}
