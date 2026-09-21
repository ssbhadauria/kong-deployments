# ---------------------------------------------------------------------------
# Stack 10 — Konnect platform
# Creates the control plane the ECS data plane (stack 20) will attach to.
#
# auth_type = "pinned_client_certs" means the data plane authenticates to the
# control plane with a client certificate we generate and register in stack 20
# (konnect_gateway_data_plane_client_certificate). This is the hybrid-mode
# trust model for a self-managed DP running in ECS.
# ---------------------------------------------------------------------------

resource "konnect_gateway_control_plane" "this" {
  name         = var.control_plane_name
  description  = "KongAir refresher — hybrid control plane for the ECS data plane"
  cluster_type = "CLUSTER_TYPE_CONTROL_PLANE"
  auth_type    = "pinned_client_certs"

  labels = var.tags

  # proxy_urls is metadata telling Konnect (and the Dev Portal) where the DP is
  # reachable. We don't know the ECS load balancer hostname yet, so it's left
  # unset here and added in stack 20 once the LB exists. Example once known:
  #
  # proxy_urls = [{
  #   host     = "kongair.example.com"
  #   port     = 443
  #   protocol = "https"
  # }]
}

# ---------------------------------------------------------------------------
# Team (pattern example)
# A Konnect org team that can administer this control plane. Wire real users or
# a system account to it via role assignments.
#
# NOTE: role-assignment resource names have shifted between provider releases
# (e.g. konnect_team_role_assignment / konnect_role). Confirm the exact
# resource + entity_type_name/role_name values against `terraform providers
# schema -json` for your pinned version before uncommenting.
# ---------------------------------------------------------------------------

resource "konnect_team" "platform_admins" {
  name        = "${var.name_prefix}-platform-admins"
  description = "Administers the KongAir refresher control plane"
  labels      = var.tags
}

# resource "konnect_team_role_assignment" "platform_admins_cp_admin" {
#   team_id                 = konnect_team.platform_admins.id
#   entity_id               = konnect_gateway_control_plane.this.id
#   entity_type_name        = "control-planes"
#   entity_region           = "us"
#   role_name               = "Admin"
# }
