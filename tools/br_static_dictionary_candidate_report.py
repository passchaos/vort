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
    OFFSETS_BY_LENGTH,
    SIZE_BITS_BY_LENGTH,
    SUPPORTED_TRANSFORMS,
    apply_transform,
    entry_key,
    load_anchors,
    parse_c_integer_array,
    resolve_common_dir,
)


def transform_kind(transform: int) -> str:
    operation, prefix, suffix = SUPPORTED_TRANSFORMS[transform]
    if operation == "identity" and (prefix or suffix):
        return "affix_identity"
    return operation


def anchor_raw_words(anchors: list[dict[str, Any]]) -> dict[tuple[int, int], str]:
    raw_words: dict[tuple[int, int], str] = {}
    for entry in anchors:
        raw_words[(entry["copy_len"], entry["word_index"])] = entry["raw_word"]
    return raw_words


def upstream_raw_words(common_dir: Path, limit: int) -> dict[tuple[int, int], str]:
    common = resolve_common_dir(common_dir)
    dictionary_data = parse_c_integer_array((common / "dictionary_inc.h").read_text(), "kBrotliDictionaryData")
    raw_words: dict[tuple[int, int], str] = {}
    remaining = limit
    for copy_len in sorted(SIZE_BITS_BY_LENGTH):
        count = 1 << SIZE_BITS_BY_LENGTH[copy_len]
        for word_index in range(count):
            if remaining == 0:
                return raw_words
            offset = OFFSETS_BY_LENGTH[copy_len] + copy_len * word_index
            raw = bytes(dictionary_data[offset : offset + copy_len])
            try:
                raw_word = raw.decode("utf-8")
            except UnicodeDecodeError:
                continue
            raw_words[(copy_len, word_index)] = raw_word
            remaining -= 1
    return raw_words


def candidate_entries(anchors: list[dict[str, Any]], raw_words: dict[tuple[int, int], str]) -> list[dict[str, Any]]:
    existing = {entry_key(entry) for entry in anchors}
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



def kind_rows(candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for kind in sorted({candidate["transform_kind"] for candidate in candidates}):
        items = [candidate for candidate in candidates if candidate["transform_kind"] == kind]
        rows.append({"transform_kind": kind, "candidate_count": len(items)})
    return rows


def length_rows(candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for copy_len in sorted({candidate["copy_len"] for candidate in candidates}):
        items = [candidate for candidate in candidates if candidate["copy_len"] == copy_len]
        rows.append({"copy_len": copy_len, "candidate_count": len(items)})
    return rows

def build_report(anchors: list[dict[str, Any]], raw_words: dict[tuple[int, int], str], candidates: list[dict[str, Any]], source_mode: str) -> dict[str, Any]:
    return {
        "schema": "vort.br_static_dictionary_candidate_report",
        "schema_version": 1,
        "source_mode": source_mode,
        "source_entry_count": len(anchors),
        "raw_word_count": len(raw_words),
        "transform_count": len(SUPPORTED_TRANSFORMS),
        "candidate_count": len(candidates),
        "kind_rows": kind_rows(candidates),
        "length_rows": length_rows(candidates),
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
        f"- Source mode: {report['source_mode']}",
        f"- Source entries: {report['source_entry_count']}",
        f"- Unique raw words: {report['raw_word_count']}",
        f"- Supported transforms considered: {report['transform_count']}",
        f"- Candidate entries: {report['candidate_count']}",
        f"- Rows shown: {len(rows)}",
        "",
        "## Transform-kind summary",
        "",
        "| Transform kind | Candidates |",
        "| --- | ---: |",
    ]
    for row in report["kind_rows"]:
        lines.append(f"| `{row['transform_kind']}` | {row['candidate_count']} |")
    lines.extend([
        "",
        "## Copy-length summary",
        "",
        "| Copy length | Candidates |",
        "| ---: | ---: |",
    ])
    for row in report["length_rows"]:
        lines.append(f"| {row['copy_len']} | {row['candidate_count']} |")
    lines.extend([
        "",
        "## Candidate rows",
        "",
        "| Transform | Copy length | Word index | Kind | Raw word | Candidate word |",
        "| ---: | ---: | ---: | --- | --- | --- |",
    ])
    for row in rows:
        lines.append(
            f"| {row['transform']} | {row['copy_len']} | {row['word_index']} | `{row['transform_kind']}` | `{row['raw_word']}` | `{row['transformed_word']}` |"
        )
    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--anchors", type=Path, default=DEFAULT_ANCHORS)
    parser.add_argument("--brotli-common-dir", type=Path, help="optional Brotli common/ directory or checkout root for upstream raw words")
    parser.add_argument("--source-limit", type=int, default=0, help="maximum upstream raw words to include when --brotli-common-dir is set; 0 keeps anchor-only mode")
    parser.add_argument("--json", type=Path)
    parser.add_argument("--markdown", type=Path)
    parser.add_argument("--markdown-limit", type=int, default=80)
    args = parser.parse_args()

    if args.source_limit > 0 and args.brotli_common_dir is None:
        raise SystemExit("--source-limit requires --brotli-common-dir")

    anchors = load_anchors(args.anchors)
    raw_words = anchor_raw_words(anchors)
    source_mode = "anchors"
    if args.brotli_common_dir is not None and args.source_limit > 0:
        raw_words.update(upstream_raw_words(args.brotli_common_dir, args.source_limit))
        source_mode = "upstream"
    candidates = candidate_entries(anchors, raw_words)
    report = build_report(anchors, raw_words, candidates, source_mode)
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
