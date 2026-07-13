#!/usr/bin/env python3
"""Validate JSON examples embedded in docs/validation-json.md."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs" / "validation-json.md"


EXPECTED_SCHEMAS = {
    "vort.validation_report",
    "vort.sidecar_verify_report",
    "vort.sidecar_corrupt_smoke_report",
    "vort.validation_json_smoke",
    "vort.dashboard_index",
    "vort.dashboard_producers",
}


def main() -> int:
    text = DOC.read_text()
    blocks = re.findall(r"```json\n(.*?)\n```", text, re.S)
    parsed = [json.loads(block) for block in blocks]
    schemas = {value.get("schema") for value in parsed if isinstance(value, dict)}
    missing = EXPECTED_SCHEMAS - schemas
    if missing:
        raise AssertionError(f"missing schema examples: {sorted(missing)}")
    if len(parsed) != len(EXPECTED_SCHEMAS):
        raise AssertionError(f"expected {len(EXPECTED_SCHEMAS)} examples, found {len(parsed)}")
    print(f"validation_json_docs=ok examples={len(parsed)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
