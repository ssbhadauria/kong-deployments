terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Bootstrap uses LOCAL state on purpose: it creates the very bucket the other
  # stacks use for remote state, so it can't depend on that bucket existing.
  # Options:
  #   (a) keep this local state, commit terraform.tfstate (fine for a demo), OR
  #   (b) after apply, add an S3 backend block here too and run
  #       `terraform init -migrate-state` to move bootstrap's own state in.
}
