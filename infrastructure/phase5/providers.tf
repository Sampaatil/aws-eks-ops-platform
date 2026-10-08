provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = { Project = "opsflow", Environment = "lab", ManagedBy = "terraform", Phase = "5" }
  }
}
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket              = var.state_bucket
    key                 = var.foundation_state_key
    region              = var.aws_region
    allowed_account_ids = [var.aws_account_id]
  }
}
locals {
  name        = "opsflow-lab"
  vpc_id      = data.terraform_remote_state.foundation.outputs.vpc_id
  public_ids  = values(data.terraform_remote_state.foundation.outputs.public_subnet_ids)
  private_ids = values(data.terraform_remote_state.foundation.outputs.private_subnet_ids)
}
