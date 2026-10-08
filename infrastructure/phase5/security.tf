resource "aws_security_group" "control" {
  name        = "${local.name}-control"
  description = "Additional EKS control-plane security group"
  vpc_id      = local.vpc_id
}
resource "aws_security_group" "nodes" {
  name        = "${local.name}-nodes"
  description = "Custom worker and VPC CNI Pod group; no SSH or public inbound"
  vpc_id      = local.vpc_id
  tags        = { "kubernetes.io/cluster/${local.name}" = "owned" }
}
resource "aws_vpc_security_group_ingress_rule" "control_from_nodes" {
  security_group_id            = aws_security_group.control.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
resource "aws_vpc_security_group_egress_rule" "control" {
  security_group_id = aws_security_group.control.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_vpc_security_group_ingress_rule" "nodes_self" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "-1"
}
resource "aws_vpc_security_group_ingress_rule" "nodes_control" {
  for_each                     = toset(["443", "10250", "9443"])
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.control.id
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.key)
  to_port                      = tonumber(each.key)
}
resource "aws_vpc_security_group_egress_rule" "nodes" {
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_security_group" "database" {
  name        = "${local.name}-rds"
  description = "PostgreSQL from worker group only"
  vpc_id      = local.vpc_id
}
resource "aws_vpc_security_group_ingress_rule" "database" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
# Security groups are stateful; database replies require no broad outbound rule.
# LBC dynamically manages ALB-to-Pod ingress on worker group. Do not put inline SG ingress here.
