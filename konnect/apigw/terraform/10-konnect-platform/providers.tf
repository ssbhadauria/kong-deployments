provider "konnect" {
  # Konnect Personal Access Token (or a System Account token for CI).
  # Prefer supplying via env var: export TF_VAR_konnect_pat=...
  personal_access_token = var.konnect_pat

  # Region-specific API URL. US: https://us.api.konghq.com/
  # EU: https://eu.api.konghq.com/  |  AU: https://au.api.konghq.com/
  server_url = var.konnect_server_url
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}
