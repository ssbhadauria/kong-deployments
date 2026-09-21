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

# The generated_gateway.tf (produced by generate.sh) references this data source
# after control_plane_id is rewired from var -> remote state.
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "kong-refresher-tfstate"
    key    = "10-konnect-platform/terraform.tfstate"
    region = "us-east-2"
  }
}
