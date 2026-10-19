locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------------------------------------------------
# TRUST RELATIONSHIP (Assume Role Policy for EC2)
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "ec2" {
  name                 = "${local.name_prefix}-ec2-role"
  assume_role_policy   = data.aws_iam_policy_document.ec2_assume_role.json
  description          = "Least privilege execution role for 3-tier EC2 application instances"
  max_session_duration = 3600

  tags = {
    Name = "${local.name_prefix}-ec2-role"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACHED MANAGED POLICIES
# ---------------------------------------------------------------------------------------------------------------------

# 1. AWS Systems Manager (SSM) Session Manager: Eliminates need for SSH Port 22 or Bastion Hosts
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 2. CloudWatch Agent: Allows publishing detailed metrics and log streams to CloudWatch
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ---------------------------------------------------------------------------------------------------------------------
# CUSTOM LEAST-PRIVILEGE POLICY: Secrets Manager Read Access
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "secrets_access" {
  statement {
    sid    = "AllowAppReadDatabaseSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    # Restrict read access strictly to secrets belonging to this project and environment
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/*"
    ]
  }
}

resource "aws_iam_policy" "secrets_access" {
  name        = "${local.name_prefix}-secrets-read-policy"
  description = "Allows EC2 application instances to fetch runtime credentials from AWS Secrets Manager"
  policy      = data.aws_iam_policy_document.secrets_access.json

  tags = {
    Name = "${local.name_prefix}-secrets-read-policy"
  }
}

resource "aws_iam_role_policy_attachment" "secrets_access" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM INSTANCE PROFILE (The bridge between IAM Role and EC2 Instance)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name = "${local.name_prefix}-ec2-instance-profile"
  }
}
