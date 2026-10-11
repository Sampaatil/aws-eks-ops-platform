output "pipeline_name" {
  value = aws_codepipeline.app.name
}
output "connection_arn" {
  value = aws_codestarconnections_connection.github.arn
}
output "deploy_role_arn" {
  value = aws_iam_role.build["cd"].arn
}
output "artifact_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}
output "nat_gateway_id" {
  value = aws_nat_gateway.deploy.id
}
output "deploy_subnet_id" {
  value = aws_subnet.deploy.id
}
