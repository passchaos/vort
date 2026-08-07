#!/usr/bin/env python3
"""Audit Vort's Brotli static-dictionary subset against source anchors.

The decoder intentionally carries a small hand-reviewed subset of RFC 7932's
static dictionary. This tool keeps that subset tied to explicit source-word
anchors and can optionally verify those anchors against a local checkout of the
upstream Brotli `common/` dictionary and transform data.
"""

from __future__ import annotations

import argparse
import ast
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "src" / "br.zig"
DEFAULT_ANCHORS = ROOT / "tools" / "br_static_dictionary_source_anchors.json"

# RFC 7932 static-dictionary bucket layout. The upstream C dictionary exposes
# the same arrays in common/dictionary.c; keeping them here makes the normal
# audit self-contained while --brotli-common-dir can still check raw bytes.
SIZE_BITS_BY_LENGTH = {
    4: 10,
    5: 10,
    6: 11,
    7: 11,
    8: 10,
    9: 10,
    10: 10,
    11: 10,
    12: 10,
    13: 9,
    14: 9,
    15: 8,
    16: 7,
    17: 7,
    18: 8,
    19: 7,
    20: 7,
    21: 6,
    22: 6,
    23: 5,
    24: 5,
}

OFFSETS_BY_LENGTH = {
    4: 0,
    5: 4096,
    6: 9216,
    7: 21504,
    8: 35840,
    9: 44032,
    10: 53248,
    11: 63488,
    12: 74752,
    13: 87040,
    14: 93696,
    15: 100864,
    16: 104704,
    17: 106752,
    18: 108928,
    19: 113536,
    20: 115968,
    21: 118528,
    22: 119872,
    23: 121280,
    24: 122016,
}

# Current production decoder entries use only this small transform subset. The
# prefix/suffix strings are the upstream transform table entries for the listed
# transform indexes, collapsed to the behavior needed by the source-anchor audit.
SUPPORTED_TRANSFORMS: dict[int, tuple[str, str, str]] = {
    0: ("identity", "", ""),
    1: ("identity", "", " "),
    6: ("identity", " ", ""),
    9: ("uppercase_first", "", ""),
    12: ("omit_last_1", "", ""),
    20: ("identity", "", "."),
}

ENTRY_RE = re.compile(
    r'\.\{ \.transform = (\d+), \.copy_len = (\d+), \.word_index = (\d+), \.word = "((?:[^"\\]|\\.)*)" \}'
)


def zig_string(value: str) -> str:
    return ast.literal_eval('"' + value + '"')


def apply_transform(transform: int, raw_word: str) -> str:
    if transform not in SUPPORTED_TRANSFORMS:
        raise AssertionError(f"unsupported transform in source anchors: {transform}")
    operation, prefix, suffix = SUPPORTED_TRANSFORMS[transform]
    word = raw_word
    if operation == "identity":
        pass
    elif operation == "uppercase_first":
        if word:
            word = word[0].upper() + word[1:]
    elif operation == "omit_last_1":
        if not word:
            raise AssertionError("omit_last_1 cannot apply to empty word")
        word = word[:-1]
    else:
        raise AssertionError(f"unsupported transform operation: {operation}")
    return prefix + word + suffix


def parse_minimal_entries(path: Path) -> list[dict[str, Any]]:
    text = path.read_text()
    entries: list[dict[str, Any]] = []
    for match in ENTRY_RE.finditer(text):
        transform = int(match.group(1))
        copy_len = int(match.group(2))
        word_index = int(match.group(3))
        word = zig_string(match.group(4))
        entries.append(
            {
                "transform": transform,
                "copy_len": copy_len,
                "word_index": word_index,
                "word": word,
            }
        )
    if not entries:
        raise AssertionError(f"no static dictionary entries found in {path}")
    return entries


def load_anchors(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise AssertionError("source anchors must be a JSON object")
    if payload.get("schema") != "vort.br_static_dictionary_source_anchors":
        raise AssertionError("unexpected source anchors schema")
    if payload.get("schema_version") != 1:
        raise AssertionError("unexpected source anchors schema_version")
    entries = payload.get("entries")
    if not isinstance(entries, list) or not entries:
        raise AssertionError("source anchors entries must be a non-empty list")
    if payload.get("entry_count") != len(entries):
        raise AssertionError("source anchors entry_count mismatch")
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise AssertionError(f"anchors.entries[{index}] must be object")
        for field in ("transform", "copy_len", "word_index"):
            if not isinstance(entry.get(field), int) or isinstance(entry.get(field), bool):
                raise AssertionError(f"anchors.entries[{index}].{field} must be int")
        for field in ("raw_word", "transformed_word", "transform_kind"):
            if not isinstance(entry.get(field), str) or not entry.get(field):
                raise AssertionError(f"anchors.entries[{index}].{field} must be non-empty string")
    return entries


def entry_key(entry: dict[str, Any]) -> tuple[int, int, int]:
    return (entry["transform"], entry["copy_len"], entry["word_index"])


def check_duplicates(entries: list[dict[str, Any]], label: str) -> None:
    seen: set[tuple[int, int, int]] = set()
    for entry in entries:
        key = entry_key(entry)
        if key in seen:
            raise AssertionError(f"duplicate {label} key {key}")
        seen.add(key)


def validate_anchor_semantics(anchors: list[dict[str, Any]]) -> Counter[str]:
    operations: Counter[str] = Counter()
    for entry in anchors:
        transform = entry["transform"]
        copy_len = entry["copy_len"]
        raw_word = entry["raw_word"]
        expected = entry["transformed_word"]
        if copy_len not in SIZE_BITS_BY_LENGTH:
            raise AssertionError(f"unsupported Brotli dictionary length {copy_len}")
        if len(raw_word.encode()) != copy_len:
            raise AssertionError(f"raw_word byte length mismatch for {entry_key(entry)}")
        actual = apply_transform(transform, raw_word)
        if actual != expected:
            raise AssertionError(f"transform output mismatch for {entry_key(entry)}: {actual!r} != {expected!r}")
        operation = SUPPORTED_TRANSFORMS[transform][0]
        if operation == "identity":
            prefix = SUPPORTED_TRANSFORMS[transform][1]
            suffix = SUPPORTED_TRANSFORMS[transform][2]
            if prefix or suffix:
                operation = "affix_identity"
        operations[operation] += 1
        if entry["transform_kind"] != operation:
            raise AssertionError(f"transform_kind mismatch for {entry_key(entry)}")
    return operations


def resolve_common_dir(path: Path) -> Path:
    if (path / "dictionary_inc.h").exists() and (path / "transform.c").exists():
        return path
    common = path / "common"
    if (common / "dictionary_inc.h").exists() and (common / "transform.c").exists():
        return common
    raise AssertionError(f"{path} is not a Brotli common directory or checkout root")


def parse_c_integer_array(text: str, name: str) -> list[int]:
    match = re.search(rf"{re.escape(name)}\[[^\]]*\]\s*=\s*\{{(.*?)\}};", text, re.S)
    if not match:
        raise AssertionError(f"could not find {name}")
    body = re.sub(r"/\*.*?\*/", "", match.group(1), flags=re.S)
    return [int(token, 0) for token in re.findall(r"0x[0-9A-Fa-f]+|\d+", body)]


def parse_prefix_suffix(text: str) -> tuple[bytes, list[int], list[tuple[int, int, int]]]:
    prefix_match = re.search(r"kPrefixSuffix\[[^\]]*\]\s*=\s*(.*?)\s*;", text, re.S)
    if not prefix_match:
        raise AssertionError("could not find kPrefixSuffix")
    chunks = re.findall(r'"(?:[^"\\]|\\.)*"', prefix_match.group(1))
    prefix_suffix = b"".join(ast.literal_eval("b" + chunk) for chunk in chunks) + b"\0"
    prefix_suffix_map = parse_c_integer_array(text, "kPrefixSuffixMap")

    constants = {
        "BROTLI_TRANSFORM_IDENTITY": 0,
        "BROTLI_TRANSFORM_OMIT_LAST_1": 1,
        "BROTLI_TRANSFORM_OMIT_LAST_2": 2,
        "BROTLI_TRANSFORM_OMIT_LAST_3": 3,
        "BROTLI_TRANSFORM_OMIT_LAST_4": 4,
        "BROTLI_TRANSFORM_OMIT_LAST_5": 5,
        "BROTLI_TRANSFORM_OMIT_LAST_6": 6,
        "BROTLI_TRANSFORM_OMIT_LAST_7": 7,
        "BROTLI_TRANSFORM_OMIT_LAST_8": 8,
        "BROTLI_TRANSFORM_OMIT_LAST_9": 9,
        "BROTLI_TRANSFORM_UPPERCASE_FIRST": 10,
        "BROTLI_TRANSFORM_UPPERCASE_ALL": 11,
        "BROTLI_TRANSFORM_OMIT_FIRST_1": 12,
        "BROTLI_TRANSFORM_OMIT_FIRST_2": 13,
        "BROTLI_TRANSFORM_OMIT_FIRST_3": 14,
        "BROTLI_TRANSFORM_OMIT_FIRST_4": 15,
        "BROTLI_TRANSFORM_OMIT_FIRST_5": 16,
        "BROTLI_TRANSFORM_OMIT_FIRST_6": 17,
        "BROTLI_TRANSFORM_OMIT_FIRST_7": 18,
        "BROTLI_TRANSFORM_OMIT_FIRST_8": 19,
        "BROTLI_TRANSFORM_OMIT_FIRST_9": 20,
        "BROTLI_TRANSFORM_SHIFT_FIRST": 21,
        "BROTLI_TRANSFORM_SHIFT_ALL": 22,
    }
    transform_match = re.search(r"kTransformsData\[\]\s*=\s*\{(.*?)\};", text, re.S)
    if not transform_match:
        raise AssertionError("could not find kTransformsData")
    body = re.sub(r"/\*.*?\*/", "", transform_match.group(1), flags=re.S)
    values: list[int] = []
    for token in re.findall(r"BROTLI_TRANSFORM_[A-Z0-9_]+|0x[0-9A-Fa-f]+|\d+", body):
        values.append(constants[token] if token in constants else int(token, 0))
    if len(values) % 3 != 0:
        raise AssertionError("kTransformsData length must be divisible by 3")
    transforms = [tuple(values[i : i + 3]) for i in range(0, len(values), 3)]
    return prefix_suffix, prefix_suffix_map, transforms


def c_string_at(prefix_suffix: bytes, prefix_suffix_map: list[int], index: int) -> bytes:
    offset = prefix_suffix_map[index]
    length = prefix_suffix[offset]
    return prefix_suffix[offset + 1 : offset + 1 + length]


def uppercase_first_ascii(value: bytes) -> bytes:
    if not value:
        return value
    first = value[0]
    if 0x61 <= first <= 0x7A:
        first -= 0x20
    return bytes([first]) + value[1:]


def apply_upstream_transform(transform_index: int, word: bytes, prefix_suffix: bytes, prefix_suffix_map: list[int], transforms: list[tuple[int, int, int]]) -> bytes:
    prefix_id, transform_type, suffix_id = transforms[transform_index]
    transformed = word
    if 1 <= transform_type <= 9:
        transformed = transformed[:-transform_type]
    elif 12 <= transform_type <= 20:
        transformed = transformed[transform_type - 11 :]
    elif transform_type in (21, 22):
        raise AssertionError("shift transforms are outside the current minimal subset")
    if transform_type == 10:
        transformed = uppercase_first_ascii(transformed)
    elif transform_type == 11:
        transformed = bytes(byte - 0x20 if 0x61 <= byte <= 0x7A else byte for byte in transformed)
    return c_string_at(prefix_suffix, prefix_suffix_map, prefix_id) + transformed + c_string_at(prefix_suffix, prefix_suffix_map, suffix_id)


def validate_against_brotli_source(common_dir: Path, anchors: list[dict[str, Any]]) -> None:
    common = resolve_common_dir(common_dir)
    dictionary_data = parse_c_integer_array((common / "dictionary_inc.h").read_text(), "kBrotliDictionaryData")
    prefix_suffix, prefix_suffix_map, transforms = parse_prefix_suffix((common / "transform.c").read_text())
    for entry in anchors:
        copy_len = entry["copy_len"]
        word_index = entry["word_index"]
        transform = entry["transform"]
        offset = OFFSETS_BY_LENGTH[copy_len] + copy_len * word_index
        raw = bytes(dictionary_data[offset : offset + copy_len])
        if raw.decode("utf-8") != entry["raw_word"]:
            raise AssertionError(f"upstream raw word mismatch for {entry_key(entry)}")
        transformed = apply_upstream_transform(transform, raw, prefix_suffix, prefix_suffix_map, transforms)
        if transformed.decode("utf-8") != entry["transformed_word"]:
            raise AssertionError(f"upstream transformed word mismatch for {entry_key(entry)}")


def table_entries_from_anchors(anchors: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "transform": entry["transform"],
            "copy_len": entry["copy_len"],
            "word_index": entry["word_index"],
            "word": entry["transformed_word"],
        }
        for entry in anchors
    ]


def zig_escape(value: str) -> str:
    escaped: list[str] = []
    for byte in value.encode("utf-8"):
        if byte == ord('"'):
            escaped.append('\\"')
        elif byte == ord("\\"):
            escaped.append('\\\\')
        elif byte == ord("\n"):
            escaped.append('\\n')
        elif byte == ord("\r"):
            escaped.append('\\r')
        elif byte == ord("\t"):
            escaped.append('\\t')
        elif 0x20 <= byte <= 0x7E:
            escaped.append(chr(byte))
        else:
            escaped.append(f"\\x{byte:02x}")
    return "".join(escaped)


def render_generated_zig_table(anchors: list[dict[str, Any]]) -> str:
    lines = [
        "// Generated by tools/br_static_dictionary_source_audit.py from",
        "// tools/br_static_dictionary_source_anchors.json. Keep src/br.zig in sync.",
        "const minimal_static_dictionary_entries = [_]StaticDictionaryEntry{",
    ]
    for entry in table_entries_from_anchors(anchors):
        lines.append(
            "    .{ .transform = %d, .copy_len = %d, .word_index = %d, .word = \"%s\" },"
            % (entry["transform"], entry["copy_len"], entry["word_index"], zig_escape(entry["word"]))
        )
    lines.append("};")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--anchors", type=Path, default=DEFAULT_ANCHORS)
    parser.add_argument("--summary", type=Path)
    parser.add_argument("--generated-zig", type=Path, help="optional generated Zig table fragment output path")
    parser.add_argument("--brotli-common-dir", type=Path, help="optional local Brotli common/ directory or checkout root")
    args = parser.parse_args()

    table_entries = parse_minimal_entries(args.source)
    anchors = load_anchors(args.anchors)
    check_duplicates(table_entries, "table")
    check_duplicates(anchors, "anchor")

    operations = validate_anchor_semantics(anchors)
    generated_table_entries = table_entries_from_anchors(anchors)
    generated_table_matches_source = generated_table_entries == table_entries
    table_by_key = {entry_key(entry): entry for entry in table_entries}
    anchors_by_key = {entry_key(entry): entry for entry in anchors}
    if set(table_by_key) != set(anchors_by_key):
        missing = sorted(set(table_by_key) - set(anchors_by_key))
        stale = sorted(set(anchors_by_key) - set(table_by_key))
        raise AssertionError(f"anchor/table key mismatch missing={missing} stale={stale}")
    for key, table_entry in table_by_key.items():
        anchor = anchors_by_key[key]
        if table_entry["word"] != anchor["transformed_word"]:
            raise AssertionError(f"table word differs from source anchor for {key}")
    if not generated_table_matches_source:
        raise AssertionError("generated Zig table order/content differs from src/br.zig")

    generated_zig = render_generated_zig_table(anchors)
    generated_zig_path = ""
    if args.generated_zig is not None:
        args.generated_zig.parent.mkdir(parents=True, exist_ok=True)
        args.generated_zig.write_text(generated_zig)
        generated_zig_path = str(args.generated_zig)

    source_checked = False
    source_dir = ""
    if args.brotli_common_dir is not None:
        validate_against_brotli_source(args.brotli_common_dir, anchors)
        source_checked = True
        source_dir = str(resolve_common_dir(args.brotli_common_dir))

    summary = {
        "schema": "vort.br_static_dictionary_source_audit",
        "schema_version": 1,
        "ok": True,
        "entry_count": len(table_entries),
        "anchor_count": len(anchors),
        "transform_count": len({entry["transform"] for entry in table_entries}),
        "length_count": len({entry["copy_len"] for entry in table_entries}),
        "operation_counts": dict(sorted(operations.items())),
        "generated_table_matches_source": generated_table_matches_source,
        "generated_zig_bytes": len(generated_zig.encode()),
        "generated_zig_path": generated_zig_path,
        "source_checked": source_checked,
        "source_dir": source_dir,
    }
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(
        "br_static_dictionary_source_audit=ok "
        f"entries={summary['entry_count']} anchors={summary['anchor_count']} "
        f"source_checked={str(source_checked).lower()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
