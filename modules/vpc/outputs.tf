output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets (used by ALB and NAT Gateways)"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidr_blocks" {
  description = "List of CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_app_subnet_ids" {
  description = "List of IDs of the private application subnets (used by EC2 ASG)"
  value       = aws_subnet.private_app[*].id
}

output "private_app_subnet_cidr_blocks" {
  description = "List of CIDR blocks of the private application subnets"
  value       = aws_subnet.private_app[*].cidr_block
}

output "private_db_subnet_ids" {
  description = "List of IDs of the private database subnets (used by RDS Subnet Group)"
  value       = aws_subnet.private_db[*].id
}

output "private_db_subnet_cidr_blocks" {
  description = "List of CIDR blocks of the private database subnets"
  value       = aws_subnet.private_db[*].cidr_block
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = aws_nat_gateway.nat[*].id
}

output "nat_gateway_public_ips" {
  description = "List of Elastic Public IP addresses allocated for the NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "availability_zones" {
  description = "List of Availability Zones used for subnet allocation"
  value       = local.azs
}
