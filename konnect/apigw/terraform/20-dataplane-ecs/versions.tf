terraform {
  required_version = ">= 1.6.0"

  required_providers {
    konnect = {
      source  = "kong/konnect"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }

  # NOTE: region here is the STATE BUCKET's region (us-east-2, where bootstrap
  # created it) — NOT the AWS provider region (us-west-1). They are independent.
  backend "s3" {
    bucket       = "kong-refresher-tfstate"
    key          = "20-dataplane-ecs/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
