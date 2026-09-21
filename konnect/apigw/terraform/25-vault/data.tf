# Control plane (stack 10) — the vault entity lives under it.
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "kong-refresher-tfstate"
    key    = "10-konnect-platform/terraform.tfstate"
    region = "us-east-2"
  }
}

# Data plane (stack 20) — we attach the vault-read policy to its TASK role,
# because Kong (running as the task) is what resolves {vault://...} at runtime.
data "terraform_remote_state" "dataplane" {
  backend = "s3"
  config = {
    bucket = "kong-refresher-tfstate"
    key    = "20-dataplane-ecs/terraform.tfstate"
    region = "us-east-2"
  }
}

locals {
  control_plane_id = data.terraform_remote_state.platform.outputs.control_plane_id
  task_role_name   = data.terraform_remote_state.dataplane.outputs.task_role_name
}
