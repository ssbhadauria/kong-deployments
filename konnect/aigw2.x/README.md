# aigw2.x — AI Gateway 2.x, GitOps with Terraform

The AI Gateway 2.x counterpart of `konnect/apigw`. Same discipline:
**one source-of-truth document → generated Terraform → `terraform apply` →
Konnect** — but targeting the AI Gateway 2.x entity model
(`konnect_ai_gateway_*` resources, kong/konnect provider >= 3.23) instead of
classic services/routes/plugins.

## Structure

```
aigw2.x/
├── README.md                        ← this file
├── docs/
│   └── mental-model.md              # apigw ↔ aigw2.x mapping + schema quirks
├── specs/
│   └── ps-copilot/
│       └── ai.yaml                  # SOURCE OF TRUTH: models, model_providers,
│                                    # mcp_servers, policies, auth, consumer groups
├── scripts/
│   ├── ai-to-tf.sh                  # pipeline entrypoint (mirrors apigw oas-to-tf.sh)
│   └── ai_to_tf.py                  # ai.yaml → HCL generator
└── terraform/
    └── 30-ai-gateway-config/        # the deployable stack
        ├── main.tf                  #   konnect_ai_gateway control plane
        ├── generate.sh              #   regenerates generated_ai_gateway.tf
        └── generated_ai_gateway.tf  #   (gitignored — built from the spec)
```

## The loop

```bash
# 1. Edit the source of truth
$EDITOR specs/ps-copilot/ai.yaml

# 2. Generate + validate + deploy
cd terraform/30-ai-gateway-config
./generate.sh
terraform init
TF_VAR_konnect_pat=<pat> TF_VAR_tech_llm_api_key=<key> terraform plan
TF_VAR_konnect_pat=<pat> TF_VAR_tech_llm_api_key=<key> terraform apply
```

State lives in the shared `kong-refresher-tfstate` bucket under
`30-ai-gateway-config/terraform.tfstate`, alongside the apigw stacks.

## Current contents (ps-copilot spec)

- **Model provider** `kong-tech-llms` — OpenAI-compatible LLMs on
  cloud.konghq.tech (auth header from `TF_VAR_tech_llm_api_key`)
- **Model** `ps-copilot` on `/ps` → routes `model: gpt-5.2` bodies to the
  .tech upstream, with cost metadata for RLA
- **MCP server** `kong-tech-tools` (`upstream-server`) on `/mcp/kong-tech`
- **Policies** — `ai-rate-limiting-advanced` ($5/hr cost budget per
  `kong-ps` consumer group), `ai-prompt-guard`, `ai-sanitizer`,
  `rate-limiting-advanced` on the MCP route
- **Auth** — built-in `key_auth` strategy (`apikey` header); consumers/keys
  are issued per engineer in Konnect
