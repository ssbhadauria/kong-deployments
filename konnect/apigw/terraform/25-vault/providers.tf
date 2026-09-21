provider "konnect" {
  personal_access_token = var.konnect_pat
  server_url            = var.konnect_server_url
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.tags
  }
}

variable "konnect_pat" {
  description = "Konnect token (GitHub secret KONNECT_TOKEN -> TF_VAR_konnect_pat)."
  type        = string
  sensitive   = true
}

variable "konnect_server_url" {
  type    = string
  default = "https://us.api.konghq.com/"
}

variable "aws_region" {
  type    = string
  default = "us-west-1"
}

variable "name_prefix" {
  type    = string
  default = "kong-refresher"
}

# Prefix used inside Kong to reference this vault: {vault://<prefix>/<secret>/<key>}
variable "vault_prefix" {
  type    = string
  default = "aws-sm"
}

variable "tags" {
  type = map(string)
  default = {
    project = "kong-refresher"
    env     = "demo"
  }
}
