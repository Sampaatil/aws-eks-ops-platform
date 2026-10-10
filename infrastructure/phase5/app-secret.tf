# Merge into the EXISTING Phase 5 Terraform root, not a new state.
# Metadata only. Never manage secret_string/password in Terraform state.
resource "aws_secretsmanager_secret" "application_database" {
  name                    = "opsflow/lab/database-app"
  description             = "Existing OpsFlow application PostgreSQL credential; operator-managed value"
  recovery_window_in_days = 7
  tags = {
    Project = "OpsFlow"
    Purpose = "application-database-recovery"
  }
}
output "app_database_secret_arn" {
  value = aws_secretsmanager_secret.application_database.arn
}
