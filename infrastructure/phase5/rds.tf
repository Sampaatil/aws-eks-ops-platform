resource "aws_cloudwatch_log_group" "database" {
  for_each          = toset(["postgresql", "upgrade"])
  name              = "/aws/rds/instance/${local.name}-postgres/${each.key}"
  retention_in_days = 7
}
resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-rds"
  subnet_ids = local.private_ids
}
resource "aws_db_parameter_group" "main" {
  name   = "${local.name}-postgres16"
  family = "postgres16"
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
}
resource "aws_db_instance" "main" {
  identifier                      = "${local.name}-postgres"
  engine                          = "postgres"
  engine_version                  = var.postgres_engine_version
  instance_class                  = var.db_instance_class
  db_name                         = "opsflow"
  username                        = "opsflow_admin"
  manage_master_user_password     = true
  db_subnet_group_name            = aws_db_subnet_group.main.name
  parameter_group_name            = aws_db_parameter_group.main.name
  vpc_security_group_ids          = [aws_security_group.database.id]
  publicly_accessible             = false
  multi_az                        = false
  storage_type                    = "gp3"
  allocated_storage               = 20
  storage_encrypted               = true
  backup_retention_period         = 1
  copy_tags_to_snapshot           = true
  auto_minor_version_upgrade      = true
  deletion_protection             = false
  skip_final_snapshot             = false
  final_snapshot_identifier       = var.final_snapshot_identifier
  delete_automated_backups        = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = false
  depends_on                      = [aws_cloudwatch_log_group.database]
}
