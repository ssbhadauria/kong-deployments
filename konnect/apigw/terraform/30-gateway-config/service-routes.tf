# ---------------------------------------------------------------------------
# Flights service + routes.
#
# This is the committed equivalent of what
#   scripts/oas-to-tf.sh  (deck file openapi2kong -> deck file kong2tf)
# produces from specs/kongair-flights/openapi.yaml. It's checked in (rather than
# generated in CI) so plans are deterministic; re-run the script to regenerate
# if the spec changes. One Service + one Route per OAS operation.
# ---------------------------------------------------------------------------

resource "konnect_gateway_service" "flights" {
  control_plane_id = local.control_plane_id
  name             = "flights-service"
  protocol         = var.flights_upstream_protocol
  host             = var.flights_upstream_host
  port             = var.flights_upstream_port
  path             = "/"
  tags             = var.tags
}

# GET /health
resource "konnect_gateway_route" "health" {
  control_plane_id = local.control_plane_id
  name             = "flights-service_get-health"
  service          = { id = konnect_gateway_service.flights.id }
  methods          = ["GET"]
  paths            = ["~/health$"]
  strip_path       = false
  tags             = var.tags
}

# GET /flights
resource "konnect_gateway_route" "flights_list" {
  control_plane_id = local.control_plane_id
  name             = "flights-service_get-flights"
  service          = { id = konnect_gateway_service.flights.id }
  methods          = ["GET"]
  paths            = ["~/flights$"]
  strip_path       = false
  tags             = var.tags
}

# GET /flights/{flightNumber}
resource "konnect_gateway_route" "flight_by_number" {
  control_plane_id = local.control_plane_id
  name             = "flights-service_get-flight-by-number"
  service          = { id = konnect_gateway_service.flights.id }
  methods          = ["GET"]
  paths            = ["~/flights/(?<flightNumber>[^#?/]+)$"]
  strip_path       = false
  tags             = var.tags
}
