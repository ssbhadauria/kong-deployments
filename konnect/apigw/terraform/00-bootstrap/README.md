# Stack 00 — bootstrap (remote state + CI trust)

Applied **once, by hand, with an admin's AWS credentials**, before anything else.
It creates the foundation the rest of the repo depends on and is deliberately
**excluded from the GitHub Actions pipeline** (local state, and it creates the
very role CI uses — chicken-and-egg).

## What it creates
- **S3 bucket** `kong-refresher-tfstate` (versioned, encrypted, private) — the
  remote state backend every other stack uses.
- **DynamoDB table** `kong-refresher-tflock` — optional state lock (only needed
  if a stack uses `dynamodb_table` locking instead of `use_lockfile`).
- **GitHub OIDC provider** + **IAM role** `kong-refresher-gha-terraform` — lets
  GitHub Actions assume an AWS role via OIDC with **no static keys**. The role's
  ARN goes into the repo secret `AWS_ROLE_ARN`.

## Apply
```bash
cd konnect/apigw/terraform/00-bootstrap

# Use your admin SSO profile. If the AWS provider throws InvalidClientTokenId,
# the SDK isn't reading the SSO cache — export real creds into the shell:
eval "$(aws configure export-credentials --profile <YOUR_ADMIN_PROFILE> --format env)"

terraform init
terraform apply -var 'github_repo_name=ps-amer-kong-refresher'
```
Outputs: `state_bucket`, `lock_table`, `github_actions_role_arn`.

## Gotchas we hit (and the fixes, so the next person doesn't)

1. **AWS auth: `InvalidClientTokenId` even after `aws sso login`.**
   Terraform's AWS SDK didn't read the SSO cache. Fix: export real session creds
   with `aws configure export-credentials ... --format env` (see above). These
   are short-lived; re-run the `eval` line if a later apply fails with an expired
   token.

2. **OIDC provider already exists (`EntityAlreadyExists`).**
   There is only one GitHub OIDC provider per AWS account, and this account
   already had one. Import it before applying:
   ```bash
   terraform import aws_iam_openid_connect_provider.github \
     arn:aws:iam::412431539555:oidc-provider/token.actions.githubusercontent.com
   ```
   Importing means Terraform now MANAGES a shared, org-wide resource (it dropped
   a pre-existing owner tag on import). **Before any `terraform destroy` of
   bootstrap**, run `terraform state rm aws_iam_openid_connect_provider.github`
   or you'll delete a provider other Kong repos rely on.

3. **OIDC trust denied: `Not authorized to perform sts:AssumeRoleWithWebIdentity`.**
   The Kong GitHub org **customizes the OIDC subject claim** to embed numeric IDs,
   so the real `sub` is:
   `repo:Kong@962416/ps-amer-kong-refresher@1379024548:ref:refs/heads/main`
   A plain `repo:Kong/<repo>:*` never matches. The trust condition uses wildcards
   to absorb the IDs: `repo:${github_org}@*/${github_repo_name}@*:*`.
   (To harden later, append `:ref:refs/heads/main` to lock CI to the main branch.)

4. **`iam:UpdateAssumeRolePolicy` denied when editing the trust policy.**
   The `poweruser_custIAM` SSO role can create but not update a role's trust
   policy. Fix without new permissions — force a recreate (same name, same ARN,
   so the `AWS_ROLE_ARN` secret stays valid):
   ```bash
   terraform apply -replace='aws_iam_role.github_actions' -var 'github_repo_name=ps-amer-kong-refresher'
   ```

## After apply — wire up GitHub
- Repo secret `AWS_ROLE_ARN` = `github_actions_role_arn`
- Repo secret `KONNECT_TOKEN` = a Konnect token whose identity has **Control
  Plane Admin** (or Org Admin) — see stack 10's README for why.
- Environment `production` with required reviewers (the apply approval gate).

## Variables
- `github_org` (default `Kong`)
- `github_repo_name` (required, e.g. `ps-amer-kong-refresher`)
- `state_bucket_name`, `lock_table_name`, `create_lock_table`, `aws_region`, `name_prefix`, `tags`