output "vpc_id" {
  value = aws_vpc.main.id
}
output "public_subnet_ids" {
  value = { for k, s in aws_subnet.public : k => s.id }
}
output "private_subnet_ids" {
  value = { for k, s in aws_subnet.private : k => s.id }
}
output "public_route_table_id" {
  value = aws_route_table.public.id
}
output "private_route_table_ids" {
  value = { for k, rt in aws_route_table.private : k => rt.id }
}
output "ecr_repository_urls" {
  value = { for k, r in aws_ecr_repository.app : k => r.repository_url }
}
output "ecr_repository_names" {
  value = { for k, r in aws_ecr_repository.app : k => r.name }
}
output "ecr_push_policy_arn" {
  value = aws_iam_policy.ecr_push.arn
}
output "ecr_push_policy_json" {
  value = data.aws_iam_policy_document.ecr_push.json
}
