# Mental model: apigw → aigw2.x

The aigw2.x folder mirrors konnect/apigw's GitOps pattern, adapted for the
AI Gateway 2.x entity model.

## The pipeline

```
apigw:    openapi.yaml ── deck file openapi2kong ──▶ kong.yaml ── deck file kong2tf ──▶ generated_gateway.tf
aigw2.x:  ai.yaml      ── scripts/ai-to-tf.sh (straight mapping, no decK) ────────────▶ generated_ai_gateway.tf
```

Why no decK step: `openapi2kong` exists because OAS is a foreign format that
must be translated into Kong primitives. The AI Gateway 2.x entity file is
*already* Kong's native declarative format — and the konnect TF provider
(>= 3.23.0) exposes the same entities as `konnect_ai_gateway_*` resources —
so the conversion is a mechanical field mapping, not a format translation.

## The source-of-truth document

| OAS spec (apigw) | ai.yaml (aigw2.x) |
|---|---|
| `paths` / operations | `models[].config.route` (paths, model-body matching), `mcp_servers[].config.route` |
| `servers` (upstream) | `model_providers[]` (vendor type + auth), `targets[].config.<vendor>.upstream_url` |
| `x-kong-plugin-*` | `policies[]` — each `type` is the plugin of the same name (`ai-rate-limiting-advanced`, `ai-prompt-guard`, `ai-sanitizer`, …) |
| consumers/groups alongside | `consumer_groups[]`, `auth_strategies[]` |

## TF resources (kong/konnect ~> 3.25)

| ai.yaml section | Terraform resource |
|---|---|
| `ai_gateways` | `konnect_ai_gateway` (hand-written in `main.tf`) |
| `model_providers` | `konnect_ai_gateway_model_provider` |
| `models` | `konnect_ai_gateway_model` |
| `mcp_servers` | `konnect_ai_gateway_mcp_server` |
| `policies` | `konnect_ai_gateway_policy` |
| `auth_strategies` | `konnect_ai_gateway_auth_strategy` |
| `consumer_groups` | `konnect_ai_gateway_consumer_group` |

Also available if needed later: `konnect_ai_gateway_agent`,
`konnect_ai_gateway_custom_policy`, `konnect_ai_gateway_consumer(_credential)`,
`konnect_ai_gateway_vault`, `konnect_ai_gateway_data_plane_certificate`,
`konnect_ai_gateway_config_store(_secret)`.

## Known schema quirks (learned via `terraform validate`)

- Top-level `name` is read-only on model, model_provider, mcp_server, and
  auth_strategy — the name lives inside the type block (`model = { name … }`,
  `openai = { name … }`, `upstream_server = { name … }`, `key_auth = { name … }`).
- `display_name` is required inside `model` and `key_auth` blocks.
- `upstream_server.config.tools_cache_ttl_seconds` is required (defaulted to
  300 by the generator).
- Policy `config` is a JSON string → emitted as `jsonencode(...)`.
- Entity cross-references (`targets[].provider`, `policies[]`,
  `access.auth_strategies[]`) are by **name**; the generator wires them to the
  corresponding TF resource's `.name` so apply order is correct.
