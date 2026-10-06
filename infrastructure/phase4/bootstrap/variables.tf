variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "aws_account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Enter your intended 12-digit AWS account ID."
  }
}
