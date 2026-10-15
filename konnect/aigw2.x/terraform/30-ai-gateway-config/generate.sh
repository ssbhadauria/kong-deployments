#!/usr/bin/env bash
# Runs in the pipeline (and locally) to turn the AI entity spec into Terraform.
# The spec is the source of truth; this file's output (generated_ai_gateway.tf)
# is gitignored and produced fresh each run.
set -euo pipefail

SPEC="../../specs/ps-copilot/ai.yaml"
OUT="generated_ai_gateway.tf"

../../scripts/ai-to-tf.sh "${SPEC}" "${OUT}"

echo ""
echo "Next: terraform init && terraform plan"
