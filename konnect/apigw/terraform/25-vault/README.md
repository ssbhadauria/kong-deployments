# Stack 25 — Kong Vault (AWS Secrets Manager backend)

Sets up Kong's native AWS Secrets Manager Vault so plugin configs can reference
secrets as `{vault://aws-sm/...}` and Kong resolves them at runtime — the value
never lands in decK/Terraform/plugin config.

## Not the same as stack 20's ASM usage
- **Stack 20** = ECS *secret injection*: AWS gives the container a secret as an
  env var at boot (DP key, Grafana token). Kong just sees an env var.
- **Stack 25** = Kong's *Vault backend*: Kong itself calls Secrets Manager at
  runtime to resolve `{vault://...}` references written into plugin config.

## Creates
- `konnect_gateway_vault` (backend `aws`, prefix `aws-sm`, region `us-west-1`).
- `aws_secretsmanager_secret` **container** for the OIDC client secret (empty;
  the value is written by stack 40 when Kong Identity mints the client).
- An IAM policy on stack 20's **task role** granting `GetSecretValue` /
  `DescribeSecret` on that secret — Kong authenticates to AWS via the task role
  through the Fargate container-credentials endpoint (no static keys).

## Depends on
- Stack 10 output `control_plane_id`
- Stack 20 output `task_role_name` (added for this stack)

## Outputs
- `oidc_client_secret_vault_ref` — the exact `{vault://...}` string stack 40's
  `openid-connect` plugin uses for `client_secret`.

## Apply
Via the pipeline like every stack: `Actions → terraform-apply → Run workflow →`
`konnect/apigw/terraform/25-vault`. Order: 10 → 20 → **25** → 30 → 40.

## Notes
- Confirm `konnect_gateway_vault` field names (`name`/`prefix`/`config`) against
  your pinned provider version if the plan errors.
- The secret is created empty; a `{vault://...}` lookup only succeeds once stack
  40 populates it, so this stack applying green ≠ the reference resolving yet.
