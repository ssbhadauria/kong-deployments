output "service_id" {
  value = konnect_gateway_service.flights.id
}

output "route_names" {
  value = [
    konnect_gateway_route.health.name,
    konnect_gateway_route.flights_list.name,
    konnect_gateway_route.flight_by_number.name,
  ]
}
