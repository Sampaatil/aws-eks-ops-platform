locals {
  build_trust = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "codebuild.amazonaws.com" }, Action = "sts:AssumeRole", Condition = { StringEquals = { "aws:SourceAccount" = var.aws_account_id }, ArnLike = { "aws:SourceArn" = "arn:aws:codebuild:${var.aws_region}:${var.aws_account_id}:project/${local.name}-*" } } }] })
  repo_arns   = [for url in values(local.repositories) : "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${split("/", url)[1]}"]
}
resource "aws_iam_role" "build" {
  for_each           = toset(["ci", "cd"])
  name               = "${local.name}-${each.key}"
  assume_role_policy = local.build_trust
}
resource "aws_iam_role_policy" "common" {
  for_each = aws_iam_role.build
  role     = each.value.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.build[each.key].arn}:*" },
    { Effect = "Allow", Action = ["s3:GetBucketLocation", "s3:ListBucket"], Resource = aws_s3_bucket.artifacts.arn },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"], Resource = "${aws_s3_bucket.artifacts.arn}/*" }
  ] })
}
resource "aws_iam_role_policy" "ci" {
  role = aws_iam_role.build["ci"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
    { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:DescribeImages", "ecr:DescribeImageScanFindings"], Resource = local.repo_arns }
  ] })
}
resource "aws_iam_role_policy" "cd" {
  role = aws_iam_role.build["cd"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["eks:DescribeCluster"], Resource = data.aws_eks_cluster.existing.arn },
    { Effect = "Allow", Action = ["ecr:DescribeImages", "ecr:DescribeImageScanFindings"], Resource = local.repo_arns },
    { Effect = "Allow", Action = ["ec2:CreateNetworkInterface", "ec2:DeleteNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeDhcpOptions", "ec2:DescribeVpcs"], Resource = "*" },
    { Effect = "Allow", Action = ["ec2:CreateNetworkInterfacePermission"], Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:network-interface/*", Condition = { StringEquals = { "ec2:Subnet" = aws_subnet.deploy.arn, "ec2:AuthorizedService" = "codebuild.amazonaws.com" } } }
  ] })
}
resource "aws_eks_access_entry" "deploy" {
  cluster_name      = local.infra.cluster_name
  principal_arn     = aws_iam_role.build["cd"].arn
  kubernetes_groups = ["opsflow-ci-deploy"]
  type              = "STANDARD"
}
resource "aws_iam_role" "pipeline" {
  name               = "${local.name}-pipeline"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "codepipeline.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy" "pipeline" {
  role = aws_iam_role.pipeline.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["codeconnections:UseConnection", "codestar-connections:UseConnection"], Resource = aws_codestarconnections_connection.github.arn },
    { Effect = "Allow", Action = ["s3:GetBucketLocation", "s3:ListBucket"], Resource = aws_s3_bucket.artifacts.arn },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"], Resource = "${aws_s3_bucket.artifacts.arn}/*" },
    { Effect = "Allow", Action = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"], Resource = [for p in aws_codebuild_project.build : p.arn] }
  ] })
}
