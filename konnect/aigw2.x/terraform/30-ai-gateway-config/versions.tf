terraform {
  required_version = ">= 1.6.0"

  required_providers {
    konnect = {
      source  = "kong/konnect"
      version = "~> 3.25" # AI Gateway 2.x resources landed in 3.23.0
    }
  }

  backend "s3" {
    bucket       = "kong-refresher-tfstate"
    key          = "30-ai-gateway-config/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
