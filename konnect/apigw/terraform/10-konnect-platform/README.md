# Stack 10 — Konnect platform

Creates the Konnect Gateway **control plane** that the ECS data plane (stack 20)
attaches to in hybrid mode, plus a platform-admin team as a pattern.

## What it creates
- `konnect_gateway_control_plane` with `auth_type = pinned_client_certs`
- `konnect_team` (admin team; role assignment shown commented — confirm the
  resource name for your provider version)

## Apply
```bash
export TF_VAR_konnect_pat="kpat_..."      # Konnect PAT or System Account token
cp terraform.tfvars.example terraform.tfvars   # optional, or use env vars
terraform init
terraform plan
terraform apply
```

## Outputs (consumed downstream)
- `control_plane_id` — required by all `konnect_gateway_*` resources in stacks 20/30/40/60
- `aws_region`, `name_prefix`, `tags` — passed through for consistency

## Notes
- Provider `kong/konnect` evolves quickly. Run
  `terraform providers schema -json | jq` to confirm attribute/resource names
  (control-plane endpoints, team role assignment) for your pinned version.
- `proxy_urls` on the control plane is intentionally unset until stack 20 knows
  the ECS load balancer hostname.

## Next
Stack 20 — data plane on ECS (Kong DP + OTel Collector sidecar + DP client cert).
Confirm the vault backend (AWS Secrets Manager vs HashiCorp Vault) and the
observability backend (SigNoz vs Grafana LGTM) before stacks 25/70.
