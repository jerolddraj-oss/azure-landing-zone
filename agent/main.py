#!/usr/bin/env python3
"""CAF landing-zone requirements agent.

The optional LLM step only translates natural-language requests into a strict
JSON schema. All generated values are validated locally before Terraform sees
them. The agent never authenticates to Azure or runs terraform apply.
"""
from __future__ import annotations

import argparse
import ipaddress
import json
import os
import re
import sys
from pathlib import Path
from typing import Any
from uuid import UUID

SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["subscription_id", "location", "name_prefix", "hub_address_space", "common_tags"],
    "properties": {
        "subscription_id": {"type": "string"},
        "location": {"type": "string"},
        "name_prefix": {"type": "string"},
        "hub_address_space": {"type": "array", "items": {"type": "string"}, "minItems": 1},
        "common_tags": {"type": "object", "additionalProperties": {"type": "string"}},
    },
}

SYSTEM_PROMPT = """You translate Azure CAF landing-zone requests into configuration JSON.
Return only values supported by the supplied schema. Do not invent a subscription ID:
use 00000000-0000-0000-0000-000000000000 if the user did not provide one.
Defaults: location East US, name_prefix jd-alz, hub_address_space [10.0.0.0/16].
Default tags: project=azure-landing-zone, environment=platform, managed_by=terraform.
Never output credentials, secrets, or Azure permissions. This agent configures the
existing Terraform root; it does not deploy resources or modify HCL."""


def parse_request_with_openai(request: str) -> dict[str, Any]:
    """Use the OpenAI Responses API for natural-language requirement extraction."""
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("--request requires OPENAI_API_KEY. Alternatively use --config.")
    try:
        from openai import OpenAI
    except ImportError as exc:
        raise ValueError("Install agent dependencies with: pip install -r agent/requirements.txt") from exc

    client = OpenAI(api_key=api_key)
    response = client.responses.create(
        model=os.environ.get("OPENAI_MODEL", "gpt-4.1-mini"),
        input=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": request},
        ],
        text={
            "format": {
                "type": "json_schema",
                "name": "azure_landing_zone_requirements",
                "strict": True,
                "schema": SCHEMA,
            }
        },
    )
    text = response.output_text
    if not text:
        raise ValueError("The AI model returned no structured output.")
    return json.loads(text)


def validate_config(config: dict[str, Any]) -> dict[str, Any]:
    required = set(SCHEMA["required"])
    missing = required - config.keys()
    extra = config.keys() - required
    if missing:
        raise ValueError(f"Missing required fields: {', '.join(sorted(missing))}")
    if extra:
        raise ValueError(f"Unsupported fields: {', '.join(sorted(extra))}")

    try:
        UUID(config["subscription_id"])
    except (ValueError, TypeError, AttributeError) as exc:
        raise ValueError("subscription_id must be a valid UUID.") from exc

    location = config["location"]
    if not isinstance(location, str) or not location.strip() or len(location) > 80:
        raise ValueError("location must be a non-empty Azure region name.")
    prefix = config["name_prefix"]
    if not isinstance(prefix, str) or not re.fullmatch(r"[a-zA-Z0-9-]{2,20}", prefix):
        raise ValueError("name_prefix must be 2-20 characters: letters, digits, hyphens.")

    cidrs = config["hub_address_space"]
    if not isinstance(cidrs, list) or not cidrs:
        raise ValueError("hub_address_space must be a non-empty list of IPv4 CIDRs.")
    networks = []
    for cidr in cidrs:
        try:
            network = ipaddress.ip_network(cidr, strict=True)
        except ValueError as exc:
            raise ValueError(f"Invalid CIDR {cidr!r}: {exc}") from exc
        if network.version != 4:
            raise ValueError("Only IPv4 address spaces are supported by this starter.")
        networks.append(network)
    for i, left in enumerate(networks):
        for right in networks[i + 1:]:
            if left.overlaps(right):
                raise ValueError(f"Hub CIDR ranges overlap: {left} and {right}.")

    tags = config["common_tags"]
    if not isinstance(tags, dict) or not all(
        isinstance(k, str) and isinstance(v, str) for k, v in tags.items()
    ):
        raise ValueError("common_tags must be a string-to-string object.")
    if len(tags) > 50:
        raise ValueError("Azure resources support a maximum of 50 tags.")

    return {
        "subscription_id": config["subscription_id"],
        "location": location.strip(),
        "name_prefix": prefix.lower(),
        "hub_address_space": [str(n) for n in networks],
        "common_tags": tags,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate validated Terraform variables for the Azure CAF landing zone.")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--config", type=Path, help="JSON file with landing-zone requirements.")
    source.add_argument("--request", help="Natural-language request (requires OPENAI_API_KEY and agent dependencies).")
    parser.add_argument("--output", type=Path, default=Path("environments/eastus/terraform.tfvars.json"))
    parser.add_argument("--dry-run", action="store_true", help="Validate and print JSON without writing a file.")
    args = parser.parse_args()

    try:
        raw = parse_request_with_openai(args.request) if args.request else json.loads(args.config.read_text(encoding="utf-8"))
        validated = validate_config(raw)
        rendered = json.dumps(validated, indent=2) + "\n"
        if args.dry_run:
            print(rendered, end="")
            return 0
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
        print(f"Validated Terraform variables written to: {args.output}")
        print("Review the generated file and Terraform plan before any deployment.")
        return 0
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
