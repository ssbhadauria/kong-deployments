# GitOps setup — GitHub Actions

Git is the source of truth. PRs run `terraform plan`; merges (or a manual
dispatch) run a gated `terraform apply`; all against shared S3 remote state,
with CI authenticating to AWS via OIDC (no static keys).

## Directory structure

```
ps-amer-kong-refresher/                 # git repo root
├── .github/
│   └── workflows/                      # MUST live at the repo root
│       ├── _terraform.yml              # reusable engine: init/fmt/validate/plan/apply (one stack)
│       ├── terraform-plan.yml          # PR: detect changed stacks -> plan -> comment
│       └── terraform-apply.yml         # main push / manual dispatch: gated, ordered apply
└── konnect/
    └── apigw/                          # main working dir
        ├── terraform/
        │   ├── 00-bootstrap/           # state bucket + GitHub OIDC provider + CI role (apply once, local state)
        │   ├── 10-konnect-platform/    # control plane + team
        │   ├── 20-dataplane-ecs/       # Kong DP + OTel Collector sidecar + DP cert
        │   ├── 25-vault/               # AWS Secrets Manager + konnect_gateway_vault
        │   ├── 30-gateway-config/      # service + routes (from kong2tf) + rate-limiting/otel/prometheus
        │   ├── 40-kong-identity/       # auth server + OIDC + ACL
        │   ├── 60-dev-portal/          # portal + publish API + DCR strategy
        │   └── 70-observability/       # collector exporter -> Grafana Cloud (token in ASM)
        ├── specs/kongair-flights/openapi.yaml
        ├── scripts/oas-to-tf.sh
        ├── insomnia/
        ├── docs/gitops-setup.md        # this file
        └── README.md
```

The workflows key off `konnect/apigw/terraform`. If you ever move the main dir,
update it in exactly 4 places: the `paths:` trigger and the `TF_ROOT` line in
each of terraform-plan.yml and terraform-apply.yml.

Each `terraform/NN-*` folder is its own root/state (its own `backend "s3"` key).
The S3 `key` is an object name inside the bucket, NOT a filesystem path — it does
not change with the repo layout. Downstream stacks read upstream outputs with a
`terraform_remote_state` data source.

## One-time setup

1. Push this structure; protect `main` (require PR + passing checks).

2. Create a Konnect **System Account** and generate a token (CI's identity).

3. Apply `00-bootstrap` locally with admin AWS creds — from the repo root:
   ```bash
   cd konnect/apigw/terraform/00-bootstrap
   terraform init
   terraform apply -var 'github_repo=<ORG>/<REPO>'
   ```
   Note outputs: `state_bucket`, `github_actions_role_arn`.
   (If the account already has a GitHub OIDC provider, import it first — see the
   comment in `iam-github-oidc.tf`.)

4. Add repo secrets (Settings > Secrets and variables > Actions):
   - `AWS_ROLE_ARN` = `github_actions_role_arn`
   - `KONNECT_TOKEN` = the System Account token

5. Create the `production` environment (Settings > Environments) with required
   reviewers — the apply approval gate.

## Executing stack 10

1. Branch, edit `konnect/apigw/terraform/10-konnect-platform/**`, open a PR.
2. `terraform-plan` runs and posts the plan as a PR comment.
3. Review, approve, merge to `main`.
4. `terraform-apply` waits on the `production` approval, then applies. The
   control plane is created; `control_plane_id` is written to
   `s3://<bucket>/10-konnect-platform/terraform.tfstate`.
5. Stack 20 reads that output via `terraform_remote_state`.

Live, one stack at a time: **Actions > terraform-apply > Run workflow**, and pass
the full path `konnect/apigw/terraform/10-konnect-platform`.

## Running the OAS -> Terraform script
From the main dir, so its relative paths resolve:
```bash
cd konnect/apigw
./scripts/oas-to-tf.sh specs/kongair-flights/openapi.yaml
```

## Notes
- `00-bootstrap` is excluded from the pipeline (local state, admin-only).
- Apply order is enforced by `max-parallel: 1` + numeric prefixes.
