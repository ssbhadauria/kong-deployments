#!/usr/bin/env bash
#
# AI Gateway 2.x entity spec -> Terraform (Konnect)
#
# The aigw2.x equivalent of apigw's oas-to-tf.sh. One difference: no decK
# conversion step — the AI Gateway 2.x entity model maps ~1:1 onto
# konnect_ai_gateway_* resources, so this is a straight generator.
#
#   ai.yaml --(ai_to_tf.py)--> generated_ai_gateway.tf --> terraform apply
#
# Usage: ai-to-tf.sh <spec.ai.yaml> <output.tf>

set -euo pipefail

SPEC="${1:?usage: ai-to-tf.sh <spec.ai.yaml> <output.tf>}"
OUT="${2:?usage: ai-to-tf.sh <spec.ai.yaml> <output.tf>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The generator needs PyYAML; install it if the runner doesn't have it.
if ! python3 -c "import yaml" >/dev/null 2>&1; then
  echo ">> installing pyyaml"
  python3 -m pip install --quiet --user pyyaml
fi

python3 "${SCRIPT_DIR}/ai_to_tf.py" "${SPEC}" "${OUT}"

# Keep the pipeline's fmt -check happy.
terraform fmt "${OUT}" >/dev/null 2>&1 || true

echo ">> generated resources:"
grep -E '^resource ' "${OUT}" || true
