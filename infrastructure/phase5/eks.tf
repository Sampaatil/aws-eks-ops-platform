resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.name}/cluster"
  retention_in_days = 7
}
resource "aws_eks_cluster" "main" {
  name                      = local.name
  role_arn                  = aws_iam_role.cluster.arn
  version                   = var.kubernetes_version
  enabled_cluster_log_types = ["api", "audit", "authenticator"]
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }
  upgrade_policy { support_type = "STANDARD" }
  vpc_config {
    subnet_ids              = local.private_ids
    security_group_ids      = [aws_security_group.control.id]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.admin_ipv4_cidr]
  }
  depends_on = [aws_iam_role_policy_attachment.cluster, aws_cloudwatch_log_group.cluster]
}
resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.admin_principal_arn
  type          = "STANDARD"
}
resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}
resource "aws_launch_template" "nodes" {
  name_prefix = "${local.name}-nodes-"
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    security_groups             = [aws_security_group.nodes.id]
    delete_on_termination       = true
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }
  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-worker", Project = "opsflow", Environment = "lab" }
  }
}
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "lab-workers"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = local.public_ids
  ami_type        = "AL2023_x86_64_STANDARD"
  instance_types  = [var.node_instance_type]
  capacity_type   = "ON_DEMAND"
  version         = var.kubernetes_version
  launch_template {
    id      = aws_launch_template.nodes.id
    version = tostring(aws_launch_template.nodes.latest_version)
  }
  scaling_config {
    desired_size = var.node_desired_size
    min_size     = 1
    max_size     = 3
  }
  update_config { max_unavailable = 1 }
  depends_on = [aws_iam_role_policy_attachment.nodes,
    aws_vpc_security_group_ingress_rule.control_from_nodes,
    aws_vpc_security_group_ingress_rule.nodes_control,
    aws_vpc_security_group_ingress_rule.nodes_self,
    aws_vpc_security_group_egress_rule.nodes,
  aws_vpc_security_group_egress_rule.control]
}
data "aws_eks_addon_version" "addons" {
  for_each           = toset(["vpc-cni", "kube-proxy", "coredns", "eks-pod-identity-agent"])
  addon_name         = each.key
  kubernetes_version = var.kubernetes_version
  most_recent        = false
}
resource "aws_eks_addon" "addons" {
  for_each                    = data.aws_eks_addon_version.addons
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = each.key
  addon_version               = each.value.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_node_group.main]
}
resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc.arn
  depends_on      = [aws_eks_addon.addons, aws_iam_role_policy_attachment.lbc]
}
