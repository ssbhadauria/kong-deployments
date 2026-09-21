# ---------------------------------------------------------------------------
# Stack 25 — Kong AWS Secrets Manager Vault backend
#
# This is DIFFERENT from stack 20's use of ASM. Stack 20 uses ECS *secret
# injection* (AWS hands a secret to the container as an env var at boot). Here,
# Kong itself resolves secrets AT RUNTIME from references like
#   {vault://aws-sm/<secret-name>/<key>}
# written directly into plugin config (used by the OIDC plugin in stack 40).
# The value never appears in decK/Terraform/plugin config.
# ---------------------------------------------------------------------------

# The Kong Vault entity: tells Kong how to reach AWS Secrets Manager and under
# what reference prefix. On Fargate, Kong authenticates to AWS with the ECS
# TASK role via the container credentials endpoint — no static AWS keys.
#
# NOTE: confirm field names against your provider version
# (terraform providers schema -json | jq '.. | .konnect_gateway_vault? // empty').
# Expected shape: name = backend type ("aws"), prefix = the {vault://<prefix>} token.
resource "konnect_gateway_vault" "aws_sm" {
  control_plane_id = local.control_plane_id
  name             = "aws"
  prefix           = var.vault_prefix
  description      = "AWS Secrets Manager backend for {vault://${var.vault_prefix}/...} references"

  config = jsonencode({
    region = var.aws_region
  })

  tags = ["kong-refresher"]
}

# The secret CONTAINER for the OIDC client secret. The VALUE is written later by
# stack 40 (when Kong Identity mints the client), so this stack only creates the
# empty secret — no secret_version here, to avoid two stacks fighting over it.
resource "aws_secretsmanager_secret" "oidc_client_secret" {
  name        = "${var.name_prefix}/oidc-client-secret"
  description = "OIDC client secret, resolved by Kong via {vault://${var.vault_prefix}/${var.name_prefix}/oidc-client-secret/...}"
}

# Let Kong (the TASK role, owned by stack 20) READ that secret at runtime.
data "aws_iam_policy_document" "vault_read" {
  statement {
    sid = "KongVaultReadOIDCSecret"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = ["${aws_secretsmanager_secret.oidc_client_secret.arn}*"]
  }
}

resource "aws_iam_role_policy" "vault_read" {
  name   = "${var.name_prefix}-kong-vault-read"
  role   = local.task_role_name
  policy = data.aws_iam_policy_document.vault_read.json
}

output "vault_prefix" {
  value = var.vault_prefix
}

# Reference string to use in the OIDC plugin config (stack 40).
output "oidc_client_secret_vault_ref" {
  description = "Put this in openid-connect client_secret instead of a literal."
  value       = "{vault://${var.vault_prefix}/${var.name_prefix}/oidc-client-secret/client_secret}"
}

output "oidc_client_secret_arn" {
  value = aws_secretsmanager_secret.oidc_client_secret.arn
}
