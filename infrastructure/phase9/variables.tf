variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "aws_account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Intended 12-digit AWS account required."
  }
}
variable "state_bucket" {
  type = string
}
variable "phase5_state_key" {
  type    = string
  default = "opsflow/lab/eks.tfstate"
}
variable "github_repository" {
  type        = string
  description = "Actual GitHub owner/repository, independently verify spelling and ownership."
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use owner/repository."
  }
}
variable "branch" {
  type    = string
  default = "main"
}
variable "detect_changes" {
  type    = bool
  default = false
}
variable "deploy_subnet_cidr" {
  type    = string
  default = "10.40.64.0/24"
}
variable "kubectl_version" {
  type    = string
  default = "v1.35.0"
}
variable "helm_version" {
  type    = string
  default = "v3.19.0"
}
