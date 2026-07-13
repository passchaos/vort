#!/usr/bin/env python3
"""Write a small Markdown index for zig-out dashboard artifacts."""

from __future__ import annotations

import argparse
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


def json_summary(path: Path) -> str:
    try:
        data = json.loads(path.read_text())
    except Exception:
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default="zig-out", help="dashboard artifact directory")
    parser.add_argument("--output", default="zig-out/vort-dashboard-index.md", help="Markdown index path")
    args = parser.parse_args()

    root = Path(args.dir)
    output = Path(args.output)
    artifacts = sorted(path for path in root.glob("vort-*") if path.suffix in {".md", ".json"} and path.resolve() != output.resolve())
    grouped: dict[str, list[Path]] = {}
    for artifact in artifacts:
        grouped.setdefault(category_for(artifact), []).append(artifact)

    lines = [
        "# Vort dashboard index",
        "",
        "Generated from `zig-out` artifacts. Paths are relative to this index file.",
        "",
    ]
    for category in sorted(grouped):
        lines.extend([f"## {category}", ""])
        for artifact in grouped[category]:
            rel = artifact.relative_to(output.parent)
            note = json_summary(artifact) if artifact.suffix == ".json" else ""
            suffix = f" — {note}" if note else ""
            lines.append(f"- [{artifact.name}]({rel.as_posix()}){suffix}")
        lines.append("")
    if not artifacts:
        lines.append("_No dashboard artifacts found._")
        lines.append("")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines))
    print(f"dashboard_index={output} artifacts={len(artifacts)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
