#!/usr/bin/env python3
"""Write a small Markdown index for zig-out dashboard artifacts."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path


def category_for(path: Path) -> str:
    name = path.name
    if "validation" in name or "sidecar-corrupt" in name:
        return "validation"
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


def artifact_metadata(path: Path) -> str:
    stat = path.stat()
    mtime = dt.datetime.fromtimestamp(stat.st_mtime, tz=dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    return f"{stat.st_size} bytes, updated `{mtime}`"


def artifact_record(path: Path, output_dir: Path, producer_map: dict) -> dict:
    stat = path.stat()
    mtime = dt.datetime.fromtimestamp(stat.st_mtime, tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data = read_json(path) if path.suffix == ".json" else {}
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
        "rows": data.get("rows"),
        "ok": data.get("ok"),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default="zig-out", help="dashboard artifact directory")
    parser.add_argument("--output", default="zig-out/vort-dashboard-index.md", help="Markdown index path")
    parser.add_argument("--manifest", default="zig-out/vort-dashboard-index.json", help="JSON artifact manifest path")
    parser.add_argument("--producer-map", default="tools/dashboard_producers.json", help="JSON producer-step mapping path")
    parser.add_argument("--strict-producers", action="store_true", help="fail if any artifact lacks a producer_step")
    args = parser.parse_args()

    root = Path(args.dir)
    output = Path(args.output)
    manifest = Path(args.manifest)
    producer_map = load_producer_map(Path(args.producer_map))
    artifacts = sorted(
        path
        for path in root.glob("vort-*")
        if path.suffix in {".md", ".json"} and path.resolve() not in {output.resolve(), manifest.resolve()}
    )
    grouped: dict[str, list[Path]] = {}
    for artifact in artifacts:
        grouped.setdefault(category_for(artifact), []).append(artifact)

    records = [artifact_record(path, output.parent, producer_map) for path in artifacts]
    producer_step_missing = [record["name"] for record in records if not record["producer_step"] and not record["producer_missing_allowed"]]
    producer_step_allowed_missing = [record["name"] for record in records if not record["producer_step"] and record["producer_missing_allowed"]]
    producer_step_covered = len(records) - len(producer_step_missing)

    lines = [
        "# Vort dashboard index",
        "",
        "Generated from `zig-out` artifacts. Paths are relative to this index file.",
        f"",
        f"- artifacts: {len(artifacts)}",
        f"- producer steps: {producer_step_covered}/{len(records)}",
        f"- allowed missing producer steps: {len(producer_step_allowed_missing)}",
        "",
    ]
    for category in sorted(grouped):
        lines.extend([f"## {category}", ""])
        for artifact in grouped[category]:
            rel = artifact.relative_to(output.parent)
            note = json_summary(artifact) if artifact.suffix == ".json" else ""
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
    print(f"dashboard_index={output} manifest={manifest} artifacts={len(artifacts)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
