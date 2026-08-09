#!/usr/bin/env python3
"""Black-box smoke for the Zstd native stream summary CLI."""

from __future__ import annotations

import json
import pathlib
import struct
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run_cli(cli: pathlib.Path, *args: str) -> str:
    return subprocess.run([str(cli), *args], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()


def require_cli_failure(cli: pathlib.Path, path: pathlib.Path, expected_error: str, expected_phase: str, expected_offset: int, context: str) -> None:
    result = subprocess.run(
        [str(cli), "summary-zstd-native-file", str(path), "json"],
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if result.returncode == 0:
        raise AssertionError(f"{context}: expected failure {expected_error}, got success: {result.stdout!r}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise AssertionError(f"{context}: expected structured error JSON, got {result.stdout!r}") from exc
    expected = {
        "schema": "vort.zstd_native_stream_summary_error",
        "schema_version": 1,
        "ok": False,
        "compressed_bytes": path.stat().st_size,
        "error": expected_error,
        "phase": expected_phase,
        "offset": expected_offset,
    }
    for key, value in expected.items():
        if payload.get(key) != value:
            raise AssertionError(f"{context}: expected {key}={value!r}, got {payload.get(key)!r} in {payload!r}")


def parse_fields(output: str) -> dict[str, int]:
    fields: dict[str, int] = {}
    for token in output.split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        fields[key] = int(value)
    return fields


def skippable_frame(skippable_id: int, payload: bytes) -> bytes:
    if not 0 <= skippable_id <= 15:
        raise ValueError(skippable_id)
    return struct.pack("<II", 0x184D2A50 + skippable_id, len(payload)) + payload


def dictionary_id_raw_frame(dictionary_id: int, payload: bytes) -> bytes:
    if not 0 < dictionary_id <= 0xFF:
        raise ValueError(dictionary_id)
    if len(payload) > 0xFF:
        raise ValueError("fixture keeps a one-byte content-size field")
    block_header = (len(payload) << 3) | 1
    return (
        b"\x28\xb5\x2f\xfd"
        + bytes([0x21, dictionary_id, len(payload)])
        + struct.pack("<I", block_header)[:3]
        + payload
    )


def require_fields(actual: dict[str, int], expected: dict[str, int], context: str) -> None:
    for key, value in expected.items():
        if actual.get(key) != value:
            raise AssertionError(f"{context}: expected {key}={value}, got {actual.get(key)} in {actual}")


JSON_TO_TEXT_FIELDS = {
    "compressed_bytes": "zstd_native_compressed_bytes",
    "frame_count": "frames",
    "skippable_frame_count": "skippable_frames",
    "checksum_frame_count": "checksum_frames",
    "dictionary_id_frame_count": "dictionary_id_frames",
    "content_size_frame_count": "content_size_frames",
    "declared_content_bytes": "declared_content_bytes",
    "block_count": "blocks",
    "compressed_block_count": "compressed_blocks",
    "rle_block_count": "rle_blocks",
    "raw_block_count": "raw_blocks",
    "payload_bytes": "payload_bytes",
    "skippable_payload_bytes": "skippable_payload_bytes",
}


def require_json_matches_text(payload: dict[str, object], summary: dict[str, int], context: str) -> None:
    if payload.get("schema") != "vort.zstd_native_stream_summary":
        raise AssertionError(f"{context}: unexpected schema {payload!r}")
    if payload.get("schema_version") != 1:
        raise AssertionError(f"{context}: unexpected schema_version {payload!r}")
    for json_key, text_key in JSON_TO_TEXT_FIELDS.items():
        if payload.get(json_key) != summary.get(text_key):
            raise AssertionError(
                f"{context}: JSON {json_key}={payload.get(json_key)!r} "
                f"does not match text {text_key}={summary.get(text_key)!r}; payload={payload!r} summary={summary!r}"
            )


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: zstd_native_summary_cli_probe.py <vort-cli>")
    cli = pathlib.Path(sys.argv[1]).resolve()
    cache_dir = ROOT / ".zig-cache"
    cache_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="vort-zstd-summary-cli-", dir=cache_dir) as tmpdir:
        tmp = pathlib.Path(tmpdir)
        first_payload = b"zstd summary first payload"
        second_payload = b"zstd summary second payload"
        first_plain = tmp / "first.txt"
        second_plain = tmp / "second.txt"
        first_frame = tmp / "first.zst"
        second_frame = tmp / "second.zst"
        stream_path = tmp / "stream.zst"
        first_plain.write_bytes(first_payload)
        second_plain.write_bytes(second_payload)

        run_cli(cli, "encode-zstd-native-file", str(first_plain), str(first_frame), "raw_or_rle", "false", "true")
        single_summary = parse_fields(run_cli(cli, "summary-zstd-native-file", str(first_frame)))
        require_fields(
            single_summary,
            {
                "frames": 1,
                "skippable_frames": 0,
                "checksum_frames": 0,
                "dictionary_id_frames": 0,
                "content_size_frames": 1,
                "declared_content_bytes": len(first_payload),
                "blocks": 1,
                "raw_blocks": 1,
                "rle_blocks": 0,
                "compressed_blocks": 0,
                "payload_bytes": len(first_payload),
                "skippable_payload_bytes": 0,
            },
            "single-frame summary",
        )
        single_json = json.loads(run_cli(cli, "summary-zstd-native-file", str(first_frame), "json"))
        require_json_matches_text(single_json, single_summary, "single-frame JSON summary")

        run_cli(cli, "encode-zstd-native-file", str(second_plain), str(second_frame), "raw_or_rle", "true", "true")
        skip_a = b"summary metadata a"
        skip_b = b"summary metadata bb"
        dict_payload = b"abc"
        dict_frame = dictionary_id_raw_frame(7, dict_payload)
        stream_path.write_bytes(
            first_frame.read_bytes()
            + skippable_frame(3, skip_a)
            + skippable_frame(12, skip_b)
            + second_frame.read_bytes()
            + dict_frame
        )
        stream_summary = parse_fields(run_cli(cli, "summary-zstd-native-file", str(stream_path)))
        require_fields(
            stream_summary,
            {
                "frames": 3,
                "skippable_frames": 2,
                "checksum_frames": 1,
                "dictionary_id_frames": 1,
                "content_size_frames": 3,
                "declared_content_bytes": len(first_payload) + len(second_payload) + len(dict_payload),
                "blocks": 3,
                "raw_blocks": 3,
                "rle_blocks": 0,
                "compressed_blocks": 0,
                "payload_bytes": len(first_payload) + len(second_payload) + len(dict_payload),
                "skippable_payload_bytes": len(skip_a) + len(skip_b),
            },
            "concatenated/skippable summary",
        )
        if stream_summary["zstd_native_compressed_bytes"] != stream_path.stat().st_size:
            raise AssertionError(f"summary compressed size mismatch: {stream_summary}")
        stream_json = json.loads(run_cli(cli, "summary-zstd-native-file", str(stream_path), "json"))
        require_json_matches_text(stream_json, stream_summary, "concatenated/skippable JSON summary")

        malformed_path = tmp / "bad-magic.zst"
        truncated_path = tmp / "truncated-header.zst"
        truncated_skip_path = tmp / "truncated-skippable.zst"
        malformed_path.write_bytes(b"not-zstd")
        truncated_path.write_bytes(b"\x28\xb5\x2f")
        truncated_skip_path.write_bytes(skippable_frame(2, b"metadata")[:-3])
        require_cli_failure(cli, malformed_path, "InvalidMagic", "magic", 0, "bad magic summary")
        require_cli_failure(cli, truncated_path, "TruncatedFrame", "magic", truncated_path.stat().st_size, "truncated header summary")
        require_cli_failure(cli, truncated_skip_path, "TruncatedFrame", "skippable_payload", truncated_skip_path.stat().st_size, "truncated skippable summary")

    print("zstd_native_summary_cli_probe=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
