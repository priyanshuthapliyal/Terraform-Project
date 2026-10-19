terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend "s3" {
  #   bucket         = "three-tier-tfstate-<ACCOUNT_ID>"
  #   key            = "three-tier/staging/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "three-tier-terraform-state-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "terraform-aws-3tier"
    }
  }
}
