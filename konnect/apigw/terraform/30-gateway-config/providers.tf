provider "konnect" {
  personal_access_token = var.konnect_pat
  server_url            = var.konnect_server_url
}

variable "konnect_pat" {
  type      = string
  sensitive = true
}

variable "konnect_server_url" {
  type    = string
  default = "https://us.api.konghq.com/"
}

# Upstream the flights Service proxies to. Defaults to KongAir's live public API
# so no backend needs deploying. Point at your own KongAir (EKS, etc.) by
# overriding these if you run the service yourself.
variable "flights_upstream_host" {
  type    = string
  default = "api.kong-air.com"
}
variable "flights_upstream_protocol" {
  type    = string
  default = "https"
}
variable "flights_upstream_port" {
  type    = number
  default = 443
}

# Rate limit for the demo — deliberately low so it's easy to trip in Insomnia.
variable "rate_limit_per_minute" {
  type    = number
  default = 5
}

variable "tags" {
  type    = list(string)
  default = ["kong-refresher", "flight-data"]
}

data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "kong-refresher-tfstate"
    key    = "10-konnect-platform/terraform.tfstate"
    region = "us-east-2"
  }
}

locals {
  control_plane_id = data.terraform_remote_state.platform.outputs.control_plane_id
}
