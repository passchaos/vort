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


def main(argv: list[str]) -> int:
    if len(argv) not in (2, 4):
        print(f"usage: {argv[0]} <vort-cli> [--summary <path>]", file=sys.stderr)
        return 2

    cli = argv[1]
    summary_path: Path | None = None
    if len(argv) == 4:
        if argv[2] != "--summary":
            print(f"usage: {argv[0]} <vort-cli> [--summary <path>]", file=sys.stderr)
            return 2
        summary_path = Path(argv[3])

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
        ("zlib_bad_fcheck", "inspect-zlib-header-hex", "7802", "BadZlibHeader"),
        ("gzip_bad_fhcrc", "inspect-gzip-header-hex", "1f8b0802000000000403a2b2", "BadGzipHeader"),
    ]
    for _, command, sample, expected_error in negative_cases:
        failed = expect_failure(cli, command, sample)
        if expected_error not in failed:
            raise AssertionError(f"expected {expected_error!r} in failure output for {command} {sample}, got {failed!r}")

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
            "header_bits_consumed": "17",
        },
    )
    cases.append(
        {
            "name": "raw_dynamic",
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
    assert raw_dynamic_json["header_bits_consumed"] == 17
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
    }
    if summary_path is not None:
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print("header inspect smoke: raw=ok zlib=ok zlib_dict=ok gzip=ok gzip_optional=ok negatives=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
