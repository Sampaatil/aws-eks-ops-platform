variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "aws_account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Use the intended 12-digit AWS account ID."
  }
}
variable "state_bucket" { type = string }
variable "foundation_state_key" {
  type    = string
  default = "opsflow/lab/foundation.tfstate"
}
variable "admin_principal_arn" {
  type        = string
  description = "Permanent IAM role ARN or IAM user ARN; never STS assumed-role ARN."
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:(role|user)/.+$", var.admin_principal_arn)) && startswith(var.admin_principal_arn, "arn:aws:iam::${var.aws_account_id}:")
    error_message = "Supply a permanent IAM role/user ARN in the intended AWS account, not an STS session ARN."
  }
}
variable "admin_ipv4_cidr" {
  type        = string
  description = "Your current public IPv4 address with /32."
  validation {
    condition     = can(cidrnetmask(var.admin_ipv4_cidr)) && can(regex("/32$", var.admin_ipv4_cidr))
    error_message = "Use a valid IPv4 /32, not 0.0.0.0/0."
  }
}
variable "kubernetes_version" {
  type    = string
  default = "1.35"
}
variable "node_instance_type" {
  type    = string
  default = "t3.small"
}
variable "node_desired_size" {
  type    = number
  default = 2
  validation {
    condition     = var.node_desired_size >= 1 && var.node_desired_size <= 3 && floor(var.node_desired_size) == var.node_desired_size
    error_message = "For this bounded lab use 1, 2 or 3 nodes."
  }
}
variable "postgres_engine_version" {
  type        = string
  default     = "16"
  description = "PostgreSQL 16 only for this parameter group; verify availability in your account."
  validation {
    condition     = can(regex("^16(\\.[0-9]+)?$", var.postgres_engine_version))
    error_message = "Use PostgreSQL major 16 or a supported 16.x minor for the postgres16 parameter group."
  }
}
variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "final_snapshot_identifier" {
  type        = string
  description = "Unique RDS snapshot name for this deployment's final snapshot."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+[a-z0-9]$", var.final_snapshot_identifier)) && !strcontains(var.final_snapshot_identifier, "--")
    error_message = "Use a unique lowercase snapshot identifier starting with a letter, no trailing or repeated hyphens."
  }
}
