variable "gateway_name" {
  description = "Name of the AI Gateway control plane. Keep in sync with specs/ps-copilot/ai.yaml (ai_gateways[0].name)."
  type        = string
  default     = "ps-copilot"
}

variable "gateway_display_name" {
  type    = string
  default = "PS Copilot Gateway"
}

# Referenced by the generated file via "${var.tech_llm_api_key}" in ai.yaml.
# Supply at apply time:  TF_VAR_tech_llm_api_key=... terraform apply
variable "tech_llm_api_key" {
  description = "API key/credential for the LLM service on cloud.konghq.tech (sent as the Authorization header to the upstream provider)."
  type        = string
  sensitive   = true
}
