locals {
  prefix = "opsflow-lab"
  subnets = {
    a = { az = var.availability_zones[0], public_cidr = "10.40.0.0/24", private_cidr = "10.40.16.0/20" }
    b = { az = var.availability_zones[1], public_cidr = "10.40.1.0/24", private_cidr = "10.40.32.0/20" }
  }
}
resource "aws_vpc" "main" {
  cidr_block           = "10.40.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.prefix}-vpc" }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.prefix}-igw" }
}
resource "aws_subnet" "public" {
  for_each                = local.subnets
  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.az
  cidr_block              = each.value.public_cidr
  map_public_ip_on_launch = false
  tags = {
    Name                     = "${local.prefix}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  }
}
resource "aws_subnet" "private" {
  for_each                = local.subnets
  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.az
  cidr_block              = each.value.private_cidr
  map_public_ip_on_launch = false
  tags = {
    Name                              = "${local.prefix}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.prefix}-public" }
}
resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  for_each = local.subnets
  vpc_id   = aws_vpc.main.id
  tags     = { Name = "${local.prefix}-private-${each.key}" }
}
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
# Default security group is deliberately closed; future workloads use dedicated groups.
resource "aws_default_security_group" "closed" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.prefix}-default-closed" }
}
