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

variable "availability_zones" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b"]
  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "Specify exactly two distinct available AZs in your chosen region."
  }
}
