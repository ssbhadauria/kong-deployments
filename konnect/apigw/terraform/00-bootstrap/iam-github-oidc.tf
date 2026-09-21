# ---------------------------------------------------------------------------
# GitHub Actions OIDC -> AWS (no static access keys in CI)
# Applied once by an admin as part of 00-bootstrap. The pipeline assumes this
# role via OIDC; its ARN goes into the repo secret AWS_ROLE_ARN.
# ---------------------------------------------------------------------------

variable "name_prefix" {
  type    = string
  default = "kong-refresher"
}

variable "github_org" {
  description = "GitHub org that owns the repo (used in the OIDC subject match)."
  type        = string
  default     = "Kong"
}

variable "github_repo_name" {
  description = "GitHub repository name (no org). e.g. ps-amer-kong-refresher"
  type        = string
}

# Fetches GitHub's OIDC cert so the thumbprint is always current.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

# One OIDC provider per AWS account. If it already exists in the account, import
# it instead of creating a duplicate:
#   terraform import aws_iam_openid_connect_provider.github \
#     arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # NOTE: The Kong GitHub org customizes the OIDC subject claim to embed
    # internal numeric IDs, so the real `sub` looks like:
    #   repo:Kong@962416/ps-amer-kong-refresher@1379024548:ref:refs/heads/main
    # The wildcards below absorb those IDs. A plain "repo:Kong/<repo>:*" will
    # NOT match and fails with "Not authorized to perform sts:AssumeRoleWithWebIdentity".
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}@*/${var.github_repo_name}@*:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.name_prefix}-gha-terraform"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

# DEMO SCOPE ONLY. Across stacks this role provisions VPC, ECS, IAM roles and
# Secrets Manager, so it's broad. TIGHTEN to least-privilege for anything real.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_role_arn" {
  description = "Put this in the GitHub repo secret AWS_ROLE_ARN."
  value       = aws_iam_role.github_actions.arn
}
