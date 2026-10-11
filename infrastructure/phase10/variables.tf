variable "aws_region" { type = string }
variable "aws_account_id" { type = string }
variable "cluster_name" { type = string }
variable "log_retention_days" {
  type    = number
  default = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.log_retention_days)
    error_message = "Choose a short supported lab retention."
  }
}
