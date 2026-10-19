plugin "aws" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  module = true
  force  = false
}

# Enforce AWS best practices and catch invalid instance types or deprecated arguments
rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_db_instance_invalid_type" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_naming_conventions" {
  enabled = true
}
