data "aws_eks_cluster" "existing" { name = var.cluster_name }
resource "aws_cloudwatch_log_group" "application" {
  name = "/opsflow/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days
}
resource "aws_iam_role" "logs" {
  name = "${var.cluster_name}-phase10-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })
}
resource "aws_iam_role_policy" "logs" {
  name = "application-log-writer"
  role = aws_iam_role.logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.application.arn}:*"
    }]
  })
}
resource "aws_eks_pod_identity_association" "logs" {
  cluster_name = data.aws_eks_cluster.existing.name
  namespace = "monitoring"
  service_account = "opsflow-fluent-bit"
  role_arn = aws_iam_role.logs.arn
}
