#!/usr/bin/env python3
"""Black-box smoke for Vort native-subset Zstandard frames against zstd CLI."""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "zig-out" / "bin" / "vort"
ZSTD = shutil.which("zstd")


def run_cli(*args: str) -> str:
    return subprocess.run([str(CLI), *args], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()


def parse_field(output: str, name: str) -> str:
    match = re.search(rf"(?:^| ){re.escape(name)}=([^ ]*)", output)
    if not match:
        raise AssertionError(f"missing {name!r} in {output!r}")
    return match.group(1)


def zstd_decompress(frame: bytes) -> bytes:
    if not ZSTD:
        raise RuntimeError("zstd missing")
    result = subprocess.run([ZSTD, "-dcq"], input=frame, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    return result.stdout


def zstd_compress(payload: bytes, level: int = 1) -> bytes:
    if not ZSTD:
        raise RuntimeError("zstd missing")
    return subprocess.run([ZSTD, f"-{level}", "-cq"], input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout


def assert_vort_native_decode(frame: bytes, expected: bytes) -> None:
    encoded_hex = frame.hex()
    out = run_cli("decode-zstd-native-hex", encoded_hex, str(len(expected)))
    assert int(parse_field(out, "decoded_bytes")) == len(expected), out
    assert int(parse_field(out, "crc32")) == (zlib.crc32(expected) & 0xFFFFFFFF), out
    if expected:
        failed = subprocess.run(
            [str(CLI), "decode-zstd-native-hex", encoded_hex, str(len(expected) - 1)],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if failed.returncode == 0 or "OutputLimitExceeded" not in failed.stderr:
            raise AssertionError(f"expected OutputLimitExceeded, got rc={failed.returncode} stderr={failed.stderr!r}")


def assert_vort_native_decode_error(frame: bytes, max_output_len: int, error_name: str) -> None:
    failed = subprocess.run(
        [str(CLI), "decode-zstd-native-hex", frame.hex(), str(max_output_len)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if failed.returncode == 0 or error_name not in failed.stderr:
        raise AssertionError(f"expected {error_name}, got rc={failed.returncode} stderr={failed.stderr!r}")


def main() -> int:
    if not ZSTD:
        print("zstd native CLI diff: zstd=missing")
        return 0
    if not CLI.exists():
        raise SystemExit(f"missing built CLI at {CLI}; run `zig build` first")

    # The system zstd CLI is used as an interoperability oracle for the native
    # raw/RLE frames and for literal-only requests. Literal-only requests may
    # deliberately fall back to raw/RLE blocks when the sequence-free compressed
    # block payload would not be smaller than the regenerated block. That keeps
    # output compatible with deployed zstd builds that reject expanded
    # compressed blocks even though newer format wording allows them.
    cases = [
        ("", "raw_or_rle", "true", "true"),
        ("hello", "raw_or_rle", "true", "true"),
        ("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "raw_or_rle", "true", "true"),
        ("raw block without checksum", "raw_or_rle", "false", "true"),
        ("raw block without size", "raw_or_rle", "true", "false"),
        ("raw block minimal header", "raw_or_rle", "false", "false"),
        ("literal-only zstd payload", "literal_only", "true", "true"),
        ("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz", "literal_only", "true", "true"),
    ]
    for text, mode, checksum, content_size in cases:
        encoded_hex = run_cli("encode-zstd-native-hex", text, mode, checksum, content_size)
        frame = bytes.fromhex(encoded_hex)
        decoded = zstd_decompress(frame)
        expected = text.encode()
        if decoded != expected:
            raise AssertionError((text, mode, checksum, content_size, decoded, expected))
        assert_vort_native_decode(frame, expected)

    # Protect the growing native decoder against real system-zstd output, not
    # only frames emitted by Vort's bootstrap writer. These payloads exercise the
    # simple predefined/mixed sequence paths that are still far short of full
    # zstd, but are now intentionally supported by the native decoder.
    external_cases = [
        b"zstd payload zstd payload zstd payload zstd payload",
        b"abcdefghijklmnopqrstuvwxyz" * 8,
        (b'{"key":"value","number":123,"array":[1,2,3],"text":"abcdefg"}\n' * 20),
    ]
    for payload in external_cases:
        assert_vort_native_decode(zstd_compress(payload, 1), payload)

    # This high-compression case carries a single-stream Huffman literals
    # section followed by predefined sequence decoding. It used to mark the
    # native decoder's Huffman boundary; keep it as a real system-zstd smoke now
    # that the first Huffman literal slice is supported.
    huffman_cases = [
        (b'{"key":"value","number":123,"array":[1,2,3],"text":"abcdefg"}\n' * 100, 19),
    ]
    for payload, level in huffman_cases:
        assert_vort_native_decode(zstd_compress(payload, level), payload)

    unsupported_cases = []

    with tempfile.TemporaryDirectory(prefix="vort-zstd-native-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        payload = b"file payload for zstd native smoke" * 4
        # Keep one file-system smoke around the CLI invocation/decompression path
        # without adding more public Vort file commands yet.
        frame = bytes.fromhex(run_cli("encode-zstd-native-hex", payload.decode(), "raw_or_rle", "true"))
        frame_path = tmp / "sample.zst"
        out_path = tmp / "sample.out"
        frame_path.write_bytes(frame)
        subprocess.run([ZSTD, "-dcq", str(frame_path), "-o", str(out_path)], check=True)
        assert out_path.read_bytes() == payload

    print(
        f"zstd_native_cli_diff_ok cases={len(cases)} external_cases={len(external_cases)} "
        f"huffman_cases={len(huffman_cases)} unsupported_cases={len(unsupported_cases)} zstd={pathlib.Path(ZSTD).name}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
