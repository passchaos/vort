#!/usr/bin/env python3
"""Validate dashboard producer-map required artifact coverage."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

from validation_json_docs_check import load_manifest, validate_value_against_manifest


ROOT = Path(__file__).resolve().parents[1]
PRODUCERS = ROOT / "tools" / "dashboard_producers.json"
REQUIRED = ROOT / "tools" / "dashboard_producers_required_artifacts.json"


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise AssertionError(f"{path} must contain a JSON object")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", help="optional JSON summary output path")
    args = parser.parse_args()

    producers = load_json(PRODUCERS)
    required = load_json(REQUIRED)
    if producers.get("schema") != "vort.dashboard_producers":
        raise AssertionError("unexpected dashboard producers schema")
    if required.get("schema") != "vort.dashboard_producers_required_artifacts":
        raise AssertionError("unexpected dashboard producer required artifacts schema")
    if producers.get("schema_version") != 1 or required.get("schema_version") != 1:
        raise AssertionError("unsupported dashboard producer schema version")

    exact = producers.get("exact")
    metadata = producers.get("artifact_metadata")
    required_smoke_gates = producers.get("required_smoke_gates")
    rows = required.get("required_artifacts")
    if not isinstance(exact, dict) or not isinstance(metadata, dict) or not isinstance(required_smoke_gates, list) or not isinstance(rows, list):
        raise AssertionError("dashboard producer configs have invalid collection fields")

    required_gate_set = {name for name in required_smoke_gates if isinstance(name, str)}
    cases: list[dict[str, object]] = []
    seen: set[str] = set()

    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise AssertionError(f"required_artifacts[{index}] must be an object")
        name = row.get("name")
        expected_producer = row.get("producer_step")
        expected_format = row.get("expected_format")
        expected_smoke_gate = row.get("smoke_gate")
        expected_required = row.get("required_smoke_gate")
        if not isinstance(name, str):
            raise AssertionError(f"required_artifacts[{index}].name must be a string")
        if name in seen:
            raise AssertionError(f"duplicate required artifact {name!r}")
        seen.add(name)
        actual_metadata = metadata.get(name)
        actual_producer = exact.get(name)
        actual_format = actual_metadata.get("expected_format") if isinstance(actual_metadata, dict) else None
        actual_smoke_gate = actual_metadata.get("smoke_gate") if isinstance(actual_metadata, dict) else None
        actual_required = name in required_gate_set
        matched = (
            actual_producer == expected_producer
            and actual_format == expected_format
            and actual_smoke_gate == expected_smoke_gate
            and actual_required == expected_required
        )
        cases.append(
            {
                "name": name,
                "producer_step": str(actual_producer or ""),
                "configured_producer_step": str(expected_producer or ""),
                "expected_format": str(actual_format or ""),
                "configured_expected_format": str(expected_format or ""),
                "smoke_gate": str(actual_smoke_gate or ""),
                "configured_smoke_gate": str(expected_smoke_gate or ""),
                "required_smoke_gate": actual_required,
                "configured_required_smoke_gate": bool(expected_required),
                "matched": matched,
            }
        )

    missing_required = sorted(set(exact) - seen)
    extra_required = sorted(seen - set(exact))
    if missing_required or extra_required:
        raise AssertionError(f"dashboard producer required artifact drift: missing={missing_required!r} extra={extra_required!r}")

    metadata_without_exact = sorted(set(metadata) - set(exact))
    exact_without_metadata = sorted(set(exact) - set(metadata))
    required_gate_without_metadata = sorted(required_gate_set - set(metadata))
    if metadata_without_exact or exact_without_metadata or required_gate_without_metadata:
        raise AssertionError(
            "dashboard producer map internal drift: "
            f"metadata_without_exact={metadata_without_exact!r} "
            f"exact_without_metadata={exact_without_metadata!r} "
            f"required_gate_without_metadata={required_gate_without_metadata!r}"
        )

    summary = {
        "schema": "vort.dashboard_producers_required_smoke",
        "schema_version": 1,
        "ok": all(bool(row["matched"]) for row in cases),
        "artifact_count": len(cases),
        "required_smoke_gate_count": sum(1 for row in cases if row["required_smoke_gate"]),
        "cases": cases,
    }
    validate_value_against_manifest(summary, load_manifest())

    if args.summary:
        path = Path(args.summary)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    if not summary["ok"]:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 1
    print(f"dashboard_producers_required_smoke=ok artifacts={summary['artifact_count']} required_smoke_gates={summary['required_smoke_gate_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
