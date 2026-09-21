provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.tags
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket for Terraform remote state. Must match the literal name in each stack's backend block."
  type        = string
  default     = "kong-refresher-tfstate"
}

variable "lock_table_name" {
  description = "DynamoDB table for state locking (only needed if you use dynamodb_table locking instead of use_lockfile)."
  type        = string
  default     = "kong-refresher-tflock"
}

variable "create_lock_table" {
  description = "Set false if all stacks use S3 native locking (use_lockfile, TF >= 1.10)."
  type        = bool
  default     = true
}

variable "tags" {
  type = map(string)
  default = {
    project = "kong-refresher"
    env     = "demo"
  }
}
