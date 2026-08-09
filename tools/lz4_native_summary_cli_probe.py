#!/usr/bin/env python3
"""Black-box smoke for the LZ4 native stream summary CLI."""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import tempfile

from lz4_native_summary_fixtures import dictionary_id_raw_frame, skippable_frame

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run_cli(cli: pathlib.Path, *args: str) -> str:
    return subprocess.run([str(cli), *args], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()


def require_cli_failure(cli: pathlib.Path, path: pathlib.Path, expected_error: str, context: str) -> None:
    result = subprocess.run(
        [str(cli), "summary-lz4-native-file", str(path), "json"],
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if result.returncode == 0:
        raise AssertionError(f"{context}: expected failure {expected_error}, got success: {result.stdout!r}")
    marker = f"error: {expected_error}"
    if marker not in result.stdout:
        raise AssertionError(
            f"{context}: expected {marker!r} in failure output, got returncode={result.returncode} output={result.stdout!r}"
        )


def parse_fields(output: str) -> dict[str, int]:
    fields: dict[str, int] = {}
    for token in output.split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        fields[key] = int(value)
    return fields


def require_fields(actual: dict[str, int], expected: dict[str, int], context: str) -> None:
    for key, value in expected.items():
        if actual.get(key) != value:
            raise AssertionError(f"{context}: expected {key}={value}, got {actual.get(key)} in {actual}")

JSON_TO_TEXT_FIELDS = {
    "compressed_bytes": "lz4_native_compressed_bytes",
    "frame_count": "frames",
    "skippable_frame_count": "skippable_frames",
    "content_size_frame_count": "content_size_frames",
    "checksum_frame_count": "checksum_frames",
    "block_checksum_frame_count": "block_checksum_frames",
    "dictionary_id_frame_count": "dictionary_id_frames",
    "declared_content_bytes": "declared_content_bytes",
    "block_count": "blocks",
    "compressed_block_count": "compressed_blocks",
    "raw_block_count": "raw_blocks",
    "payload_bytes": "payload_bytes",
    "skippable_payload_bytes": "skippable_payload_bytes",
}


def require_json_matches_text(payload: dict[str, object], summary: dict[str, int], context: str) -> None:
    if payload.get("schema") != "vort.lz4_native_stream_summary":
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
        raise SystemExit("usage: lz4_native_summary_cli_probe.py <vort-cli>")
    cli = pathlib.Path(sys.argv[1]).resolve()
    cache_dir = ROOT / ".zig-cache"
    cache_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="vort-lz4-summary-cli-", dir=cache_dir) as tmpdir:
        tmp = pathlib.Path(tmpdir)
        first_payload = b"lz4 summary first payload"
        second_payload = b"lz4 summary second payload"
        first_plain = tmp / "first.txt"
        second_plain = tmp / "second.txt"
        first_frame = tmp / "first.lz4"
        second_frame = tmp / "second.lz4"
        stream_path = tmp / "stream.lz4"
        first_plain.write_bytes(first_payload)
        second_plain.write_bytes(second_payload)

        run_cli(cli, "encode-lz4-native-file", str(first_plain), str(first_frame))
        single_summary = parse_fields(run_cli(cli, "summary-lz4-native-file", str(first_frame)))
        require_fields(
            single_summary,
            {
                "frames": 1,
                "skippable_frames": 0,
                "content_size_frames": 1,
                "checksum_frames": 1,
                "block_checksum_frames": 0,
                "dictionary_id_frames": 0,
                "declared_content_bytes": len(first_payload),
                "blocks": 1,
                "raw_blocks": 1,
                "compressed_blocks": 0,
                "payload_bytes": len(first_payload),
                "skippable_payload_bytes": 0,
            },
            "single-frame summary",
        )
        single_json = json.loads(run_cli(cli, "summary-lz4-native-file", str(first_frame), "json"))
        require_json_matches_text(single_json, single_summary, "single-frame JSON summary")

        run_cli(cli, "encode-lz4-native-file", str(second_plain), str(second_frame))
        skip_a = b"lz4 summary metadata a"
        skip_b = b"lz4 summary metadata bb"
        dict_payload = b"abc"
        stream_path.write_bytes(
            first_frame.read_bytes()
            + skippable_frame(4, skip_a)
            + skippable_frame(13, skip_b)
            + second_frame.read_bytes()
            + dictionary_id_raw_frame(0x1234_ABCD, dict_payload)
        )
        stream_summary = parse_fields(run_cli(cli, "summary-lz4-native-file", str(stream_path)))
        require_fields(
            stream_summary,
            {
                "frames": 3,
                "skippable_frames": 2,
                "content_size_frames": 3,
                "checksum_frames": 2,
                "block_checksum_frames": 1,
                "dictionary_id_frames": 1,
                "declared_content_bytes": len(first_payload) + len(second_payload) + len(dict_payload),
                "blocks": 3,
                "raw_blocks": 3,
                "compressed_blocks": 0,
                "payload_bytes": len(first_payload) + len(second_payload) + len(dict_payload),
                "skippable_payload_bytes": len(skip_a) + len(skip_b),
            },
            "concatenated/skippable summary",
        )
        if stream_summary["lz4_native_compressed_bytes"] != stream_path.stat().st_size:
            raise AssertionError(f"summary compressed size mismatch: {stream_summary}")
        stream_json = json.loads(run_cli(cli, "summary-lz4-native-file", str(stream_path), "json"))
        require_json_matches_text(stream_json, stream_summary, "concatenated/skippable JSON summary")

        malformed_path = tmp / "bad-magic.lz4"
        truncated_path = tmp / "truncated-header.lz4"
        truncated_skip_path = tmp / "truncated-skippable.lz4"
        malformed_path.write_bytes(b"not-lz4")
        truncated_path.write_bytes(bytes([0x04, 0x22, 0x4D, 0x18, 0x60]))
        truncated_skip_path.write_bytes(skippable_frame(2, b"metadata")[:-3])
        require_cli_failure(cli, malformed_path, "CorruptFrame", "bad magic summary")
        require_cli_failure(cli, truncated_path, "TruncatedFrame", "truncated header summary")
        require_cli_failure(cli, truncated_skip_path, "TruncatedFrame", "truncated skippable summary")

    print("lz4_native_summary_cli_probe=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
