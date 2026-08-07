#!/usr/bin/env python3
"""Report candidate Brotli static-dictionary tuples from current source anchors."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

from br_static_dictionary_source_audit import (
    DEFAULT_ANCHORS,
    SUPPORTED_TRANSFORMS,
    apply_transform,
    entry_key,
    load_anchors,
)


def transform_kind(transform: int) -> str:
    operation, prefix, suffix = SUPPORTED_TRANSFORMS[transform]
    if operation == "identity" and (prefix or suffix):
        return "affix_identity"
    return operation


def candidate_entries(anchors: list[dict[str, Any]]) -> list[dict[str, Any]]:
    existing = {entry_key(entry) for entry in anchors}
    raw_words: dict[tuple[int, int], str] = {}
    for entry in anchors:
        raw_words[(entry["copy_len"], entry["word_index"])] = entry["raw_word"]

    candidates: list[dict[str, Any]] = []
    for copy_len, word_index in sorted(raw_words):
        raw_word = raw_words[(copy_len, word_index)]
        for transform in sorted(SUPPORTED_TRANSFORMS):
            key = (transform, copy_len, word_index)
            if key in existing:
                continue
            transformed = apply_transform(transform, raw_word)
            candidates.append(
                {
                    "transform": transform,
                    "copy_len": copy_len,
                    "word_index": word_index,
                    "raw_word": raw_word,
                    "transformed_word": transformed,
                    "transform_kind": transform_kind(transform),
                }
            )
    return candidates


def build_report(anchors: list[dict[str, Any]], candidates: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schema": "vort.br_static_dictionary_candidate_report",
        "schema_version": 1,
        "source_entry_count": len(anchors),
        "raw_word_count": len({(entry["copy_len"], entry["word_index"]) for entry in anchors}),
        "transform_count": len(SUPPORTED_TRANSFORMS),
        "candidate_count": len(candidates),
        "candidates": candidates,
    }


def write_json(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def write_markdown(path: Path, report: dict[str, Any], limit: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = report["candidates"][:limit]
    lines = [
        "# Brotli static dictionary candidate report",
        "",
        f"- Source entries: {report['source_entry_count']}",
        f"- Unique raw words: {report['raw_word_count']}",
        f"- Supported transforms considered: {report['transform_count']}",
        f"- Candidate entries: {report['candidate_count']}",
        f"- Rows shown: {len(rows)}",
        "",
        "| Transform | Copy length | Word index | Kind | Raw word | Candidate word |",
        "| ---: | ---: | ---: | --- | --- | --- |",
    ]
    for row in rows:
        lines.append(
            f"| {row['transform']} | {row['copy_len']} | {row['word_index']} | `{row['transform_kind']}` | `{row['raw_word']}` | `{row['transformed_word']}` |"
        )
    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--anchors", type=Path, default=DEFAULT_ANCHORS)
    parser.add_argument("--json", type=Path)
    parser.add_argument("--markdown", type=Path)
    parser.add_argument("--markdown-limit", type=int, default=80)
    args = parser.parse_args()

    anchors = load_anchors(args.anchors)
    candidates = candidate_entries(anchors)
    report = build_report(anchors, candidates)
    if args.json is not None:
        write_json(args.json, report)
    if args.markdown is not None:
        write_markdown(args.markdown, report, args.markdown_limit)
    print(
        "br_static_dictionary_candidate_report=ok "
        f"source_entries={report['source_entry_count']} raw_words={report['raw_word_count']} "
        f"candidates={report['candidate_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
