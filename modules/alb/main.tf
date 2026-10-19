locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------------------------------------------------
# APPLICATION LOAD BALANCER (INTERNET-FACING)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb" "main" {
  name                       = "${local.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_security_group_id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = true

  tags = {
    Name = "${local.name_prefix}-alb"
    Tier = "Presentation"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# TARGET GROUP (FOR EC2 APP INSTANCES)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb_target_group" "app" {
  name                 = "${local.name_prefix}-tg"
  port                 = var.app_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30 # Connection draining in seconds

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-299"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name_prefix}-tg"
    Tier = "Application"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# HTTP LISTENER (PORT 80)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # If an SSL/TLS Certificate ARN is provided, redirect HTTP to HTTPS; otherwise forward directly to Target Group
  dynamic "default_action" {
    for_each = var.certificate_arn != "" ? [1] : []
    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.certificate_arn == "" ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.app.arn
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# HTTPS LISTENER (PORT 443) - OPTIONAL / HTTPS-READY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
