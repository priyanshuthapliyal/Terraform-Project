locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# =====================================================================================================================
# TIER 1: APPLICATION LOAD BALANCER (ALB) SECURITY GROUP
# =====================================================================================================================
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group controlling public inbound traffic to the ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-alb-sg"
    Tier = "Presentation"
  }
}

# Allow HTTP from Internet (for redirect to HTTPS or direct dev testing)
resource "aws_vpc_security_group_ingress_rule" "alb_http_inbound" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP traffic from the public Internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# Allow HTTPS from Internet
resource "aws_vpc_security_group_ingress_rule" "alb_https_inbound" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS traffic from the public Internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Forward traffic ONLY to Application EC2 instances on app_port
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Allow ALB to forward traffic to EC2 application instances"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

# =====================================================================================================================
# TIER 2: APPLICATION EC2 SECURITY GROUP
# =====================================================================================================================
resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Security group controlling traffic to and from EC2 application instances"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-app-sg"
    Tier = "Application"
  }
}

# Allow traffic ONLY from ALB security group on app_port
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Allow inbound application traffic strictly from ALB security group"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

# Outbound to RDS Database on db_port
resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "Allow application instances to query the RDS database"
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
}

# Outbound HTTPS for package updates, SSM Agent, and AWS APIs via NAT Gateway
resource "aws_vpc_security_group_egress_rule" "app_https_outbound" {
  security_group_id = aws_security_group.app.id
  description       = "Allow outbound HTTPS for OS patches, AWS SSM, and CloudWatch agent"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Outbound HTTP for package repositories (e.g. Amazon Linux yum mirrors)
resource "aws_vpc_security_group_egress_rule" "app_http_outbound" {
  security_group_id = aws_security_group.app.id
  description       = "Allow outbound HTTP for package repository mirrors via NAT Gateway"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# =====================================================================================================================
# TIER 3: DATABASE (RDS) SECURITY GROUP
# =====================================================================================================================
resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "Security group controlling access to the RDS database instance"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-db-sg"
    Tier = "Database"
  }
}

# Allow database connections ONLY from Application Security Group
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "Allow database queries strictly from Application EC2 security group"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
}
