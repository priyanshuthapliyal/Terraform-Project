module "vpc" {
  source = "../../modules/vpc"

  project_name             = var.project_name
  environment              = var.environment
  vpc_cidr                 = "10.1.0.0/16" # Non-overlapping CIDR block
  availability_zones_count = 2
  single_nat_gateway       = false # HA: 1 NAT Gateway per AZ
}

module "security_groups" {
  source = "../../modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  app_port     = 8080
  db_port      = 5432
}

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
}

module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  app_port              = 8080
  health_check_path     = "/"
}

module "autoscaling" {
  source = "../../modules/autoscaling"

  project_name          = var.project_name
  environment           = var.environment
  instance_type         = "t3.small"
  min_size              = 2
  desired_capacity      = 2
  max_size              = 4
  private_subnet_ids    = module.vpc.private_app_subnet_ids
  app_security_group_id = module.security_groups.app_security_group_id
  instance_profile_name = module.iam.instance_profile_name
  target_group_arn      = module.alb.target_group_arn
  app_port              = 8080
}

module "rds" {
  source = "../../modules/rds"

  project_name          = var.project_name
  environment           = var.environment
  private_db_subnet_ids = module.vpc.private_db_subnet_ids
  db_security_group_id  = module.security_groups.db_security_group_id
  engine                = "postgres"
  engine_version        = "16.3"
  instance_class        = "db.t4g.small"
  allocated_storage     = 50
  max_allocated_storage = 200
  multi_az              = true # Staging mirrors production Multi-AZ
  deletion_protection   = true
  skip_final_snapshot   = false
  backup_retention_period = 7
}

module "monitoring" {
  source = "../../modules/monitoring"

  project_name            = var.project_name
  environment             = var.environment
  asg_name                = module.autoscaling.asg_name
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  db_instance_id          = module.rds.db_instance_id
}
