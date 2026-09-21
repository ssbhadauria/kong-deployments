# ---------------------------------------------------------------------------
# Data-plane client certificate (Konnect pinned_client_certs / cluster_mtls=pki)
# We generate a key + self-signed cert, register the PUBLIC cert with the
# control plane, and give the DP the key (secret) + cert to authenticate.
# ---------------------------------------------------------------------------

resource "tls_private_key" "dp" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "dp" {
  private_key_pem = tls_private_key.dp.private_key_pem

  subject {
    common_name  = "${var.name_prefix}-dp"
    organization = "kong-refresher"
  }

  validity_period_hours = 8760 # 1 year
  early_renewal_hours   = 720

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# Register the DP cert with the control plane so Konnect pins/trusts it.
# NOTE: confirm this resource + attribute name against your provider version
# (terraform providers schema -json | jq '.. | .konnect_gateway_data_plane_client_certificate? // empty').
resource "konnect_gateway_data_plane_client_certificate" "dp" {
  control_plane_id = local.control_plane_id
  cert             = tls_self_signed_cert.dp.cert_pem
}

# --- Secrets in AWS Secrets Manager (injected into the task, never plaintext) ---
resource "aws_secretsmanager_secret" "dp_key" {
  name        = "${var.name_prefix}/dp-cluster-cert-key"
  description = "Kong DP private key for CP mTLS"
}

resource "aws_secretsmanager_secret_version" "dp_key" {
  secret_id     = aws_secretsmanager_secret.dp_key.id
  secret_string = tls_private_key.dp.private_key_pem
}

resource "aws_secretsmanager_secret" "grafana_token" {
  name        = "${var.name_prefix}/grafana-otlp-token"
  description = "Grafana Cloud OTLP access-policy token"
}

resource "aws_secretsmanager_secret_version" "grafana_token" {
  secret_id     = aws_secretsmanager_secret.grafana_token.id
  secret_string = var.grafana_otlp_token
}
