#!/usr/bin/env bash
#
# OAS 3.0 -> Kong declarative config -> Terraform (Konnect)
#
# Answers: "deck command to convert OAS and then use the routes with TF".
# There is no manual route extraction: kong2tf emits konnect_gateway_service /
# konnect_gateway_route / konnect_gateway_plugin_* resources directly.
#
# Requires: deck (https://github.com/Kong/deck) with the `file` subcommands.
# Flag names vary slightly by deck version — run:
#     deck file openapi2kong --help
#     deck file kong2tf --help
# to confirm. Below uses the common -s/--spec and -o/--output-file forms.

set -euo pipefail

SPEC="${1:-specs/kongair-flights/openapi.yaml}"
BUILD_DIR="build"
KONG_YAML="${BUILD_DIR}/kongair-flights.kong.yaml"
TF_OUT="terraform/30-gateway-config/generated_gateway.tf"

mkdir -p "${BUILD_DIR}" "$(dirname "${TF_OUT}")"

echo ">> [1/2] OpenAPI -> Kong declarative config"
# Creates one Service (from the servers block) and one Route per operation.
# --inso-compatible skips UUID generation and matches on name — handy if you
# also manage these entities elsewhere; drop it to get stable generated IDs.
deck file openapi2kong \
  --spec "${SPEC}" \
  --output-file "${KONG_YAML}" \
  --format yaml

echo ">> [2/2] Kong declarative config -> Terraform (Konnect resources)"
# kong2tf is Konnect-only. The generated resources need a control_plane_id;
# wire it to stack 10's output. Depending on version, kong2tf either emits a
# `variable "control_plane_id"` you set, or you post-process. Check --help.
deck file kong2tf \
  --spec "${KONG_YAML}" \
  --output-file "${TF_OUT}"

echo ""
echo "Generated: ${TF_OUT}"
echo "Next:"
echo "  1. In ${TF_OUT}, point every control_plane_id at stack 10:"
echo "       control_plane_id = data.terraform_remote_state.platform.outputs.control_plane_id"
echo "  2. Review the generated routes/service, then:"
echo "       cd terraform/30-gateway-config && terraform init && terraform plan"
echo ""
echo "Plugins (rate-limiting, opentelemetry, prometheus) and consumers/groups"
echo "are added alongside the generated file in stack 30; OIDC + ACL in stack 40."
