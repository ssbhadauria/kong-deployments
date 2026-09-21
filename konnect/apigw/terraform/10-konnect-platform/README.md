# Stack 10 — Konnect platform

The first stack applied **through the GitHub Actions pipeline** (bootstrap must
be done first). Creates the Konnect Gateway **control plane** the ECS data plane
(stack 20) attaches to in hybrid mode, plus a platform-admin team.

## What it creates
- `konnect_gateway_control_plane` "kong-refresher-cp" with
  `auth_type = pinned_client_certs` (the DP authenticates with a client cert
  registered in stack 20).
- `konnect_team` "kong-refresher-platform-admins" (role assignment left
  commented — confirm the resource name for your provider version).

## How it runs (GitOps)
Applied by the pipeline, not by hand:
- **PR** touching `konnect/apigw/terraform/10-konnect-platform/**` → `terraform-plan`
  posts the plan as a PR comment.
- **Merge to main** (or **Actions → terraform-apply → Run workflow** with
  `stack = konnect/apigw/terraform/10-konnect-platform`) → gated apply.

State lives at `s3://kong-refresher-tfstate/10-konnect-platform/terraform.tfstate`.

## Outputs (consumed downstream)
- `control_plane_id` — required by every `konnect_gateway_*` resource in stacks 20/30/40/60
- `aws_region`, `name_prefix`, `tags`

## Prerequisites / gotchas we hit
1. **Use `Run workflow`, not `Re-run jobs`, after any fix.** "Re-run jobs"
   replays the ORIGINAL commit; "Run workflow" runs the tip of `main`. Re-running
   an old commit chased a formatting error that was already fixed.

2. **`terraform fmt` is enforced.** The pipeline runs `terraform fmt -check` and
   fails the run on any unformatted file. Run `terraform fmt -recursive` from the
   repo root before pushing. Pre-push gate:
   `terraform fmt -check -recursive && echo ALL CLEAN`.

3. **`KONNECT_TOKEN` needs the right authorization.** A valid token still returned
   `403 Forbidden` on `POST /v2/control-planes` because its identity lacked
   control-plane permissions (it could create the team but not the control
   plane). The token's Konnect identity must have **Control Plane Admin** (or, for
   this demo account, **Organization Admin**, which also covers Kong Identity and
   Dev Portal in later stacks). Missing token → plan fails asking for
   `var.konnect_pat`.

## Provider note
`kong/konnect` moves fast; attribute/resource names can shift between releases.
If a plan errors with `Unsupported argument` / `Missing required argument`, check
`terraform providers schema -json` for your pinned version.