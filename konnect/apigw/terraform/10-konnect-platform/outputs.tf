# These outputs are the contract for downstream stacks (20 ECS DP, 30 gateway
# config, 40 kong-identity, 60 dev-portal). Read them via terraform_remote_state
# or pass them in as -var.

output "control_plane_id" {
  description = "Konnect control plane ID. Required by every konnect_gateway_* resource downstream."
  value       = konnect_gateway_control_plane.this.id
}

output "control_plane_name" {
  value = konnect_gateway_control_plane.this.name
}

# The DP needs two endpoints to join in hybrid mode:
#   - control plane (config)    : <cp-id>.<region>.cp0.konghq.com : 443
#   - telemetry (metrics/traces): <cp-id>.<region>.tp0.konghq.com : 443
# Depending on provider version these may surface as attributes on the control
# plane (e.g. .config[...] / dedicated endpoint fields) or via the
# konnect_gateway_control_plane data source. Verify against your schema; stack
# 20 derives them from control_plane_id + region if not exported directly.

output "aws_region" {
  value = var.aws_region
}

output "name_prefix" {
  value = var.name_prefix
}

output "tags" {
  value = var.tags
}
