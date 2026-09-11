#!/usr/bin/env python3
"""Run and validate the required Brotli real-corpus differential."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
SUMMARY_PREFIX = "br_upstream_multiblock_diff=ok "
EXPECTED_QUALITY_MASK = (1 << 0) | (1 << 4) | (1 << 8) | (1 << 11)
EXPECTED_MODE_MASK = (1 << 0) | (1 << 1) | (1 << 2)
EXPECTED_WINDOW_MASK = (1 << 10) | (1 << 16) | (1 << 20) | (1 << 24)


@dataclass(frozen=True)
class CorpusCase:
    label: str
    category: str
    path: Path
    byte_count: int


@dataclass(frozen=True)
class Manifest:
    real_limit: int
    options_per_file: int
    required_categories: tuple[str, ...]
    cases: tuple[CorpusCase, ...]


def load_manifest(path: Path, root: Path = ROOT) -> Manifest:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"cannot read Brotli real-corpus manifest {path}: {error}") from error
    if document.get("schema") != "vort.br_real_corpus_manifest":
        raise RuntimeError("unexpected Brotli real-corpus manifest schema")
    if document.get("schema_version") != 1:
        raise RuntimeError("unsupported Brotli real-corpus manifest version")

    real_limit = document.get("real_limit")
    options_per_file = document.get("options_per_file")
    required_categories = document.get("required_categories")
    raw_cases = document.get("cases")
    if not isinstance(real_limit, int) or real_limit <= 0:
        raise RuntimeError("real_limit must be a positive integer")
    if options_per_file != 4:
        raise RuntimeError("options_per_file must match the probe's four-option matrix")
    if not isinstance(required_categories, list) or not required_categories or not all(isinstance(value, str) and value for value in required_categories):
        raise RuntimeError("required_categories must be a non-empty string list")
    if len(set(required_categories)) != len(required_categories):
        raise RuntimeError("required_categories contains duplicates")
    if not isinstance(raw_cases, list) or not raw_cases:
        raise RuntimeError("cases must be a non-empty list")

    cases: list[CorpusCase] = []
    labels: set[str] = set()
    paths: set[Path] = set()
    categories: set[str] = set()
    for index, raw in enumerate(raw_cases):
        if not isinstance(raw, dict):
            raise RuntimeError(f"case {index} must be an object")
        label = raw.get("label")
        category = raw.get("category")
        relative = raw.get("path")
        min_bytes = raw.get("min_bytes")
        if not isinstance(label, str) or not label or label in labels:
            raise RuntimeError(f"case {index} has an invalid or duplicate label")
        if not isinstance(category, str) or category not in required_categories:
            raise RuntimeError(f"case {label} has an unknown category")
        if not isinstance(relative, str) or not relative:
            raise RuntimeError(f"case {label} has an invalid path")
        relative_path = Path(relative)
        if relative_path.is_absolute() or ".." in relative_path.parts:
            raise RuntimeError(f"case {label} path must remain inside the repository")
        resolved = (root / relative_path).resolve()
        try:
            resolved.relative_to(root.resolve())
        except ValueError as error:
            raise RuntimeError(f"case {label} path escapes the repository") from error
        if resolved in paths:
            raise RuntimeError(f"case {label} duplicates a corpus path")
        if not isinstance(min_bytes, int) or min_bytes <= 0:
            raise RuntimeError(f"case {label} has an invalid min_bytes")
        if not resolved.is_file():
            raise RuntimeError(f"case {label} is missing: {resolved}")
        byte_count = resolved.stat().st_size
        if byte_count < min_bytes:
            raise RuntimeError(f"case {label} has {byte_count} bytes; expected at least {min_bytes}")
        labels.add(label)
        paths.add(resolved)
        categories.add(category)
        cases.append(CorpusCase(label, category, resolved, byte_count))

    missing = sorted(set(required_categories) - categories)
    if missing:
        raise RuntimeError(f"manifest misses required categories: {', '.join(missing)}")
    return Manifest(real_limit, options_per_file, tuple(required_categories), tuple(cases))


def parse_summary(output: str) -> dict[str, str]:
    for line in reversed(output.splitlines()):
        if line.startswith(SUMMARY_PREFIX):
            fields: dict[str, str] = {}
            for field in line.split()[1:]:
                if "=" in field:
                    key, value = field.split("=", 1)
                    fields[key] = value
            return fields
    raise RuntimeError("Brotli differential did not emit its structured summary")


def validate_summary(fields: dict[str, str], manifest: Manifest, extra_count: int) -> tuple[int, int, str]:
    expected_files = len(manifest.cases) + extra_count
    expected_cases = expected_files * manifest.options_per_file
    try:
        real_cases = int(fields["real_file_cases"], 0)
        progressive_cases = int(fields["real_progressive_cases"], 0)
        options_per_file = int(fields["real_options_per_file"], 0)
        quality_mask = int(fields["real_quality_mask"], 0)
        mode_mask = int(fields["real_mode_mask"], 0)
        window_mask = int(fields["real_window_mask"], 0)
        unsupported = int(fields["summaries_unsupported"], 0)
        reference_version = fields["reference_version"]
    except (KeyError, ValueError) as error:
        raise RuntimeError(f"malformed Brotli differential summary: {fields}") from error
    if real_cases != expected_cases:
        raise RuntimeError(f"decoded {real_cases} real-corpus cases; expected {expected_cases}")
    if progressive_cases != expected_cases:
        raise RuntimeError(f"progressively decoded {progressive_cases} real-corpus cases; expected {expected_cases}")
    if options_per_file != manifest.options_per_file:
        raise RuntimeError(f"probe reported {options_per_file} options per file; expected {manifest.options_per_file}")
    if quality_mask != EXPECTED_QUALITY_MASK:
        raise RuntimeError(f"unexpected Brotli real-corpus quality mask: {quality_mask:#x}")
    if mode_mask != EXPECTED_MODE_MASK:
        raise RuntimeError(f"unexpected Brotli real-corpus mode mask: {mode_mask:#x}")
    if window_mask != EXPECTED_WINDOW_MASK:
        raise RuntimeError(f"unexpected Brotli real-corpus window mask: {window_mask:#x}")
    if unsupported != 0:
        raise RuntimeError(f"real-corpus differential reported {unsupported} unsupported summaries")
    if not reference_version or reference_version == "0":
        raise RuntimeError("real-corpus differential did not identify libbrotli")
    return real_cases, progressive_cases, reference_version


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("probe", type=Path)
    parser.add_argument("--manifest", type=Path, default=ROOT / "tools/br/real_corpus_manifest.json")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--extra-file", action="append", type=Path, default=[])
    args = parser.parse_args()

    manifest = load_manifest(args.manifest.resolve(), args.root.resolve())
    extras = [path.expanduser().resolve() for path in args.extra_file]
    for path in extras:
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f"extra corpus file is missing or empty: {path}")

    command = [str(args.probe.resolve()), "--real-limit", str(manifest.real_limit)]
    for case in manifest.cases:
        command.extend(("--real-file", str(case.path)))
    for path in extras:
        command.extend(("--real-file", str(path)))
    result = subprocess.run(command, cwd=args.root.resolve(), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    if result.returncode != 0:
        if result.stdout:
            print(result.stdout, end="", file=sys.stderr)
        raise RuntimeError(f"Brotli real-corpus differential failed with exit code {result.returncode}")
    fields = parse_summary(result.stdout)
    real_cases, progressive_cases, version = validate_summary(fields, manifest, len(extras))
    print(
        "br_real_corpus_diff=ok "
        f"files={len(manifest.cases) + len(extras)} "
        f"required_categories={len(manifest.required_categories)} "
        f"real_file_cases={real_cases} real_progressive_cases={progressive_cases} "
        f"real_limit={manifest.real_limit} reference_version={version}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
