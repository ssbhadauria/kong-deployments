variable "konnect_pat" {
  description = "Konnect Personal Access Token or System Account token. Supply via TF_VAR_konnect_pat, never commit it."
  type        = string
  sensitive   = true
}

variable "konnect_server_url" {
  description = "Konnect region API base URL."
  type        = string
  default     = "https://us.api.konghq.com/"
}

variable "aws_region" {
  description = "AWS region for downstream infra (ECS data plane, Secrets Manager, etc.)."
  type        = string
  default     = "us-east-2"
}

variable "name_prefix" {
  description = "Prefix applied to created resources so the demo is easy to find and tear down."
  type        = string
  default     = "kong-refresher"
}

variable "control_plane_name" {
  description = "Name of the Konnect Gateway control plane."
  type        = string
  default     = "kong-refresher-cp"
}

variable "tags" {
  description = "Common tags/labels applied to resources."
  type        = map(string)
  default = {
    project = "kong-refresher"
    owner   = "solutions-engineering"
    env     = "demo"
  }
}
