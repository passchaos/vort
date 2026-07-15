#!/usr/bin/env python3
"""Write a small Markdown index for zig-out dashboard artifacts."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
from pathlib import Path


def category_for(path: Path) -> str:
    name = path.name
    if "validation" in name or "sidecar-corrupt" in name or "header-inspect" in name or "dashboard-strict" in name:
        return "validation"
    if "bench" in name or "benchmark" in name:
        return "benchmark"
    if "standard" in name or "corpus" in name or "dictionary" in name:
        return "corpus and ratio"
    if "parallel" in name or "thread-pool" in name:
        return "native parallel"
    return "other"


def load_producer_map(path: Path) -> dict:
    data = read_json(path)
    if data.get("schema") != "vort.dashboard_producers":
        return {}
    return data


def producer_step_for(path: Path, producer_map: dict) -> str:
    name = path.name
    exact = producer_map.get("exact")
    if isinstance(exact, dict) and name in exact:
        return str(exact[name])

    contains = producer_map.get("contains")
    if isinstance(contains, list):
        for item in contains:
            if not isinstance(item, dict):
                continue
            match = item.get("match")
            producer = item.get("producer_step")
            if isinstance(match, str) and isinstance(producer, str) and match in name:
                return producer

    fallback_exact = {
        "vort-sidecar-corrupt-smoke.md": "zig build run-sidecar-corrupt-dashboard",
        "vort-sidecar-corrupt-smoke.json": "zig build run-sidecar-corrupt-dashboard",
        "vort-validation-json-smoke.json": "zig build run-validation-json-dashboard",
        "vort-dashboard-index.md": "zig build run-dashboard-index",
        "vort-dashboard-index.json": "zig build run-dashboard-index",
        "vort-dictionary-corpus-dashboard.md": "zig build -Doptimize=ReleaseFast run-dictionary-corpus-dashboard",
        "vort-file-corpus-standard-dashboard.md": "zig build -Doptimize=ReleaseFast run-file-corpus-standard-dashboard",
        "vort-file-corpus-standard-full-dashboard.md": "zig build -Doptimize=ReleaseFast run-file-corpus-standard-full-dashboard",
        "vort-native-parallel-dashboard.md": "zig build -Doptimize=ReleaseFast run-native-parallel-dashboard",
        "vort-native-thread-pool-full-dashboard.md": "zig build -Doptimize=ReleaseFast run-native-thread-pool-full-dashboard",
        "vort-standard-corpus-dashboard.md": "zig build -Doptimize=ReleaseFast run-standard-corpus-dashboard",
        "vort-standard-corpus-full-dashboard.md": "zig build -Doptimize=ReleaseFast run-standard-corpus-full-dashboard",
    }
    if name in fallback_exact:
        return fallback_exact[name]
    if "native-parallel" in name:
        return "zig build -Doptimize=ReleaseFast bench-native-parallel"
    if "path-dashboard" in name:
        return "zig build -Doptimize=ReleaseFast run-file-corpus-dashboard -- <paths>"
    if "tar-dashboard" in name:
        return "zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --paths <tar>"
    return ""


def is_allowed_missing(path: Path, producer_map: dict) -> bool:
    allow = producer_map.get("allow_missing")
    if not isinstance(allow, dict):
        return False
    name = path.name
    exact = allow.get("exact")
    if isinstance(exact, list) and name in exact:
        return True
    contains = allow.get("contains")
    if isinstance(contains, list):
        return any(isinstance(match, str) and match in name for match in contains)
    return False


def artifact_config_for(path: Path, producer_map: dict) -> dict:
    metadata = producer_map.get("artifact_metadata")
    if not isinstance(metadata, dict):
        return {}
    value = metadata.get(path.name)
    return value if isinstance(value, dict) else {}


def required_smoke_gates(producer_map: dict) -> list[str]:
    required = producer_map.get("required_smoke_gates")
    if not isinstance(required, list):
        return []
    return [name for name in required if isinstance(name, str)]


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text())
    except Exception:
        return {}
    return value if isinstance(value, dict) else {}


def json_summary(path: Path) -> str:
    data = read_json(path)
    if not data:
        return ""
    schema = data.get("schema")
    rows = data.get("rows")
    ok = data.get("ok")
    parts: list[str] = []
    if schema:
        parts.append(f"schema `{schema}`")
    if rows is not None:
        parts.append(f"rows `{rows}`")
    if ok is not None:
        parts.append(f"ok `{ok}`")
    return ", ".join(parts)


def csv_row_count(path: Path) -> int | None:
    try:
        with path.open(newline="") as f:
            return sum(1 for _ in csv.DictReader(f))
    except Exception:
        return None


def artifact_metadata(path: Path) -> str:
    stat = path.stat()
    mtime = dt.datetime.fromtimestamp(stat.st_mtime, tz=dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    return f"{stat.st_size} bytes, updated `{mtime}`"


def dashboard_strict_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.dashboard_strict_smoke":
            missing_modes = data.get("missing_modes")
            if not isinstance(missing_modes, list):
                missing_modes = []
            return {
                "present": True,
                "ok": bool(data.get("ok")),
                "check_count": int(data.get("check_count") or 0),
                "mode_count": int(data.get("mode_count") or 0),
                "expected_mode_count": int(data.get("expected_mode_count") or 0),
                "missing_mode_count": int(data.get("missing_mode_count") or 0),
                "missing_modes": missing_modes,
            }
    return {"present": False, "ok": False, "check_count": 0, "mode_count": 0, "expected_mode_count": 0, "missing_mode_count": 0, "missing_modes": []}


def header_inspect_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.header_inspect_smoke":
            missing_workflows = data.get("missing_workflows")
            if not isinstance(missing_workflows, list):
                missing_workflows = []
            return {
                "present": True,
                "ok": bool(data.get("ok")),
                "required_workflow_count": int(data.get("required_workflow_count") or 0),
                "missing_workflow_count": int(data.get("missing_workflow_count") or 0),
                "missing_workflows": missing_workflows,
            }
    return {
        "present": False,
        "ok": False,
        "required_workflow_count": 0,
        "missing_workflow_count": 0,
        "missing_workflows": [],
    }


def artifact_record(path: Path, output_dir: Path, producer_map: dict) -> dict:
    stat = path.stat()
    mtime = dt.datetime.fromtimestamp(stat.st_mtime, tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data = read_json(path) if path.suffix == ".json" else {}
    rows = data.get("rows")
    if rows is None and path.suffix == ".csv":
        rows = csv_row_count(path)
    producer_step = producer_step_for(path, producer_map)
    artifact_config = artifact_config_for(path, producer_map)
    expected_format = artifact_config.get("expected_format", "")
    if expected_format and expected_format != path.suffix.lstrip("."):
        raise ValueError(f"{path.name} expected format {expected_format!r} but found {path.suffix!r}")
    return {
        "name": path.name,
        "path": path.relative_to(output_dir).as_posix(),
        "category": category_for(path),
        "format": path.suffix.lstrip("."),
        "expected_format": expected_format,
        "producer_step": producer_step,
        "producer_missing_allowed": producer_step == "" and is_allowed_missing(path, producer_map),
        "smoke_gate": artifact_config.get("smoke_gate", ""),
        "size_bytes": stat.st_size,
        "mtime_utc": mtime,
        "schema": data.get("schema"),
        "schema_version": data.get("schema_version"),
        "rows": rows,
        "ok": data.get("ok"),
        "required_workflow_count": data.get("required_workflow_count") if data.get("schema") == "vort.header_inspect_smoke" else None,
        "missing_workflow_count": data.get("missing_workflow_count") if data.get("schema") == "vort.header_inspect_smoke" else None,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default="zig-out", help="dashboard artifact directory")
    parser.add_argument("--output", default="zig-out/vort-dashboard-index.md", help="Markdown index path")
    parser.add_argument("--manifest", default="zig-out/vort-dashboard-index.json", help="JSON artifact manifest path")
    parser.add_argument("--producer-map", default="tools/dashboard_producers.json", help="JSON producer-step mapping path")
    parser.add_argument("--strict-producers", action="store_true", help="fail if any artifact lacks a producer_step")
    parser.add_argument("--strict-smoke-gates", action="store_true", help="fail if required artifacts lack a smoke_gate")
    parser.add_argument("--strict-header-inspect", action="store_true", help="fail if header inspect artifact is missing, failed, or has missing workflows")
    args = parser.parse_args()

    root = Path(args.dir)
    output = Path(args.output)
    manifest = Path(args.manifest)
    producer_map = load_producer_map(Path(args.producer_map))
    artifacts = sorted(
        path
        for path in root.glob("vort-*")
        if path.suffix in {".csv", ".md", ".json"} and path.resolve() not in {output.resolve(), manifest.resolve()}
    )
    grouped: dict[str, list[Path]] = {}
    for artifact in artifacts:
        grouped.setdefault(category_for(artifact), []).append(artifact)

    records = [artifact_record(path, output.parent, producer_map) for path in artifacts]
    producer_step_missing = [record["name"] for record in records if not record["producer_step"] and not record["producer_missing_allowed"]]
    producer_step_allowed_missing = [record["name"] for record in records if not record["producer_step"] and record["producer_missing_allowed"]]
    producer_step_covered = len(records) - len(producer_step_missing)
    smoke_gate_missing = [record["name"] for record in records if not record["smoke_gate"]]
    smoke_gate_covered = len(records) - len(smoke_gate_missing)
    records_by_name = {record["name"]: record for record in records}
    smoke_gate_required_missing = [
        name
        for name in required_smoke_gates(producer_map)
        if name not in records_by_name or not records_by_name[name]["smoke_gate"]
    ]
    header_health = header_inspect_health(artifacts)
    strict_health = dashboard_strict_health(artifacts)

    lines = [
        "# Vort dashboard index",
        "",
        "Generated from `zig-out` artifacts. Paths are relative to this index file.",
        f"",
        f"- artifacts: {len(artifacts)}",
        f"- producer steps: {producer_step_covered}/{len(records)}",
        f"- allowed missing producer steps: {len(producer_step_allowed_missing)}",
        f"- smoke gates: {smoke_gate_covered}/{len(records)}",
        f"- required smoke gates missing: {len(smoke_gate_required_missing)}",
        f"- header inspect workflows: {header_health['required_workflow_count']} required, {header_health['missing_workflow_count']} missing",
        f"- dashboard strict smoke: {strict_health['check_count']} checks across {strict_health['mode_count']} modes ({strict_health['missing_mode_count']} missing)",
        "",
    ]
    if strict_health["missing_modes"]:
        lines.extend(["## Missing dashboard strict modes", "", "| mode | min checks | min expected failures | min matched |", "| --- | ---: | ---: | ---: |"])
        for row in strict_health["missing_modes"]:
            lines.append(f"| `{row.get('mode', '')}` | {row.get('min_checks', '')} | {row.get('min_expected_failures', '')} | {row.get('min_matched', '')} |")
        lines.append("")
    if header_health["missing_workflows"]:
        lines.extend(["## Missing header inspect workflows", "", "| command | workflow | format |", "| --- | --- | --- |"])
        for row in header_health["missing_workflows"]:
            lines.append(f"| `{row.get('command', '')}` | {row.get('workflow', '')} | {row.get('format', '')} |")
        lines.append("")
    for category in sorted(grouped):
        lines.extend([f"## {category}", ""])
        for artifact in grouped[category]:
            rel = artifact.relative_to(output.parent)
            if artifact.suffix == ".json":
                note = json_summary(artifact)
            elif artifact.suffix == ".csv":
                rows = csv_row_count(artifact)
                note = f"rows `{rows}`" if rows is not None else ""
            else:
                note = ""
            metadata = artifact_metadata(artifact)
            suffix = f" — {metadata}"
            producer_step = producer_step_for(artifact, producer_map)
            if producer_step:
                suffix += f", `{producer_step}`"
            if note:
                suffix += f", {note}"
            lines.append(f"- [{artifact.name}]({rel.as_posix()}){suffix}")
        lines.append("")
    if not artifacts:
        lines.append("_No dashboard artifacts found._")
        lines.append("")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines))
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(
        json.dumps(
            {
                "schema": "vort.dashboard_index",
                "schema_version": 1,
                "artifact_count": len(records),
                "producer_step_covered": producer_step_covered,
                "producer_step_allowed_missing": producer_step_allowed_missing,
                "producer_step_missing": producer_step_missing,
                "smoke_gate_covered": smoke_gate_covered,
                "smoke_gate_missing": smoke_gate_missing,
                "smoke_gate_required_missing": smoke_gate_required_missing,
                "header_inspect_present": header_health["present"],
                "header_inspect_ok": header_health["ok"],
                "header_inspect_required_workflow_count": header_health["required_workflow_count"],
                "header_inspect_missing_workflow_count": header_health["missing_workflow_count"],
                "header_inspect_missing_workflows": header_health["missing_workflows"],
                "dashboard_strict_present": strict_health["present"],
                "dashboard_strict_ok": strict_health["ok"],
                "dashboard_strict_check_count": strict_health["check_count"],
                "dashboard_strict_mode_count": strict_health["mode_count"],
                "dashboard_strict_expected_mode_count": strict_health["expected_mode_count"],
                "dashboard_strict_missing_mode_count": strict_health["missing_mode_count"],
                "dashboard_strict_missing_modes": strict_health["missing_modes"],
                "artifacts": records,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )
    if args.strict_producers and producer_step_missing:
        missing = ",".join(producer_step_missing)
        raise SystemExit(f"dashboard_index_missing_producers={missing}")
    if args.strict_smoke_gates and smoke_gate_required_missing:
        missing = ",".join(smoke_gate_required_missing)
        raise SystemExit(f"dashboard_index_missing_smoke_gates={missing}")
    if args.strict_header_inspect:
        if not header_health["present"]:
            raise SystemExit("dashboard_index_missing_header_inspect=1")
        if not header_health["ok"]:
            raise SystemExit("dashboard_index_header_inspect_failed=1")
        if header_health["missing_workflow_count"]:
            missing = ",".join(f"{row.get('command')}:{row.get('workflow')}" for row in header_health["missing_workflows"])
            raise SystemExit(f"dashboard_index_header_inspect_missing_workflows={header_health['missing_workflow_count']}:{missing}")
    print(f"dashboard_index={output} manifest={manifest} artifacts={len(artifacts)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
