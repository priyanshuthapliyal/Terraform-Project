variable "project_name" {
  description = "The project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "The IPv4 CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "The vpc_cidr must be a valid IPv4 CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "availability_zones_count" {
  description = "Number of Availability Zones to spread subnets across (minimum 2 for HA)"
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zones_count >= 2
    error_message = "High availability requires at least 2 Availability Zones."
  }
}

variable "single_nat_gateway" {
  description = "If true, provision a single NAT Gateway shared across all private app subnets (cost optimization for dev). If false, provision 1 NAT Gateway per AZ (production HA standard)."
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Should be true to enable DNS support in the VPC"
  type        = bool
  default     = true
}
