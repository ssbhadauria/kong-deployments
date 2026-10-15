# The AI Gateway 2.x control plane itself. All generated entities
# (generated_ai_gateway.tf) attach to it via konnect_ai_gateway.this.id.
resource "konnect_ai_gateway" "this" {
  name         = var.gateway_name
  display_name = var.gateway_display_name
  description  = "AI Gateway 2.2 control plane for the PS Copilot agent (managed by Terraform)"

  labels = {
    managed_by = "terraform"
    stack      = "30-ai-gateway-config"
    spec       = "specs/ps-copilot/ai.yaml"
  }
}
