terraform {
  required_version = ">= 1.6.0"

  required_providers {
    konnect = {
      source  = "kong/konnect"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket       = "kong-refresher-tfstate"
    key          = "30-gateway-config/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
