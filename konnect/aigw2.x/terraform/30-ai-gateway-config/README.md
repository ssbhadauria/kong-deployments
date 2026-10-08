# 30-ai-gateway-config

Deploys the AI Gateway 2.x control plane and everything declared in
`../../specs/ps-copilot/ai.yaml`: model provider, model, MCP server,
policies (RLA budget, prompt guard, sanitizer), auth strategy, consumer group.

## Flow

```
../../specs/ps-copilot/ai.yaml   (source of truth — edit THIS, never the .tf)
        │  ./generate.sh   (../../scripts/ai-to-tf.sh)
        ▼
generated_ai_gateway.tf          (gitignored, regenerated every run)
        │  terraform apply
        ▼
Konnect AI Gateway 2.x control plane
```

## Usage

```bash
./generate.sh
terraform init
TF_VAR_konnect_pat=<pat> TF_VAR_tech_llm_api_key=<.tech key> terraform plan
TF_VAR_konnect_pat=<pat> TF_VAR_tech_llm_api_key=<.tech key> terraform apply
```

`terraform validate` in CI runs after `generate.sh` — it type-checks the
generated resources against the provider schema (kong/konnect ~> 3.25).

## Notes

- Provider pin is `~> 3.25` because `konnect_ai_gateway_*` resources first
  appeared in **3.23.0**. Do not downgrade below that.
- `main.tf` owns only the control plane (`konnect_ai_gateway.this`); every
  entity inside it is generated from the spec.
- The generator encodes provider-schema quirks learned from `terraform
  validate`: top-level `name` is read-only on model/model_provider/
  mcp_server/auth_strategy (names live inside the type block),
  `tools_cache_ttl_seconds` defaults to 300 on `upstream_server`.
