# Stack 00 — bootstrap (remote state)

Creates the S3 bucket (versioned, encrypted, private) and optional DynamoDB
lock table that every other stack uses as its Terraform backend. **Apply once,
before anything else**, with local state.

```bash
cd terraform/00-bootstrap
terraform init
terraform apply           # creates kong-refresher-tfstate (+ lock table)
```

After this exists, every other stack's `backend "s3"` block resolves, and the
GitOps pipeline can `init/plan/apply` each stack against shared remote state.

## Locking choice
- `use_lockfile = true` in each stack's backend (Terraform >= 1.10) → S3-native
  locking, no DynamoDB. Set `create_lock_table = false` here.
- Otherwise keep the DynamoDB table and use `dynamodb_table = ...` in backends.

## GitOps apply order
```
00-bootstrap (once, manual)
   └─ 10-konnect-platform
        └─ 20-dataplane-ecs
             └─ 25-vault            (AWS Secrets Manager + konnect_gateway_vault)
                  └─ 30-gateway-config
                       └─ 40-kong-identity   (OIDC + ACL)
                            └─ 60-dev-portal
                                 └─ 70-observability  (collector -> Grafana Cloud)
```
Downstream stacks read upstream outputs via `terraform_remote_state`.
