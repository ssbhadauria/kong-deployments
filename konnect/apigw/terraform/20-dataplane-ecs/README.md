# Stack 20 — data plane on ECS (+ OTel Collector sidecar)

Runs a Kong Gateway **data plane** on Fargate in the existing us-west-1 VPC,
connected to the stack 10 control plane in hybrid mode, fronted by an
internet-facing NLB, with an **OTel Collector sidecar** shipping telemetry to
Grafana Cloud.

## What it creates
- **ECS Fargate service** (`desired_count = 2`, private subnets) with a task of
  two containers:
  - `kong` — the DP (`KONG_ROLE=data_plane`, `KONG_KONNECT_MODE=on`, `cluster_mtls=pki`).
  - `otel-collector` (sidecar, `essential=false`) — scrapes `localhost:8100/metrics`,
    receives OTLP on `localhost:4317/4318`, exports via `otlphttp` + basicauth to
    Grafana Cloud (HTTP-only OTLP).
- **DP client cert** (`tls_*`) registered to the CP via
  `konnect_gateway_data_plane_client_certificate`; the private key lives in ASM
  and is injected as `KONG_CLUSTER_CERT_KEY`.
- **Two ASM secrets** — DP key and Grafana token — injected via ECS `secrets`.
- **Internet-facing NLB** (public subnets) → TCP 80→8000, 443→8443; security
  groups so only the NLB (VPC CIDR) reaches the proxy ports.

The DP control-plane / telemetry hosts are **derived automatically** from the
Konnect API at plan time (`data.http.control_plane` in `data.tf`, using the
`control_plane_id` from stack 10). Nothing to copy by hand.

## Prerequisites (do these before applying)

1. **Add the GitHub secret** `GRAFANA_CLOUD_OTLP_TOKEN` = your (freshly rotated)
   Grafana Cloud access-policy token with metrics/logs/traces write scopes. The
   pipeline forwards it as `TF_VAR_grafana_otlp_token`.

3. `terraform fmt -recursive` from the repo root before pushing (CI enforces it).

## Apply
Via the pipeline: **Actions → terraform-apply → Run workflow →**
`konnect/apigw/terraform/20-dataplane-ecs`.

## Verify
- Konnect → Gateway Manager → the CP should show a **connected** data plane node.
- `terraform output proxy_nlb_dns` → the public hostname. Until stack 30 adds a
  service/route, `curl http://<nlb-dns>/` returns Kong's 404 ("no Route matched")
  — that's success (the proxy is live).
- Grafana Cloud → Explore: DP metrics appear once stack 30 enables the Prometheus
  plugin (the `:8100/metrics` scrape is inert until then; the collector logs
  scrape errors meanwhile, which is expected).

## Notes / things to verify on your provider + images
- `konnect_gateway_data_plane_client_certificate` — confirm resource/attribute
  names against your pinned `kong/konnect` version.
- Bump `kong_image` / `otel_collector_image` to current stable tags.
- The collector uses `--config=env:OTELCOL_CONFIG` (config-from-env) because the
  contrib image is distroless (no shell to write a file).
- State backend region is **us-east-2** (bucket location); the AWS provider runs
  in **us-west-1**. Both are correct and independent.
