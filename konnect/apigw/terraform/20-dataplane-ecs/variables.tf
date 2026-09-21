# Secrets come from GitHub secrets via TF_VAR_*. Everything else has a committed
# default here (NOT in a *.tfvars file, which .gitignore excludes — so CI would
# never see it). These are non-secret infra identifiers; safe to commit.

# --- Secrets (no defaults; supplied by the pipeline) ------------------------
variable "konnect_pat" {
  description = "Konnect token (GitHub secret KONNECT_TOKEN -> TF_VAR_konnect_pat)."
  type        = string
  sensitive   = true
}

variable "grafana_otlp_token" {
  description = "Grafana Cloud access-policy token (GitHub secret GRAFANA_CLOUD_OTLP_TOKEN -> TF_VAR_grafana_otlp_token)."
  type        = string
  sensitive   = true
}

# --- Konnect ----------------------------------------------------------------
variable "konnect_server_url" {
  type    = string
  default = "https://us.api.konghq.com/"
}

# The DP control-plane and telemetry hosts are NOT variables — they're derived
# at plan time from the Konnect API in data.tf (data.http.control_plane), using
# the control_plane_id from stack 10. Nothing to set here.

# --- AWS / networking (existing VPC in us-west-1) ---------------------------
variable "aws_region" {
  type    = string
  default = "us-west-1"
}

variable "vpc_id" {
  type    = string
  default = "vpc-0347301e32ba65b81" # sb-vpc
}

variable "public_subnet_ids" {
  description = "Public subnets for the internet-facing NLB (>= 2 AZs)."
  type        = list(string)
  default     = ["subnet-08fefaa180c5bc682", "subnet-0c099e919aae2c6e2"]
}

variable "private_subnet_ids" {
  description = "Private subnets (with NAT) for the Fargate DP tasks."
  type        = list(string)
  default     = ["subnet-00df8c47b9762eda4", "subnet-0bc2e8f1524962012"]
}

variable "proxy_ingress_cidrs" {
  description = "CIDRs allowed to reach the proxy through the NLB. 0.0.0.0/0 = open."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --- Grafana Cloud OTLP (endpoint + id are NOT secret; token IS) ------------
variable "grafana_otlp_endpoint" {
  type    = string
  default = "https://otlp-gateway-prod-us-west-0.grafana.net/otlp"
}

variable "grafana_instance_id" {
  type    = string
  default = "1795125"
}

# --- Images (bump to current stable as needed) ------------------------------
variable "kong_image" {
  type    = string
  default = "kong/kong-gateway:3.15.0.6"
}

variable "otel_collector_image" {
  type    = string
  default = "otel/opentelemetry-collector-contrib:0.116.0"
}

# --- Sizing -----------------------------------------------------------------
variable "name_prefix" {
  type    = string
  default = "kong-refresher"
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "task_cpu" {
  type    = number
  default = 1024
}

variable "task_memory" {
  type    = number
  default = 2048
}

variable "tags" {
  type = map(string)
  default = {
    project = "kong-refresher"
    env     = "demo"
  }
}
