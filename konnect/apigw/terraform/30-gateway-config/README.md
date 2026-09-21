# Stack 30 — Gateway config (KongAir Flights)

The first stack that makes traffic actually flow: one Service + three Routes for
KongAir Flights, plus the first plugins.

## OAS-driven
`service-routes.tf` is the committed equivalent of
`scripts/oas-to-tf.sh` (`deck file openapi2kong` -> `deck file kong2tf`) run on
`specs/kongair-flights/openapi.yaml`. One Service, one Route per operation:
- `GET /health`
- `GET /flights`
- `GET /flights/{flightNumber}`

Regenerate after editing the spec:
```bash
cd konnect/apigw
./scripts/oas-to-tf.sh specs/kongair-flights/openapi.yaml
# review, then replace service-routes.tf with the generated output
```

## Upstream
The Service points at **`https://api.kong-air.com`** (KongAir's live public API)
by default, so no backend needs deploying — the DP proxies to it over NAT.
Override `flights_upstream_*` to point at your own KongAir (e.g. in EKS).

## Plugins (layered simplest-first)
1. **rate-limiting** on the service — 5/min, easy to trip in Insomnia.
2. **opentelemetry** on the service — traces/logs to the collector sidecar
   (`localhost:4318`). Non-fatal if the collector is down.
3. **prometheus** global — metrics on `:8100/metrics` for the collector.

## Apply
Pipeline as usual: `Actions → terraform-apply → Run workflow →`
`konnect/apigw/terraform/30-gateway-config`. Order: 10 → 20 → 25 → **30** → 40.

## Test after apply
```bash
# list flights (proxied to api.kong-air.com)
curl http://<proxy_nlb_dns>/flights
# trip the rate limit: 6 quick calls, the 6th returns 429
for i in $(seq 1 6); do curl -s -o /dev/null -w "%{http_code}\n" http://<proxy_nlb_dns>/flights; done
```
`<proxy_nlb_dns>` is stack 20's `proxy_nlb_dns` output. A `200` with flight JSON
means routing works; a `429` on the 6th call means rate-limiting works.

## Notes
- Typed plugin resource names / config fields are provider-version dependent;
  if the plan errors on a plugin, check the provider schema.
- OIDC + ACL are added in stack 40 (they'll layer auth on top of these routes).
