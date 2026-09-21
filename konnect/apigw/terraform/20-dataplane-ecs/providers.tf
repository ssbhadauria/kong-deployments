provider "konnect" {
  personal_access_token = var.konnect_pat
  server_url            = var.konnect_server_url
}

provider "aws" {
  region = var.aws_region # us-west-1 (where the existing VPC lives)
  default_tags {
    tags = var.tags
  }
}
