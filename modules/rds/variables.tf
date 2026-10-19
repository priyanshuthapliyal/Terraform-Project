variable "project_name" {
  description = "The project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "private_db_subnet_ids" {
  description = "List of private database subnet IDs across at least 2 Availability Zones"
  type        = list(string)

  validation {
    condition     = length(var.private_db_subnet_ids) >= 2
    error_message = "RDS DB Subnet Group requires subnets in at least 2 Availability Zones."
  }
}

variable "db_security_group_id" {
  description = "The Security Group ID attached to the RDS database instance"
  type        = string
}

variable "engine" {
  description = "The database engine (postgres or mysql)"
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.engine)
    error_message = "Supported engines are 'postgres' or 'mysql'."
  }
}

variable "engine_version" {
  description = "The database engine version"
  type        = string
  default     = "16.3"
}

variable "instance_class" {
  description = "The compute and memory capacity instance type for RDS"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "The allocated storage in gigabytes"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "The upper limit in GB to which Amazon RDS can automatically scale the storage"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "The initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "The master username for the database"
  type        = string
  default     = "app_admin"
}

variable "multi_az" {
  description = "Specifies if the RDS instance is multi-AZ (true in prod, false in dev for cost)"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "The days to retain automated backups for (0 to 35)"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "If true, the database cannot be deleted via the AWS API or Terraform"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted"
  type        = bool
  default     = true
}
