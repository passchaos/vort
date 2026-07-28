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

    # Keep a compact four-stream fixture because those sections need explicit
    # stream-table parsing beyond the high-compression single-stream case above.
    four_stream_cases = [
        (
            bytes.fromhex(
                "28b52ffd20f86d0500864f2a1290cf016c3325f0fdb0cddd2ce10b3339ce4e"
                "24002400240020bfb1a5123a279f76cdb7192d3a14f27ba43cef2102b95c"
                "08d2f8fea2efd493dfe58e0320bfb1a5123a279f76cdb7192d3a14f27b"
                "a43cef2102b95c08d2f8fea2efd493dfe58e0320bfb1a5123a279f76cdb"
                "7192d3a14f27ba43cef2102b95c08d2f8fea2efd493dfe58e0320bfb1a5"
                "123a279f76cdb7192d3a14f27ba43cef2102b95c08d2f8fea2efd493dfe"
                "58e0300"
            ),
            b'{"key":"value","number":123,"array":[1,2,3],"text":"abcdefg"}\n' * 4,
        ),
    ]
    for frame, payload in four_stream_cases:
        if zstd_decompress(frame) != payload:
            raise AssertionError("four-stream fixture failed system zstd decode")
        assert_vort_native_decode(frame, payload)

    # System zstd does not reliably emit a tiny treeless-literals fixture on
    # demand, so keep one handcrafted two-block frame here. The second block
    # omits the Huffman tree and reuses the first block's tree, exercising the
    # native frame-state path through the CLI surface while still checking the
    # bytes against the system zstd decoder.
    treeless_cases = [
        (
            bytes.fromhex(
                "28b52ffd00680c0200e2c30d1290cf016c3325f0fdb0cddd2ce10b3339ce4e20b"
                "fb1a5123a279f76cdb7192d3a14f27ba43cef2102b95c08d2f8fea2efd493d"
                "fe58e0301007e7f411fa0750100e3030920bfb1a5123a279f76cdb7192d3a"
                "14f27ba43cef2102b95c08d2f8fea2efd493dfe58e0301007e7f411fa0"
            ),
            b'{"key":"value","number":123,"array":[1,2,3],"text":"abcdefg"}\n' * 200,
        ),
    ]
    for frame, payload in treeless_cases:
        if zstd_decompress(frame) != payload:
            raise AssertionError("treeless fixture failed system zstd decode")
        assert_vort_native_decode(frame, payload)

    # These generated system-zstd frames exercise FSE_Compressed_Mode sequence
    # tables. Level 1 uses a compressed offset table, while level 6 uses
    # compressed LL/OF/ML tables on the same small structured payload here.
    fse_payload = b"".join(
        b'{"k":"%04d","n":%d,"txt":"abcdefghijklmnopqrstuvwxyz0123456789"}\n' % (i, i)
        for i in range(20)
    )
    fse_cases = [(fse_payload, 1), (fse_payload, 6)]
    for payload, level in fse_cases:
        assert_vort_native_decode(zstd_compress(payload, level), payload)

    # A DNA-like alphabet exposes long direct offsets interleaved with repeated
    # offsets. This protects the native decoder from corrupting the previous
    # offset ring while installing a direct offset from the sequence stream.
    dna_payload = bytes(b"ACGTN"[(i * 17 + i // 7 + i // 31) % 5] for i in range(4200))
    direct_offset_cases = [(dna_payload, 3)]
    for payload, level in direct_offset_cases:
        assert_vort_native_decode(zstd_compress(payload, level), payload)

    # Large high-compression printable data produces multiple compressed blocks
    # with mixed FSE table modes. This guards the LL/OF/ML table payload order
    # and repeated table state across blocks.
    printable_payload = bytes(((i * 37 + i // 11 + i // 101) % 95) + 32 for i in range(200_000))
    mixed_table_cases = [(printable_payload, 19)]
    for payload, level in mixed_table_cases:
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
        f"huffman_cases={len(huffman_cases)} four_stream_cases={len(four_stream_cases)} "
        f"treeless_cases={len(treeless_cases)} fse_cases={len(fse_cases)} "
        f"direct_offset_cases={len(direct_offset_cases)} mixed_table_cases={len(mixed_table_cases)} "
        f"unsupported_cases={len(unsupported_cases)} zstd={pathlib.Path(ZSTD).name}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
