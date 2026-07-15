#!/usr/bin/env python3
"""Smoke-test Vort raw/zlib/gzip header inspection CLI commands."""

import gzip
import json
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

from validation_json_docs_check import load_manifest, validate_value_against_manifest


def run(cli: str, *args: str) -> str:
    return subprocess.check_output([cli, *args], text=True).strip()


def expect_failure(cli: str, *args: str) -> str:
    result = subprocess.run([cli, *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode == 0:
        raise AssertionError(f"expected failure for {[cli, *args]!r}, got success: {result.stdout!r}")
    return result.stdout


def require_fields(output: str, fields: dict[str, str]) -> None:
    for key, value in fields.items():
        needle = f"{key}={value}"
        if needle not in output:
            raise AssertionError(f"missing {needle!r} in {output!r}")


def md(text: object) -> str:
    return str(text).replace("|", "\\|")


def md_sample(text: object, limit: int = 32) -> str:
    value = str(text)
    if len(value) <= limit:
        return md(value)
    head = max(8, limit - 12)
    tail = 8
    return md(f"{value[:head]}…{value[-tail:]} ({len(value)} hex)")


def format_for_command(command: str) -> str:
    if "raw" in command:
        return "raw"
    if "zlib" in command:
        return "zlib"
    if "gzip" in command:
        return "gzip"
    return "unknown"


def write_markdown(path: Path, summary: dict[str, object]) -> None:
    lines = [
        "# Vort header inspect smoke",
        "",
        f"- ok: `{summary['ok']}`",
        f"- cases: {summary['case_count']} (raw={summary['raw_cases']}, zlib={summary['zlib_cases']}, gzip={summary['gzip_cases']})",
        f"- dictionary cases: {summary['dictionary_cases']}",
        f"- optional gzip header cases: {summary['optional_header_cases']}",
        f"- FHCRC cases: {summary['fhcrc_cases']}",
        f"- malformed negative cases: {summary['negative_cases']}",
        "",
        "## Format summary",
        "",
        "| format | cases | bytes | dictionary | optional headers | FHCRC |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for format_name in ("raw", "zlib", "gzip"):
        cases = [case for case in summary["cases"] if case["format"] == format_name]
        lines.append(
            "| {format} | {cases} | {bytes} | {dictionary} | {optional} | {fhcrc} |".format(
                format=md(format_name),
                cases=len(cases),
                bytes=sum(case["bytes"] for case in cases),
                dictionary=sum(1 for case in cases if case["has_dictionary"]),
                optional=sum(1 for case in cases if case["has_optional_fields"]),
                fhcrc=sum(1 for case in cases if case["header_crc"]),
            )
        )
    lines.extend(
        [
            "",
            "## Successful inspections",
            "",
        ]
    )
    for format_name in ("raw", "zlib", "gzip"):
        cases = [case for case in summary["cases"] if case["format"] == format_name]
        if not cases:
            continue
        lines.extend(
            [
                f"### {format_name}",
                "",
                "| name | schema | bytes | details | command | sample |",
                "| --- | --- | ---: | --- | --- | --- |",
            ]
        )
        for case in cases:
            lines.append(
                f"| {md(case['name'])} | `{md(case['schema_name'])}` | {case['bytes']} | {md(case['detail'])} | `{md(case['command'])}` | `{md_sample(case['sample'])}` |"
            )
        lines.append("")
    lines.extend(
        [
            "## Expected failures",
            "",
            "| format | failures |",
            "| --- | ---: |",
        ]
    )
    for format_name in ("raw", "zlib", "gzip"):
        items = [item for item in summary["negative_items"] if item["format"] == format_name]
        lines.append(f"| {md(format_name)} | {len(items)} |")
    lines.extend(
        [
            "",
            "### Error summary",
            "",
            "| expected error | failures |",
            "| --- | ---: |",
        ]
    )
    for error_name, count in sorted(summary["negative_error_counts"].items()):
        lines.append(f"| `{md(error_name)}` | {count} |")
    lines.extend([""])
    for format_name in ("raw", "zlib", "gzip"):
        items = [item for item in summary["negative_items"] if item["format"] == format_name]
        if not items:
            continue
        lines.extend(
            [
                f"### {format_name}",
                "",
                "| name | command | sample | expected error |",
                "| --- | --- | --- | --- |",
            ]
        )
        for item in items:
            lines.append(f"| {md(item['name'])} | `{md(item['command'])}` | `{md_sample(item['sample'])}` | `{md(item['expected_error'])}` |")
        lines.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(f"usage: {argv[0]} <vort-cli> [--summary <path>] [--markdown <path>]", file=sys.stderr)
        return 2

    cli = argv[1]
    summary_path: Path | None = None
    markdown_path: Path | None = None
    index = 2
    while index < len(argv):
        if index + 1 >= len(argv):
            print(f"usage: {argv[0]} <vort-cli> [--summary <path>] [--markdown <path>]", file=sys.stderr)
            return 2
        flag = argv[index]
        value = Path(argv[index + 1])
        if flag == "--summary":
            summary_path = value
        elif flag == "--markdown":
            markdown_path = value
        else:
            print(f"usage: {argv[0]} <vort-cli> [--summary <path>] [--markdown <path>]", file=sys.stderr)
            return 2
        index += 2

    summary: dict[str, object] = {
        "schema": "vort.header_inspect_smoke",
        "schema_version": 1,
        "ok": False,
        "cases": [],
    }
    payload = b"hello"
    raw_frame = bytes.fromhex("cb48cdc9c90700")
    raw_stored_frame = bytes.fromhex("010500faff68656c6c6f")
    zlib_frame = zlib.compress(payload, level=6)
    gzip_frame = gzip.compress(payload, compresslevel=6, mtime=0)
    schemas_def = load_manifest()
    dictionary = b"hello "
    dict_payload = b"hello hello hello"
    dict_compressor = zlib.compressobj(level=6, wbits=zlib.MAX_WBITS, zdict=dictionary)
    zlib_dict_frame = dict_compressor.compress(dict_payload) + dict_compressor.flush()
    # This member carries FEXTRA, FNAME, FCOMMENT, and FHCRC over a raw fixed
    # deflate "hello" payload. Keeping the bytes literal makes the smoke stable
    # across Python gzip header policy changes while still exercising Vort's
    # optional-header parser and FHCRC validator through the CLI.
    gzip_optional_frame = bytes.fromhex(
        "1f8b081e0000000000030400616263646e616d6500636f6d6d656e7400"
        "e248cb48cdc9c9070086a6103605000000"
    )
    negative_cases = [
        ("raw_reserved_btype", "inspect-raw-header-hex", "07", "InvalidDeflateBlockType"),
        ("raw_bad_stored_nlen", "inspect-raw-header-hex", "010100ffff78", "StoredLengthMismatch"),
        ("raw_truncated_dynamic_header", "inspect-raw-header-hex", "05", "TruncatedFrame"),
        ("raw_dynamic_oversubscribed_cl", "inspect-raw-header-hex", "05009200", "InvalidHuffmanCode"),
        ("raw_dynamic_repeat16_without_previous", "inspect-raw-header-hex", "05000224", "InvalidDynamicBlockHeader"),
        ("raw_dynamic_repeat17_overrun", "inspect-raw-header-hex", "050010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "InvalidDynamicBlockHeader"),
        ("raw_dynamic_missing_eob", "inspect-raw-header-hex", "05c001040000000010000000000000000000000000010000000000000000000000000000000000000000", "InvalidDynamicBlockHeader"),
        ("zlib_dynamic_repeat16_without_previous", "inspect-zlib-deflate-header-hex", "78010500022400000000", "InvalidDynamicBlockHeader"),
        ("zlib_dynamic_missing_eob", "inspect-zlib-deflate-header-hex", "780105c00104000000001000000000000000000000000001000000000000000000000000000000000000000000000000", "InvalidDynamicBlockHeader"),
        ("gzip_dynamic_repeat16_without_previous", "inspect-gzip-deflate-header-hex", "1f8b0800000000000403050002240000000000000000", "InvalidDynamicBlockHeader"),
        ("gzip_dynamic_missing_eob", "inspect-gzip-deflate-header-hex", "1f8b080000000000040305c0010400000000100000000000000000000000000100000000000000000000000000000000000000000000000000000000", "InvalidDynamicBlockHeader"),
        ("zlib_bad_fcheck", "inspect-zlib-header-hex", "7802", "BadZlibHeader"),
        ("gzip_bad_fhcrc", "inspect-gzip-header-hex", "1f8b0802000000000403a2b2", "BadGzipHeader"),
    ]
    negative_items: list[dict[str, object]] = []
    for name, command, sample, expected_error in negative_cases:
        failed = expect_failure(cli, command, sample)
        if expected_error not in failed:
            raise AssertionError(f"expected {expected_error!r} in failure output for {command} {sample}, got {failed!r}")
        format_name = format_for_command(command)
        negative_items.append(
            {
                "name": name,
                "format": format_name,
                "command": command,
                "sample": sample,
                "argv": [command, sample],
                "expected_error": expected_error,
                "matched": True,
            }
        )

    raw_hex = run(cli, "inspect-raw-header-hex", raw_frame.hex())
    require_fields(
        raw_hex,
        {
            "raw_header compressed_bytes": str(len(raw_frame)),
            "final": "true",
            "block_type": "fixed",
            "data_bit_offset": "3",
            "data_byte_offset": "1",
            "header_bits_consumed": "3",
            "header_bytes_consumed": "1",
        },
    )
    cases: list[dict[str, object]] = [
        {
            "name": "raw_fixed",
            "schema_name": "vort.raw_deflate_header_info",
            "command": "inspect-raw-header-hex",
            "sample": raw_frame.hex(),
            "argv": ["inspect-raw-header-hex", raw_frame.hex()],
            "detail": "fixed",
            "format": "raw",
            "bytes": len(raw_frame),
            "data_offset": 1,
            "has_dictionary": False,
            "has_optional_fields": False,
            "header_crc": False,
        }
    ]
    raw_json = json.loads(run(cli, "inspect-raw-header-hex", raw_frame.hex(), "json"))
    assert raw_json["schema"] == "vort.raw_deflate_header_info"
    assert raw_json["block_type"] == "fixed"
    assert raw_json["final"] is True
    assert raw_json["header_bits_consumed"] == 3
    assert raw_json["stored_len"] is None
    validate_value_against_manifest(raw_json, schemas_def)

    raw_stored_hex = run(cli, "inspect-raw-header-hex", raw_stored_frame.hex())
    require_fields(
        raw_stored_hex,
        {
            "raw_header compressed_bytes": str(len(raw_stored_frame)),
            "block_type": "stored",
            "stored_len": "5",
            "stored_nlen": "65530",
            "stored_payload_offset": "5",
            "header_bits_consumed": "40",
        },
    )
    cases.append(
        {
            "name": "raw_stored",
            "schema_name": "vort.raw_deflate_header_info",
            "command": "inspect-raw-header-hex",
            "sample": raw_stored_frame.hex(),
            "argv": ["inspect-raw-header-hex", raw_stored_frame.hex()],
            "detail": "LEN=5",
            "format": "raw",
            "bytes": len(raw_stored_frame),
            "data_offset": 5,
            "has_dictionary": False,
            "has_optional_fields": False,
            "header_crc": False,
        }
    )
    raw_stored_json = json.loads(run(cli, "inspect-raw-header-hex", raw_stored_frame.hex(), "json"))
    assert raw_stored_json["schema"] == "vort.raw_deflate_header_info"
    assert raw_stored_json["block_type"] == "stored"
    assert raw_stored_json["stored_len"] == 5
    assert raw_stored_json["stored_nlen"] == 65530
    assert raw_stored_json["stored_payload_offset"] == 5
    assert raw_stored_json["header_bits_consumed"] == 40
    validate_value_against_manifest(raw_stored_json, schemas_def)

    raw_dynamic_frame_hex = run(cli, "encode-raw-dynamic-hex", payload.decode("ascii"), "default")
    raw_dynamic_frame = bytes.fromhex(raw_dynamic_frame_hex)
    raw_dynamic_hex = run(cli, "inspect-raw-header-hex", raw_dynamic_frame_hex)
    require_fields(
        raw_dynamic_hex,
        {
            "raw_header compressed_bytes": str(len(raw_dynamic_frame)),
            "block_type": "dynamic",
            "dynamic_hlit": "257",
            "dynamic_code_length_count": "",
        },
    )
    cases.append(
        {
            "name": "raw_dynamic",
            "schema_name": "vort.raw_deflate_header_info",
            "command": "inspect-raw-header-hex",
            "sample": raw_dynamic_frame_hex,
            "argv": ["inspect-raw-header-hex", raw_dynamic_frame_hex],
            "detail": "dynamic",
            "format": "raw",
            "bytes": len(raw_dynamic_frame),
            "data_offset": 1,
            "has_dictionary": False,
            "has_optional_fields": False,
            "header_crc": False,
        }
    )
    raw_dynamic_json = json.loads(run(cli, "inspect-raw-header-hex", raw_dynamic_frame_hex, "json"))
    assert raw_dynamic_json["schema"] == "vort.raw_deflate_header_info"
    assert raw_dynamic_json["block_type"] == "dynamic"
    assert raw_dynamic_json["dynamic_hlit"] >= 257
    assert raw_dynamic_json["dynamic_hdist"] >= 1
    assert raw_dynamic_json["dynamic_hclen"] >= 4
    assert raw_dynamic_json["dynamic_code_length_count"] == raw_dynamic_json["dynamic_hclen"]
    assert raw_dynamic_json["dynamic_code_length_repeat_zero_long"] >= 1
    assert len(raw_dynamic_json["dynamic_code_length_lengths"]) == 19
    assert raw_dynamic_json["dynamic_literal_nonzero"] >= 1
    assert raw_dynamic_json["dynamic_distance_nonzero"] >= 1
    assert raw_dynamic_json["dynamic_has_eob"] is True
    assert raw_dynamic_json["dynamic_lengths_bit_offset"] == raw_dynamic_json["header_bits_consumed"]
    assert raw_dynamic_json["dynamic_lengths_byte_offset"] == raw_dynamic_json["header_bytes_consumed"]
    assert raw_dynamic_json["header_bits_consumed"] > 17 + raw_dynamic_json["dynamic_hclen"] * 3
    assert raw_dynamic_json["dynamic_literal_zero"] == raw_dynamic_json["dynamic_hlit"] - raw_dynamic_json["dynamic_literal_nonzero"]
    assert raw_dynamic_json["dynamic_distance_zero"] == raw_dynamic_json["dynamic_hdist"] - raw_dynamic_json["dynamic_distance_nonzero"]
    assert raw_dynamic_json["dynamic_literal_max_bits"] >= 1
    assert raw_dynamic_json["dynamic_distance_max_bits"] >= 1
    assert len(raw_dynamic_json["dynamic_literal_length_histogram"]) == 16
    assert len(raw_dynamic_json["dynamic_distance_length_histogram"]) == 16
    assert sum(raw_dynamic_json["dynamic_literal_length_histogram"]) == raw_dynamic_json["dynamic_hlit"]
    assert sum(raw_dynamic_json["dynamic_distance_length_histogram"]) == raw_dynamic_json["dynamic_hdist"]
    cases[-1]["detail"] = (
        f"HLIT={raw_dynamic_json['dynamic_hlit']} HDIST={raw_dynamic_json['dynamic_hdist']} "
        f"HCLEN={raw_dynamic_json['dynamic_hclen']} lit_nonzero={raw_dynamic_json['dynamic_literal_nonzero']} "
        f"dist_nonzero={raw_dynamic_json['dynamic_distance_nonzero']} max={raw_dynamic_json['dynamic_literal_max_bits']}/"
        f"{raw_dynamic_json['dynamic_distance_max_bits']} rle16/17/18={raw_dynamic_json['dynamic_code_length_repeat_prev']}/"
        f"{raw_dynamic_json['dynamic_code_length_repeat_zero_short']}/{raw_dynamic_json['dynamic_code_length_repeat_zero_long']}"
    )
    validate_value_against_manifest(raw_dynamic_json, schemas_def)

    zlib_hex = run(cli, "inspect-zlib-header-hex", zlib_frame.hex())
    require_fields(
        zlib_hex,
        {
            "zlib_header compressed_bytes": str(len(zlib_frame)),
            "data_offset": "2",
            "method": "8",
            "window_bits": "15",
            "window_size": "32768",
            "fdict": "false",
            "dictid": "null",
        },
    )
    cases.append(
        {
            "name": "zlib_default",
            "schema_name": "vort.zlib_header_info",
            "command": "inspect-zlib-header-hex",
            "sample": zlib_frame.hex(),
            "argv": ["inspect-zlib-header-hex", zlib_frame.hex()],
            "detail": "-",
            "format": "zlib",
            "bytes": len(zlib_frame),
            "data_offset": 2,
            "has_dictionary": False,
            "has_optional_fields": False,
            "header_crc": False,
        }
    )
    zlib_json = json.loads(run(cli, "inspect-zlib-header-hex", zlib_frame.hex(), "json"))
    assert zlib_json["schema"] == "vort.zlib_header_info"
    assert zlib_json["uses_dictionary"] is False
    assert zlib_json["data_offset"] == 2
    validate_value_against_manifest(zlib_json, schemas_def)

    zlib_inner_json = json.loads(run(cli, "inspect-zlib-deflate-header-hex", zlib_frame.hex(), "json"))
    assert zlib_inner_json["schema"] == "vort.wrapped_deflate_header_info"
    assert zlib_inner_json["wrapper"] == "zlib"
    assert zlib_inner_json["raw_header"]["block_type"] == "fixed"
    cases.append(
        {
            "name": "zlib_inner_deflate",
            "schema_name": "vort.wrapped_deflate_header_info",
            "command": "inspect-zlib-deflate-header-hex",
            "sample": zlib_frame.hex(),
            "argv": ["inspect-zlib-deflate-header-hex", zlib_frame.hex()],
            "detail": "inner fixed",
            "format": "zlib",
            "bytes": len(zlib_frame),
            "data_offset": zlib_json["data_offset"],
            "has_dictionary": False,
            "has_optional_fields": False,
            "header_crc": False,
        }
    )
    zlib_dict_hex = run(cli, "inspect-zlib-header-hex", zlib_dict_frame.hex())
    require_fields(
        zlib_dict_hex,
        {
            "zlib_header compressed_bytes": str(len(zlib_dict_frame)),
            "data_offset": "6",
            "method": "8",
            "window_bits": "15",
            "fdict": "true",
            "dictid": str(zlib.adler32(dictionary) & 0xFFFFFFFF),
        },
    )
    cases.append(
        {
            "name": "zlib_dictionary",
            "schema_name": "vort.zlib_header_info",
            "command": "inspect-zlib-header-hex",
            "sample": zlib_dict_frame.hex(),
            "argv": ["inspect-zlib-header-hex", zlib_dict_frame.hex()],
            "detail": "FDICT",
            "format": "zlib",
            "bytes": len(zlib_dict_frame),
            "data_offset": 6,
            "has_dictionary": True,
            "has_optional_fields": False,
            "header_crc": False,
        }
    )
    zlib_dict_json = json.loads(run(cli, "inspect-zlib-header-hex", zlib_dict_frame.hex(), "json"))
    assert zlib_dict_json["schema"] == "vort.zlib_header_info"
    assert zlib_dict_json["uses_dictionary"] is True
    assert zlib_dict_json["dictionary_id"] == (zlib.adler32(dictionary) & 0xFFFFFFFF)
    validate_value_against_manifest(zlib_dict_json, schemas_def)

    gzip_hex = run(cli, "inspect-gzip-header-hex", gzip_frame.hex())
    require_fields(
        gzip_hex,
        {
            "gzip_header compressed_bytes": str(len(gzip_frame)),
            "data_offset": "10",
            "flags": "0x00",
            "text": "false",
            "mtime": "0",
            "extra_present": "false",
            "filename": "null",
            "comment": "null",
            "header_crc": "null",
        },
    )
    cases.append(
        {
            "name": "gzip_default",
            "schema_name": "vort.gzip_header_info",
            "command": "inspect-gzip-header-hex",
            "sample": gzip_frame.hex(),
            "argv": ["inspect-gzip-header-hex", gzip_frame.hex()],
            "detail": "-",
            "format": "gzip",
            "bytes": len(gzip_frame),
            "data_offset": 10,
            "has_dictionary": False,
            "has_optional_fields": False,
            "header_crc": False,
        }
    )
    gzip_json = json.loads(run(cli, "inspect-gzip-header-hex", gzip_frame.hex(), "json"))
    assert gzip_json["schema"] == "vort.gzip_header_info"
    assert gzip_json["extra_present"] is False
    assert gzip_json["header_crc"] is None
    validate_value_against_manifest(gzip_json, schemas_def)
    gzip_inner_json = json.loads(run(cli, "inspect-gzip-deflate-header-hex", gzip_frame.hex(), "json"))
    assert gzip_inner_json["schema"] == "vort.wrapped_deflate_header_info"
    assert gzip_inner_json["wrapper"] == "gzip"
    assert gzip_inner_json["raw_header"]["block_type"] == "fixed"
    cases.append(
        {
            "name": "gzip_inner_deflate",
            "schema_name": "vort.wrapped_deflate_header_info",
            "command": "inspect-gzip-deflate-header-hex",
            "sample": gzip_frame.hex(),
            "argv": ["inspect-gzip-deflate-header-hex", gzip_frame.hex()],
            "detail": "inner fixed",
            "format": "gzip",
            "bytes": len(gzip_frame),
            "data_offset": gzip_json["data_offset"],
            "has_dictionary": False,
            "has_optional_fields": False,
            "header_crc": False,
        }
    )
    gzip_optional_hex = run(cli, "inspect-gzip-header-hex", gzip_optional_frame.hex())
    require_fields(
        gzip_optional_hex,
        {
            "gzip_header compressed_bytes": str(len(gzip_optional_frame)),
            "data_offset": "31",
            "flags": "0x1e",
            "extra_present": "true",
            "extra_len": "4",
            "extra_hex": "61626364",
            "filename": '"name"',
            "comment": '"comment"',
            "header_crc": "18658",
        },
    )
    cases.append(
        {
            "name": "gzip_optional",
            "schema_name": "vort.gzip_header_info",
            "command": "inspect-gzip-header-hex",
            "sample": gzip_optional_frame.hex(),
            "argv": ["inspect-gzip-header-hex", gzip_optional_frame.hex()],
            "detail": "FEXTRA/FNAME/FCOMMENT/FHCRC",
            "format": "gzip",
            "bytes": len(gzip_optional_frame),
            "data_offset": 31,
            "has_dictionary": False,
            "has_optional_fields": True,
            "header_crc": True,
        }
    )
    gzip_optional_json = json.loads(run(cli, "inspect-gzip-header-hex", gzip_optional_frame.hex(), "json"))
    assert gzip_optional_json["schema"] == "vort.gzip_header_info"
    assert gzip_optional_json["extra_hex"] == "61626364"
    assert gzip_optional_json["filename"] == "name"
    assert gzip_optional_json["comment"] == "comment"
    assert gzip_optional_json["header_crc"] == 18658
    validate_value_against_manifest(gzip_optional_json, schemas_def)

    with tempfile.TemporaryDirectory(prefix="vort-header-inspect-") as tmp:
        tmp_path = Path(tmp)
        raw_path = tmp_path / "sample.raw"
        raw_stored_path = tmp_path / "sample-stored.raw"
        raw_dynamic_path = tmp_path / "sample-dynamic.raw"
        zlib_path = tmp_path / "sample.zlib"
        zlib_dict_path = tmp_path / "sample-dict.zlib"
        gzip_path = tmp_path / "sample.gz"
        gzip_optional_path = tmp_path / "sample-options.gz"
        raw_path.write_bytes(raw_frame)
        raw_stored_path.write_bytes(raw_stored_frame)
        raw_dynamic_path.write_bytes(raw_dynamic_frame)
        zlib_path.write_bytes(zlib_frame)
        zlib_dict_path.write_bytes(zlib_dict_frame)
        gzip_path.write_bytes(gzip_frame)
        gzip_optional_path.write_bytes(gzip_optional_frame)

        raw_file = run(cli, "inspect-raw-header-file", str(raw_path))
        raw_stored_file = run(cli, "inspect-raw-header-file", str(raw_stored_path))
        raw_dynamic_file = run(cli, "inspect-raw-header-file", str(raw_dynamic_path))
        zlib_file = run(cli, "inspect-zlib-header-file", str(zlib_path))
        zlib_dict_file = run(cli, "inspect-zlib-header-file", str(zlib_dict_path))
        gzip_file = run(cli, "inspect-gzip-header-file", str(gzip_path))
        gzip_optional_file = run(cli, "inspect-gzip-header-file", str(gzip_optional_path))
        raw_file_json = json.loads(run(cli, "inspect-raw-header-file", str(raw_path), "json"))
        raw_stored_file_json = json.loads(run(cli, "inspect-raw-header-file", str(raw_stored_path), "json"))
        raw_dynamic_file_json = json.loads(run(cli, "inspect-raw-header-file", str(raw_dynamic_path), "json"))
        zlib_file_json = json.loads(run(cli, "inspect-zlib-header-file", str(zlib_path), "json"))
        gzip_optional_file_json = json.loads(run(cli, "inspect-gzip-header-file", str(gzip_optional_path), "json"))
        if raw_file != raw_hex:
            raise AssertionError(f"raw file/hex inspection mismatch: {raw_file!r} != {raw_hex!r}")
        if raw_stored_file != raw_stored_hex:
            raise AssertionError(f"raw stored file/hex inspection mismatch: {raw_stored_file!r} != {raw_stored_hex!r}")
        if raw_dynamic_file != raw_dynamic_hex:
            raise AssertionError(f"raw dynamic file/hex inspection mismatch: {raw_dynamic_file!r} != {raw_dynamic_hex!r}")
        if zlib_file != zlib_hex:
            raise AssertionError(f"zlib file/hex inspection mismatch: {zlib_file!r} != {zlib_hex!r}")
        if zlib_dict_file != zlib_dict_hex:
            raise AssertionError(f"zlib dict file/hex inspection mismatch: {zlib_dict_file!r} != {zlib_dict_hex!r}")
        if gzip_file != gzip_hex:
            raise AssertionError(f"gzip file/hex inspection mismatch: {gzip_file!r} != {gzip_hex!r}")
        if gzip_optional_file != gzip_optional_hex:
            raise AssertionError(f"gzip optional file/hex inspection mismatch: {gzip_optional_file!r} != {gzip_optional_hex!r}")
        if raw_file_json != raw_json:
            raise AssertionError(f"raw JSON file/hex inspection mismatch: {raw_file_json!r} != {raw_json!r}")
        if raw_stored_file_json != raw_stored_json:
            raise AssertionError(f"raw stored JSON file/hex inspection mismatch: {raw_stored_file_json!r} != {raw_stored_json!r}")
        if raw_dynamic_file_json != raw_dynamic_json:
            raise AssertionError(f"raw dynamic JSON file/hex inspection mismatch: {raw_dynamic_file_json!r} != {raw_dynamic_json!r}")
        if zlib_file_json != zlib_json:
            raise AssertionError(f"zlib JSON file/hex inspection mismatch: {zlib_file_json!r} != {zlib_json!r}")
        if gzip_optional_file_json != gzip_optional_json:
            raise AssertionError(f"gzip optional JSON file/hex inspection mismatch: {gzip_optional_file_json!r} != {gzip_optional_json!r}")

    negative_error_counts: dict[str, int] = {}
    for item in negative_items:
        error_name = str(item["expected_error"])
        negative_error_counts[error_name] = negative_error_counts.get(error_name, 0) + 1

    summary = {
        "schema": "vort.header_inspect_smoke",
        "schema_version": 1,
        "ok": True,
        "cases": cases,
        "case_count": len(cases),
        "raw_cases": sum(1 for case in cases if case["format"] == "raw"),
        "zlib_cases": sum(1 for case in cases if case["format"] == "zlib"),
        "gzip_cases": sum(1 for case in cases if case["format"] == "gzip"),
        "dictionary_cases": sum(1 for case in cases if case["has_dictionary"]),
        "optional_header_cases": sum(1 for case in cases if case["has_optional_fields"]),
        "fhcrc_cases": sum(1 for case in cases if case["header_crc"]),
        "negative_cases": len(negative_cases),
        "raw_negative_cases": sum(1 for item in negative_items if item["format"] == "raw"),
        "zlib_negative_cases": sum(1 for item in negative_items if item["format"] == "zlib"),
        "gzip_negative_cases": sum(1 for item in negative_items if item["format"] == "gzip"),
        "negative_error_counts": negative_error_counts,
        "negative_items": negative_items,
    }
    if summary_path is not None:
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    if markdown_path is not None:
        write_markdown(markdown_path, summary)
        markdown = markdown_path.read_text()
        if "…" not in markdown:
            raise AssertionError("markdown output did not shorten any long samples")
        for long_sample in (raw_dynamic_frame_hex, gzip_optional_frame.hex()):
            if long_sample in markdown:
                raise AssertionError("markdown output leaked an unshortened long sample")
        if raw_dynamic_frame_hex not in json.dumps(summary):
            raise AssertionError("JSON summary lost the full raw dynamic replay sample")
    print("header inspect smoke: raw=ok zlib=ok zlib_dict=ok gzip=ok gzip_optional=ok negatives=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
