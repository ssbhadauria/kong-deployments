output "gateway_id" {
  description = "ID of the AI Gateway control plane."
  value       = konnect_ai_gateway.this.id
}

output "proxy_urls" {
  description = "Data-plane proxy URLs clients use to reach the gateway (e.g. {proxy}/ps/chat/completions)."
  value       = konnect_ai_gateway.this.proxy_urls
}
