provider "konnect" {
  personal_access_token = var.konnect_pat
  server_url            = var.konnect_server_url
}

variable "konnect_pat" {
  type      = string
  sensitive = true
}

variable "konnect_server_url" {
  type    = string
  default = "https://us.api.konghq.com/"
}
