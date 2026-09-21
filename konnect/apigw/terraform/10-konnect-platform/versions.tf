terraform {
  required_version = ">= 1.6.0"

  required_providers {
    konnect = {
      source = "kong/konnect"
      # The kong/konnect provider moves quickly. Pin exactly for reproducible
      # applies; ~> 3.0 is a reasonable starting constraint. Run
      # `terraform init -upgrade` then `terraform providers` to see what you got.
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # --- Remote state (required for GitOps) -------------------------------------
  # Each stack keeps its OWN state (so you can apply module by module) under a
  # distinct key in a shared bucket created once by the 00-bootstrap stack.
  # Downstream stacks read this stack's outputs via terraform_remote_state.
  #
  # Bucket/table names are literal (backend blocks can't take variables); they
  # must match 00-bootstrap's outputs. The pipeline runs:
  #   terraform init   (locks + pulls remote state)
  #   terraform plan   (on PR, posted as a comment)
  #   terraform apply  (on merge to main)
  backend "s3" {
    bucket  = "kong-refresher-tfstate"
    key     = "10-konnect-platform/terraform.tfstate"
    region  = "us-east-2"
    encrypt = true

    # Locking: pick ONE.
    #  - Classic (any TF version):  dynamodb_table = "kong-refresher-tflock"
    #  - Native S3 lock (TF >=1.10): use_lockfile = true   (no DynamoDB needed)
    use_lockfile = true
    # dynamodb_table = "kong-refresher-tflock"
  }
}
