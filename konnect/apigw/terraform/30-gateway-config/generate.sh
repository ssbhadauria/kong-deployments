#!/usr/bin/env bash
# Runs in the pipeline (and locally) to turn the OAS into Kong Terraform.
# The spec is the source of truth; this file's output (generated_gateway.tf)
# is gitignored and produced fresh each run.
set -euo pipefail

DECK_VERSION="1.43.1" # bump if the download 404s (check github.com/kong/deck/releases)
SPEC="../../specs/kongair-flights/openapi.yaml"
OUT="generated_gateway.tf"

# Install deck if the runner doesn't have it.
if ! command -v deck >/dev/null 2>&1; then
  echo ">> installing deck ${DECK_VERSION}"
  curl -sSL "https://github.com/kong/deck/releases/download/v${DECK_VERSION}/deck_${DECK_VERSION}_linux_amd64.tar.gz" | tar -xz -C /tmp deck
  sudo mv /tmp/deck /usr/local/bin/deck
fi
deck version

mkdir -p build
echo ">> [1/2] OpenAPI -> decK"
deck file openapi2kong -s "$SPEC" -o build/kong.yaml

echo ">> [2/2] decK -> Terraform (Konnect)"
# If the input flag differs in your deck version, check `deck file kong2tf --help`.
deck file kong2tf -s build/kong.yaml -o "$OUT"

echo ">> rewiring control_plane_id to stack 10 remote state"
# kong2tf emits `control_plane_id = var.control_plane_id` + a variable block with
# a placeholder default. Drop that variable and point at the platform remote state
# (declared in providers.tf). Also drop any import{} blocks (none expected from a
# fresh openapi2kong output, but safe).
sed -i '/variable "control_plane_id"/,/^}/d' "$OUT"
sed -i 's/var\.control_plane_id/data.terraform_remote_state.platform.outputs.control_plane_id/g' "$OUT"

# Make the generated file fmt-clean so the pipeline's fmt -check passes.
terraform fmt "$OUT" >/dev/null 2>&1 || true

echo ">> generated:"
grep -E '^resource ' "$OUT" || true
