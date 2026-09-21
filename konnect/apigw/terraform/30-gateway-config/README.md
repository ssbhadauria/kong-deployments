# Stack 30 — Gateway config, generated from the OAS in CI

The OAS is the single source of truth. Nothing about the Service, Routes, or
plugins is hand-written here — the pipeline generates it on every run.

## How it works (no handoff, no manual steps)
1. `generate.sh` runs in the pipeline (the reusable workflow runs a stack's
   `generate.sh` if present):
   - `deck file openapi2kong` : `specs/kongair-flights/openapi.yaml` -> decK
   - `deck file kong2tf`      : decK -> `generated_gateway.tf`
   - rewires `control_plane_id` from `var` to stack 10's remote state
2. Terraform then plans/applies `generated_gateway.tf`.

`generated_gateway.tf` is **gitignored** — it's a build artifact. Edit the OAS,
not the Terraform. Resource addresses are stable because `kong2tf` names
resources from the spec's `operationId`s, so re-generating doesn't churn state.

## Everything comes from the spec
- Service + one Route per operation (`/health`, `/flights`, `/flights/{flightNumber}`)
- Plugins via `x-kong-plugin-*` extensions in the OAS:
  rate-limiting (5/min), opentelemetry (-> collector sidecar), prometheus.

## Committed files
- `providers.tf` — konnect provider + the platform remote-state lookup
- `versions.tf`  — providers + S3 backend
- `generate.sh`  — the OAS -> Terraform generator
- (`generated_gateway.tf` is produced at run time, not committed)

## Run
`Actions -> terraform-apply -> Run workflow -> konnect/apigw/terraform/30-gateway-config`

## Cleanup (repeatable demos)
`Actions -> terraform-destroy -> Run workflow -> stack = konnect/apigw/terraform/30-gateway-config`
(retype the path to confirm; approve at the production gate). Leaves 10/20/25 up.

## First-run caveats (codegen we can't dry-run here)
- Verify `deck file kong2tf` input flag (`-s`) against your deck version.
- If `terraform plan` errors on a duplicate `terraform`/`provider` block, kong2tf
  emitted boilerplate — add a strip line to generate.sh. Expected output is just
  `variable` + `resource` blocks, which we already handle.
- Bump `DECK_VERSION` in generate.sh if the download 404s.
