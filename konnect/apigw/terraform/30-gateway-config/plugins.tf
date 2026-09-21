# ---------------------------------------------------------------------------
# Plugins introduced in this stack, layered simplest-first for the walkthrough:
#   1. rate-limiting   (no auth needed — easiest to demo)
#   2. opentelemetry   (traces/logs -> collector sidecar on localhost:4318)
#   3. prometheus      (metrics on :8100/metrics for the collector to scrape)
# OIDC + ACL come in stack 40.
#
# NOTE: typed plugin resource names (konnect_gateway_plugin_<name>) are
# provider-version dependent. If a name is unknown to your provider, check
#   terraform providers schema -json | jq '.provider_schemas[].resource_schemas | keys'
# ---------------------------------------------------------------------------

# 1. Rate limiting — scoped to the flights service. Low limit for the demo.
resource "konnect_gateway_plugin_rate_limiting" "flights" {
  control_plane_id = local.control_plane_id
  service          = { id = konnect_gateway_service.flights.id }

  config = {
    minute              = var.rate_limit_per_minute
    policy              = "local"
    limit_by            = "ip"
    fault_tolerant      = true
    hide_client_headers = false
  }
  tags = var.tags
}

# 2. OpenTelemetry — export traces & logs to the OTel Collector sidecar in the
# same ECS task (shared network namespace, so localhost). Non-fatal if the
# collector is down; Kong buffers/drops without affecting proxying.
resource "konnect_gateway_plugin_opentelemetry" "flights" {
  control_plane_id = local.control_plane_id
  service          = { id = konnect_gateway_service.flights.id }

  config = {
    traces_endpoint = "http://localhost:4318/v1/traces"
    logs_endpoint   = "http://localhost:4318/v1/logs"
    resource_attributes = {
      "service.name" = "flights-service"
    }
  }
  tags = var.tags
}

# 3. Prometheus — global; exposes Kong metrics at :8100/metrics (the status
# listener enabled in stack 20), which the collector scrapes.
resource "konnect_gateway_plugin_prometheus" "global" {
  control_plane_id = local.control_plane_id

  config = {
    status_code_metrics     = true
    latency_metrics         = true
    bandwidth_metrics       = true
    upstream_health_metrics = true
  }
  tags = var.tags
}
