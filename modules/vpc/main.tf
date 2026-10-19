data "aws_availability_zones" "available" {
  state = "available"

  # Exclude Local Zones and Wavelength Zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  azs         = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_count)
  nat_count   = var.single_nat_gateway ? 1 : length(local.azs)
}

# ---------------------------------------------------------------------------------------------------------------------
# VPC & INTERNET GATEWAY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SUBNETS (3 TIERS ACROSS AZs)
# ---------------------------------------------------------------------------------------------------------------------

# Tier 1: Public Subnets (ALB & NAT Gateways)
resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${local.name_prefix}-public-subnet-${count.index + 1}-${local.azs[count.index]}"
    Tier                     = "Public"
    "kubernetes.io/role/elb" = "1"
  }
}

# Tier 2: Private Application Subnets (EC2 Auto Scaling Group)
resource "aws_subnet" "private_app" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 11)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${local.name_prefix}-private-app-subnet-${count.index + 1}-${local.azs[count.index]}"
    Tier                              = "Private-Application"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Tier 3: Private Database Subnets (Amazon RDS Multi-AZ)
resource "aws_subnet" "private_db" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 21)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-private-db-subnet-${count.index + 1}-${local.azs[count.index]}"
    Tier = "Private-Database"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# NAT GATEWAYS & ELASTIC IPS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "nat" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${local.name_prefix}-nat-gw-${count.index + 1}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ROUTE TABLES & ASSOCIATIONS
# ---------------------------------------------------------------------------------------------------------------------

# 1. Public Route Table (Routes default traffic 0.0.0.0/0 to Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 2. Private Application Route Tables (Routes default traffic 0.0.0.0/0 to NAT Gateway)
resource "aws_route_table" "private_app" {
  count  = local.nat_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "${local.name_prefix}-private-app-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private_app" {
  count     = length(aws_subnet.private_app)
  subnet_id = aws_subnet.private_app[count.index].id
  # If single NAT gateway is used, associate all private app subnets to the single route table;
  # otherwise, associate each subnet to its AZ-specific route table.
  route_table_id = var.single_nat_gateway ? aws_route_table.private_app[0].id : aws_route_table.private_app[count.index].id
}

# 3. Private Database Route Table (Completely Isolated: No route to Internet or NAT Gateway)
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-private-db-rt"
  }
}

resource "aws_route_table_association" "private_db" {
  count          = length(aws_subnet.private_db)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}
