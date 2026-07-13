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


def artifact_record(path: Path, output_dir: Path) -> dict:
    stat = path.stat()
    mtime = dt.datetime.fromtimestamp(stat.st_mtime, tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data = read_json(path) if path.suffix == ".json" else {}
    return {
        "name": path.name,
        "path": path.relative_to(output_dir).as_posix(),
        "category": category_for(path),
        "format": path.suffix.lstrip("."),
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
    args = parser.parse_args()

    root = Path(args.dir)
    output = Path(args.output)
    manifest = Path(args.manifest)
    artifacts = sorted(
        path
        for path in root.glob("vort-*")
        if path.suffix in {".md", ".json"} and path.resolve() not in {output.resolve(), manifest.resolve()}
    )
    grouped: dict[str, list[Path]] = {}
    for artifact in artifacts:
        grouped.setdefault(category_for(artifact), []).append(artifact)

    lines = [
        "# Vort dashboard index",
        "",
        "Generated from `zig-out` artifacts. Paths are relative to this index file.",
        f"",
        f"- artifacts: {len(artifacts)}",
        "",
    ]
    for category in sorted(grouped):
        lines.extend([f"## {category}", ""])
        for artifact in grouped[category]:
            rel = artifact.relative_to(output.parent)
            note = json_summary(artifact) if artifact.suffix == ".json" else ""
            metadata = artifact_metadata(artifact)
            suffix = f" — {metadata}"
            if note:
                suffix += f", {note}"
            lines.append(f"- [{artifact.name}]({rel.as_posix()}){suffix}")
        lines.append("")
    if not artifacts:
        lines.append("_No dashboard artifacts found._")
        lines.append("")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines))
    records = [artifact_record(path, output.parent) for path in artifacts]
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(
        json.dumps(
            {
                "schema": "vort.dashboard_index",
                "schema_version": 1,
                "artifact_count": len(records),
                "artifacts": records,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )
    print(f"dashboard_index={output} manifest={manifest} artifacts={len(artifacts)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
