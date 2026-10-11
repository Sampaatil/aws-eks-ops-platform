data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = var.state_bucket, key = var.phase5_state_key, region = var.aws_region
  }
}
locals {
  name         = "opsflow-lab"
  infra        = data.terraform_remote_state.eks.outputs
  repositories = local.infra.ecr_repository_urls
}
data "aws_eks_cluster" "existing" {
  name = local.infra.cluster_name
}
data "aws_subnet" "public" {
  id = local.infra.public_subnet_ids[0]
}
resource "aws_subnet" "deploy" {
  vpc_id                  = local.infra.vpc_id
  cidr_block              = var.deploy_subnet_cidr
  availability_zone       = data.aws_subnet.public.availability_zone
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.name}-ci-deploy"
  }
}
resource "aws_eip" "nat" {
  domain = "vpc"
}
resource "aws_nat_gateway" "deploy" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.aws_subnet.public.id
  tags = {
    Name = "${local.name}-ci-nat"
  }
}
resource "aws_route_table" "deploy" {
  vpc_id = local.infra.vpc_id
}
resource "aws_route" "egress" {
  route_table_id         = aws_route_table.deploy.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.deploy.id
}
resource "aws_route_table_association" "deploy" {
  subnet_id      = aws_subnet.deploy.id
  route_table_id = aws_route_table.deploy.id
}
resource "aws_security_group" "deploy" {
  name        = "${local.name}-ci-deploy"
  vpc_id      = local.infra.vpc_id
  description = "CodeBuild CD egress, no inbound access"
}
resource "aws_vpc_security_group_egress_rule" "deploy" {
  security_group_id = aws_security_group.deploy.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
resource "aws_vpc_security_group_ingress_rule" "eks_from_deploy" {
  security_group_id            = data.aws_eks_cluster.existing.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.deploy.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
