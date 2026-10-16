#!/usr/bin/env python3
"""ai.yaml (AI Gateway 2.x entities) -> Terraform (kong/konnect >= 3.23).

Mirrors the apigw flow (openapi2kong -> kong2tf) but for AI Gateway 2.x:
the entity model maps ~1:1 onto konnect_ai_gateway_* resources, so no decK
conversion is needed. Config maps under each entity are passed through
verbatim — the TF provider validates them against the live schema at
`terraform validate` / `plan` time.

Placeholders in string values:
  ${var.name}  -> emitted as a Terraform variable reference (for secrets)

Usage: ai_to_tf.py <spec.ai.yaml> <output.tf>
"""

import json
import re
import sys
from pathlib import Path

import yaml

GATEWAY_ID = None  # set in main()


class Raw(str):
    """An HCL expression emitted verbatim (not quoted)."""


def tf_safe(ref: str) -> str:
    return re.sub(r"[^0-9A-Za-z_]", "_", str(ref))


def hcl(value, level=0):
    pad, pad_in = "  " * level, "  " * (level + 1)
    if isinstance(value, Raw):
        return str(value)
    if isinstance(value, dict):
        if not value:
            return "{}"
        lines = [f"{pad_in}{k} = {hcl(v, level + 1)}" for k, v in value.items() if v is not None]
        return "{\n" + "\n".join(lines) + f"\n{pad}}}"
    if isinstance(value, (list, tuple)):
        if not value:
            return "[]"
        if all(isinstance(x, (str, int, float, bool)) and not isinstance(x, Raw) for x in value):
            return "[" + ", ".join(hcl(x, level) for x in value) + "]"
        return "[\n" + ",\n".join(f"{pad_in}{hcl(x, level + 1)}" for x in value) + f"\n{pad}]"
    if isinstance(value, str):
        m = re.fullmatch(r"\$\{var\.([0-9A-Za-z_]+)\}", value)
        if m:
            return f"var.{m.group(1)}"
        return json.dumps(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    return str(value)


def resource(rtype, name, body):
    lines = [f"  {k} = {hcl(v, 1)}" for k, v in body.items() if v is not None]
    return f'resource "{rtype}" "{name}" {{\n' + "\n".join(lines) + "\n}\n"


def ref_mp(ref):
    return Raw(f"konnect_ai_gateway_model_provider.mp_{tf_safe(ref)}.name")


def ref_pol(ref):
    return Raw(f"konnect_ai_gateway_policy.pol_{tf_safe(ref)}.name")


def ref_auth(ref):
    return Raw(f"konnect_ai_gateway_auth_strategy.auth_{tf_safe(ref)}.name")


def policy_refs(entity):
    refs = entity.get("policies") or []
    return [ref_pol(r) for r in refs] or None


def gen(spec_path: str) -> str:
    spec = yaml.safe_load(Path(spec_path).read_text())
    out = []

    for p in spec.get("model_providers", []):
        ptype = p.get("type", "openai")
        body = {
            # top-level `name` is read-only on this resource; it lives in the vendor block
            "gateway_id": GATEWAY_ID,
            ptype: {
                "name": p["name"],
                "display_name": p.get("display_name"),
                "config": p.get("config"),
            },
        }
        out.append(resource("konnect_ai_gateway_model_provider", f"mp_{tf_safe(p['ref'])}", body))

    for m in spec.get("models", []):
        access = m.get("access") or {}
        inner = {
            # top-level `name` is read-only on this resource; name/display_name
            # are required INSIDE the model block.
            "name": m["name"],
            "display_name": m.get("display_name") or m["name"],
            "capabilities": m.get("capabilities"),
            "formats": m.get("formats"),
            "config": m.get("config"),
            "targets": [
                {
                    "name": t.get("name"),
                    "provider": ref_mp(t["provider"]),
                    "weight": t.get("weight"),
                    "config": t.get("config"),
                }
                for t in m.get("targets", [])
            ] or None,
            "access": (
                {"auth_strategies": [ref_auth(a) for a in access["auth_strategies"]]}
                if access.get("auth_strategies")
                else None
            ),
            "policies": policy_refs(m),
            "enabled": m.get("enabled"),
        }
        body = {"gateway_id": GATEWAY_ID, "model": inner}
        out.append(resource("konnect_ai_gateway_model", f"model_{tf_safe(m['ref'])}", body))

    for s in spec.get("mcp_servers", []):
        stype = str(s.get("type", "upstream-server")).replace("-", "_")
        # tools_cache_ttl_seconds is required by the provider schema; default it.
        config = {"tools_cache_ttl_seconds": 300, **(s.get("config") or {})}
        block = {
            # top-level `name` is read-only on this resource; it lives in the type block
            "name": s["name"],
            "display_name": s.get("display_name"),
            "enabled": s.get("enabled"),
            "config": config,
            "policies": policy_refs(s),
        }
        body = {"gateway_id": GATEWAY_ID, stype: block}
        out.append(resource("konnect_ai_gateway_mcp_server", f"mcp_{tf_safe(s['ref'])}", body))

    for p in spec.get("policies", []):
        body = {
            "name": p["name"],
            "display_name": p.get("display_name"),
            "gateway_id": GATEWAY_ID,
            "type": p["type"],
            "enabled": p.get("enabled"),
            "global": p.get("global"),
            "config": Raw(f"jsonencode({hcl(p.get('config', {}), 1)})"),
        }
        out.append(resource("konnect_ai_gateway_policy", f"pol_{tf_safe(p['ref'])}", body))

    for s in spec.get("auth_strategies", []):
        stype = str(s.get("type", "key_auth"))  # key_auth | openid_connect
        body = {
            # top-level `name`/`display_name` are read-only; they live in the type block,
            # and display_name is required there.
            "gateway_id": GATEWAY_ID,
            stype: {
                "name": s["name"],
                "display_name": s.get("display_name") or s["name"],
                "config": s.get("config"),
            },
        }
        out.append(resource("konnect_ai_gateway_auth_strategy", f"auth_{tf_safe(s['ref'])}", body))

    for g in spec.get("consumer_groups", []):
        body = {
            "name": g["name"],
            "display_name": g.get("display_name"),
            "gateway_id": GATEWAY_ID,
        }
        out.append(resource("konnect_ai_gateway_consumer_group", f"cg_{tf_safe(g['name'])}", body))

    header = (
        "# ---------------------------------------------------------------------------\n"
        "# GENERATED FILE - DO NOT EDIT.\n"
        f"# Source of truth: {spec_path}\n"
        "# Regenerate with: ../../scripts/ai-to-tf.sh (or ./generate.sh in this stack)\n"
        "# ---------------------------------------------------------------------------\n\n"
    )
    return header + "\n".join(out)


def main():
    global GATEWAY_ID
    if len(sys.argv) != 3:
        sys.exit("usage: ai_to_tf.py <spec.ai.yaml> <output.tf>")
    spec_path, out_path = sys.argv[1], sys.argv[2]
    GATEWAY_ID = Raw("konnect_ai_gateway.this.id")
    Path(out_path).write_text(gen(spec_path) + "\n")
    print(f"generated {out_path}")


if __name__ == "__main__":
    main()
