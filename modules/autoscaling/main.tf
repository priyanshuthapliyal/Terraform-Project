data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------------------------------------------------
# LAUNCH TEMPLATE (EC2 SPECIFICATION & METADATA HARDENING)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_security_group_id]
  }

  # Security Hardening: Enforce IMDSv2 (Session token mandatory)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              set -xe
              dnf update -y
              dnf install -y python3

              # Create a lightweight Python HTTP service
              cat << 'PYEOF' > /opt/app.py
              import http.server
              import socketserver
              import urllib.request
              import json

              PORT = ${var.app_port}

              class Handler(http.server.SimpleHTTPRequestHandler):
                  def do_GET(self):
                      # Fetch IMDSv2 token
                      req = urllib.request.Request("http://169.254.169.254/latest/api/token", headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"}, method="PUT")
                      try:
                          with urllib.request.urlopen(req) as resp:
                              token = resp.read().decode()
                          
                          # Fetch instance metadata
                          meta_req = urllib.request.Request("http://169.254.169.254/latest/meta-data/instance-id", headers={"X-aws-ec2-metadata-token": token})
                          with urllib.request.urlopen(meta_req) as resp:
                              instance_id = resp.read().decode()
                          
                          az_req = urllib.request.Request("http://169.254.169.254/latest/meta-data/placement/availability-zone", headers={"X-aws-ec2-metadata-token": token})
                          with urllib.request.urlopen(az_req) as resp:
                              az = resp.read().decode()
                      except Exception as e:
                          instance_id = "local"
                          az = "unknown"

                      self.send_response(200)
                      self.send_header("Content-type", "application/json")
                      self.end_headers()
                      payload = {
                          "status": "healthy",
                          "project": "${var.project_name}",
                          "environment": "${var.environment}",
                          "instance_id": instance_id,
                          "availability_zone": az
                      }
                      self.wfile.write(json.dumps(payload, indent=2).encode('utf-8'))

              with socketserver.TCPServer(("", PORT), Handler) as httpd:
                  httpd.serve_forever()
              PYEOF

              # Systemd service unit
              cat << 'SVCEOF' > /etc/systemd/system/three-tier-app.service
              [Unit]
              Description=Three Tier Web Application
              After=network.target

              [Service]
              Type=simple
              User=root
              WorkingDirectory=/opt
              ExecStart=/usr/bin/python3 /opt/app.py
              Restart=always
              RestartSec=5

              [Install]
              WantedBy=multi-user.target
              SVCEOF

              systemctl daemon-reload
              systemctl enable three-tier-app.service
              systemctl start three-tier-app.service
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-app-instance"
      Tier = "Application"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# AUTO SCALING GROUP (MULTI-AZ HIGH AVAILABILITY)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_autoscaling_group" "app" {
  name_prefix         = "${local.name_prefix}-asg-"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]

  # Use ELB health checks so instances with crashed web servers are replaced automatically
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Graceful rolling instance refresh when Launch Template updates
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
    triggers = ["tag"]
  }

  lifecycle {
    create_before_destroy = true
    # Prevent Terraform from reverting autoscaling capacity changes during dynamic load
    ignore_changes = [desired_capacity]
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "Application"
    propagate_at_launch = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# TARGET TRACKING SCALING POLICY (DYNAMIC LOAD MANAGEMENT)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${local.name_prefix}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
