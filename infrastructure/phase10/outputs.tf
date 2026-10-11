output "application_log_group" { value = aws_cloudwatch_log_group.application.name }
output "log_role_arn" { value = aws_iam_role.logs.arn }
output "pod_identity_association_id" { value = aws_eks_pod_identity_association.logs.association_id }
