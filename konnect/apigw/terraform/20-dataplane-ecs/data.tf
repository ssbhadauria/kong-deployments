# Stack 10's outputs (control_plane_id, etc.)
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "kong-refresher-tfstate"
    key    = "10-konnect-platform/terraform.tfstate"
    region = "us-east-2"
  }
}

# Existing VPC — used for its CIDR (task security-group ingress source).
data "aws_vpc" "this" {
  id = var.vpc_id
}

# Derive the DP connection endpoints from the Konnect API instead of hardcoding
# them (keeps everything code-driven for CI). The Konnect Terraform provider has
# limited data-source support, so we call the API directly with the http
# provider — the pattern Kong's own provider repo recommends.
#   GET /v2/control-planes/{id} -> .config.control_plane_endpoint / .telemetry_endpoint
# NOTE: request_headers (incl. the bearer token) are stored in state. State is
# the encrypted, access-controlled S3 backend, and var.konnect_pat is already a
# sensitive input, so this adds no exposure beyond the existing trust boundary.
data "http" "control_plane" {
  url = "${trimsuffix(var.konnect_server_url, "/")}/v2/control-planes/${local.control_plane_id}"
  request_headers = {
    Accept        = "application/json"
    Authorization = "Bearer ${var.konnect_pat}"
  }
}

locals {
  control_plane_id = data.terraform_remote_state.platform.outputs.control_plane_id

  _cp = jsondecode(data.http.control_plane.response_body).config

  # e.g. https://abcd1234.us.cp0.konghq.com -> abcd1234.us.cp0.konghq.com
  cp_host = replace(local._cp.control_plane_endpoint, "https://", "")
  tp_host = replace(local._cp.telemetry_endpoint, "https://", "")
}
