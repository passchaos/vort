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


def skippable_frame(skippable_id: int, payload: bytes) -> bytes:
    if not 0 <= skippable_id <= 15:
        raise ValueError(skippable_id)
    return (0x184D2A50 + skippable_id).to_bytes(4, "little") + len(payload).to_bytes(4, "little") + payload


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


def assert_vort_native_huffman_literals(frame: bytes) -> None:
    if frame[:4] != bytes.fromhex("28b52ffd"):
        raise AssertionError("missing zstd magic")
    descriptor = frame[4]
    offset = 5
    if descriptor & 0x08:
        raise AssertionError("reserved frame bit set")
    single_segment = bool(descriptor & 0x20)
    if not single_segment:
        offset += 1  # Window_Descriptor
    dict_id_flag = descriptor & 0x03
    offset += (0, 1, 2, 4)[dict_id_flag]
    fcs_flag = descriptor >> 6
    if single_segment or fcs_flag != 0:
        offset += 1 << fcs_flag
    if len(frame) - offset < 3:
        raise AssertionError("missing block header")
    block_header = int.from_bytes(frame[offset : offset + 3], "little")
    offset += 3
    if ((block_header >> 1) & 0x03) != 2:
        raise AssertionError("expected compressed block")
    if offset >= len(frame):
        raise AssertionError("missing literals header")
    if (frame[offset] & 0x03) != 2:
        raise AssertionError("expected compressed Huffman literals")


def zstd_frame_payload_offset(frame: bytes) -> int:
    if frame[:4] != bytes.fromhex("28b52ffd"):
        raise AssertionError("missing zstd magic")
    descriptor = frame[4]
    if descriptor & 0x08:
        raise AssertionError("reserved frame bit set")
    offset = 5
    single_segment = bool(descriptor & 0x20)
    if not single_segment:
        offset += 1
    offset += (0, 1, 2, 4)[descriptor & 0x03]
    fcs_flag = descriptor >> 6
    if single_segment or fcs_flag != 0:
        offset += 1 << fcs_flag
    return offset


def assert_vort_native_treeless_second_block(frame: bytes) -> None:
    offset = zstd_frame_payload_offset(frame)
    if len(frame) - offset < 3:
        raise AssertionError("missing first block header")
    first_header = int.from_bytes(frame[offset : offset + 3], "little")
    first_type = (first_header >> 1) & 0x03
    first_len = first_header >> 3
    if first_type != 2:
        raise AssertionError("expected first block to be compressed")
    if first_header & 0x01:
        raise AssertionError("expected more than one block")
    first_literals_offset = offset + 3
    if first_literals_offset >= len(frame) or (frame[first_literals_offset] & 0x03) != 2:
        raise AssertionError("expected first block compressed Huffman literals")
    offset += 3 + first_len
    if len(frame) - offset < 3:
        raise AssertionError("missing second block header")
    second_header = int.from_bytes(frame[offset : offset + 3], "little")
    second_type = (second_header >> 1) & 0x03
    second_len = second_header >> 3
    if second_type != 2:
        raise AssertionError("expected second block to be compressed")
    second_literals_offset = offset + 3
    if second_len == 0 or second_literals_offset >= len(frame):
        raise AssertionError("missing second literals header")
    if (frame[second_literals_offset] & 0x03) != 3:
        raise AssertionError("expected second block treeless Huffman literals")


def has_vort_native_treeless_second_block(frame: bytes) -> bool:
    try:
        assert_vort_native_treeless_second_block(frame)
    except AssertionError:
        return False
    return True


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
    def deterministic_text(seed: int, size: int) -> str:
        state = seed
        out = []
        for _ in range(size):
            state = (state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
            out.append(chr((state >> 24) % 26 + 65))
        return "".join(out)

    large_duplicate_text = deterministic_text(0x9E37_79B9, 8192)
    large_multi_a = deterministic_text(0x243F_6A88, 4096)
    large_multi_b = deterministic_text(0xB7E1_5162, 4096)
    predefined_multi_large = deterministic_text(0x4528_21E6, 8192)
    predefined_multi_small = deterministic_text(0x38D0_13F7, 257)
    two_symbol_state = 1
    two_symbol_huffman_chars = []
    for _ in range(192):
        two_symbol_huffman_chars.append("B" if (two_symbol_state & 1) else "A")
        feedback = (
            (two_symbol_state >> 0)
            ^ (two_symbol_state >> 2)
            ^ (two_symbol_state >> 3)
            ^ (two_symbol_state >> 4)
        ) & 1
        two_symbol_state = (two_symbol_state >> 1) | (feedback << 7)
    two_symbol_huffman_text = "".join(two_symbol_huffman_chars)
    four_symbol_state = 1
    four_symbol_huffman_chars = []
    for _ in range(192):
        four_symbol_state = (four_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        four_symbol_huffman_chars.append("ABCD"[(four_symbol_state >> 30) & 3])
    four_symbol_huffman_text = "".join(four_symbol_huffman_chars)
    six_symbol_state = 0x0BAD_F00D
    six_symbol_huffman_chars = []
    for _ in range(256):
        six_symbol_state = (six_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        six_symbol_huffman_chars.append("ABCDEF"[(six_symbol_state >> 29) % 6])
    six_symbol_huffman_text = "".join(six_symbol_huffman_chars)
    eight_symbol_state = 0x1234_5678
    eight_symbol_huffman_chars = []
    for _ in range(256):
        eight_symbol_state = (eight_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        eight_symbol_huffman_chars.append("ABCDEFGH"[(eight_symbol_state >> 29) & 7])
    eight_symbol_huffman_text = "".join(eight_symbol_huffman_chars)
    sixteen_symbol_state = 0x8765_4321
    sixteen_symbol_huffman_chars = []
    for _ in range(256):
        sixteen_symbol_state = (sixteen_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        sixteen_symbol_huffman_chars.append("ABCDEFGHIJKLMNOP"[(sixteen_symbol_state >> 28) & 15])
    sixteen_symbol_huffman_text = "".join(sixteen_symbol_huffman_chars)
    thirty_two_symbol_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef"
    thirty_two_symbol_state = 0xFEED_BEEF
    thirty_two_symbol_huffman_chars = []
    for _ in range(384):
        thirty_two_symbol_state = (thirty_two_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        thirty_two_symbol_huffman_chars.append(thirty_two_symbol_alphabet[(thirty_two_symbol_state >> 27) & 31])
    thirty_two_symbol_huffman_text = "".join(thirty_two_symbol_huffman_chars)
    sixty_four_symbol_state = 0x3141_5926
    sixty_four_symbol_huffman_chars = []
    for _ in range(512):
        sixty_four_symbol_state = (sixty_four_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        sixty_four_symbol_huffman_chars.append(chr(32 + ((sixty_four_symbol_state >> 26) & 63)))
    sixty_four_symbol_huffman_text = "".join(sixty_four_symbol_huffman_chars)
    printable_huffman_state = 0x2718_2818
    printable_huffman_chars = []
    for _ in range(768):
        printable_huffman_state = (printable_huffman_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        printable_huffman_chars.append(chr(32 + ((printable_huffman_state >> 24) % 95)))
    printable_huffman_text = "".join(printable_huffman_chars)
    four_stream_huffman_state = 0x1618_0339
    four_stream_huffman_chars = []
    for _ in range(4096):
        four_stream_huffman_state = (four_stream_huffman_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        four_stream_huffman_chars.append(chr(32 + ((four_stream_huffman_state >> 24) % 95)))
    four_stream_huffman_text = "".join(four_stream_huffman_chars)
    treeless_writer_huffman_state = 0x577D_F00D
    treeless_writer_huffman_chars = []
    for _ in range((1 << 17) + 4096):
        treeless_writer_huffman_state = (treeless_writer_huffman_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        treeless_writer_huffman_chars.append(chr(32 + ((treeless_writer_huffman_state >> 24) % 95)))
    treeless_writer_huffman_text = "".join(treeless_writer_huffman_chars)

    older_candidate_state = 0x6A09_E667
    older_candidate_chars = []
    for _ in range(8 * 1024):
        older_candidate_state = (older_candidate_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        older_candidate_chars.append(chr(older_candidate_state >> 24))
    older_candidate_text = "".join(older_candidate_chars + older_candidate_chars[:64] + older_candidate_chars + list("tail-data"))
    non_divisible_four_stream_huffman_state = 0x1618_0339
    non_divisible_four_stream_huffman_chars = []
    for _ in range(5190):
        non_divisible_four_stream_huffman_state = (non_divisible_four_stream_huffman_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        non_divisible_four_stream_huffman_chars.append(chr(32 + ((non_divisible_four_stream_huffman_state >> 24) % 95)))
    non_divisible_four_stream_huffman_text = "".join(non_divisible_four_stream_huffman_chars)
    cases = [
        ("", "raw_or_rle", "true", "true"),
        ("hello", "raw_or_rle", "true", "true"),
        ("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "raw_or_rle", "true", "true"),
        ("raw block without checksum", "raw_or_rle", "false", "true"),
        ("raw block without size", "raw_or_rle", "true", "false"),
        ("raw block minimal header", "raw_or_rle", "false", "false"),
        ("literal-only zstd payload", "literal_only", "true", "true"),
        ("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz", "literal_only", "true", "true"),
        ("abc" * 24, "literal_only", "true", "true"),
        ("prefix-abcdefghijklmno-middle-abcdefghijklmno-tail", "literal_only", "true", "true"),
        ("abcdefghijabcdefghijklmnopqrstklmnopqrst", "literal_only", "true", "true"),
        (large_duplicate_text * 2 + "tail-data", "literal_only", "true", "true"),
        (large_multi_a * 2 + large_multi_b * 2 + "tail-data", "literal_only", "true", "true"),
        (predefined_multi_large * 2 + predefined_multi_small * 2 + "tail-data", "literal_only", "true", "true"),
        ("ab" * 12 + "cdef" * 20 + "tail", "literal_only", "true", "true"),
        ("abcdefghijklmnop" * 24, "literal_only", "true", "true"),
        (two_symbol_huffman_text, "literal_only", "true", "true"),
        (four_symbol_huffman_text, "literal_only", "true", "true"),
        (six_symbol_huffman_text, "literal_only", "true", "true"),
        (eight_symbol_huffman_text, "literal_only", "true", "true"),
        (sixteen_symbol_huffman_text, "literal_only", "true", "true"),
        (thirty_two_symbol_huffman_text, "literal_only", "true", "true"),
        (sixty_four_symbol_huffman_text, "literal_only", "true", "true"),
        (printable_huffman_text, "literal_only", "true", "true"),
        (four_stream_huffman_text, "literal_only", "true", "true"),
        (non_divisible_four_stream_huffman_text, "literal_only", "true", "true"),
    ]
    huffman_literal_texts = {
        two_symbol_huffman_text,
        four_symbol_huffman_text,
        six_symbol_huffman_text,
        eight_symbol_huffman_text,
        sixteen_symbol_huffman_text,
        thirty_two_symbol_huffman_text,
        sixty_four_symbol_huffman_text,
        printable_huffman_text,
        four_stream_huffman_text,
        non_divisible_four_stream_huffman_text,
    }
    for text, mode, checksum, content_size in cases:
        encoded_hex = run_cli("encode-zstd-native-hex", text, mode, checksum, content_size)
        frame = bytes.fromhex(encoded_hex)
        if text in huffman_literal_texts:
            assert_vort_native_huffman_literals(frame)
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

    # Zstandard skippable frames are common in container formats. Keep a real
    # system-zstd frame wrapped in leading and trailing metadata so both the
    # reference CLI and Vort's dependency-free native decoder must skip the
    # metadata while preserving the decoded payload.
    skippable_wrapped_cases = [
        (
            b"zstd skippable metadata payload " * 8,
            skippable_frame(3, b"leading-vort-zstd-metadata"),
            skippable_frame(9, b"trailing-vort-zstd-metadata"),
            6,
        ),
    ]
    for payload, prefix, suffix, level in skippable_wrapped_cases:
        frame = prefix + zstd_compress(payload, level) + suffix
        if zstd_decompress(frame) != payload:
            raise AssertionError("skippable-wrapped system frame failed system zstd decode")
        assert_vort_native_decode(frame, payload)

    # Concatenated compatibility streams may carry skippable metadata between
    # zstd frames. Use real system-zstd frames on both sides of the metadata to
    # keep native concatenated-stream decode aligned with the reference CLI.
    skippable_concatenated_cases = [
        (
            b"first zstd concatenated payload ",
            b"second zstd concatenated payload ",
            skippable_frame(5, b"middle-vort-zstd-metadata"),
        ),
    ]
    for first_payload, second_payload, metadata in skippable_concatenated_cases:
        frame = zstd_compress(first_payload, 1) + metadata + zstd_compress(second_payload, 6)
        expected = first_payload + second_payload
        if zstd_decompress(frame) != expected:
            raise AssertionError("skippable-concatenated system frame failed system zstd decode")
        assert_vort_native_decode(frame, expected)

    # Mirror the previous case with Vort-native generated zstd-compatible
    # frames. This protects the writer+decoder interaction through the reference
    # CLI when container metadata is inserted between Vort-generated frames.
    vort_skippable_concatenated_cases = [
        (
            b"first vort-native zstd frame payload ",
            b"second vort-native zstd frame payload ",
            skippable_frame(11, b"vort-generated-middle-metadata"),
        ),
    ]
    for first_payload, second_payload, metadata in vort_skippable_concatenated_cases:
        first_frame = bytes.fromhex(
            run_cli("encode-zstd-native-bytes-hex", first_payload.hex(), "literal_only", "true", "true")
        )
        second_frame = bytes.fromhex(
            run_cli("encode-zstd-native-bytes-hex", second_payload.hex(), "literal_only", "true", "true")
        )
        frame = first_frame + metadata + second_frame
        expected = first_payload + second_payload
        if zstd_decompress(frame) != expected:
            raise AssertionError("vort skippable-concatenated frame failed system zstd decode")
        assert_vort_native_decode(frame, expected)

    # Large high-compression printable data produces multiple compressed blocks
    # with mixed FSE table modes. This guards the LL/OF/ML table payload order
    # and repeated table state across blocks.
    printable_payload = bytes(((i * 37 + i // 11 + i // 101) % 95) + 32 for i in range(200_000))
    mixed_table_cases = [(printable_payload, 19)]
    for payload, level in mixed_table_cases:
        assert_vort_native_decode(zstd_compress(payload, level), payload)

    unsupported_cases = []

    treeless_writer_cases = 0
    with tempfile.TemporaryDirectory(prefix="vort-zstd-native-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        payload = b"file payload for zstd native smoke" * 4
        payload_path = tmp / "sample.payload"
        payload_path.write_bytes(payload)
        # Keep one file-system smoke around the CLI invocation/decompression path.
        frame = bytes.fromhex(
            run_cli("encode-zstd-native-file-hex", str(payload_path), "literal_only", "true")
        )
        frame_path = tmp / "sample.zst"
        out_path = tmp / "sample.out"
        vort_out_path = tmp / "sample.vort.out"
        frame_path.write_bytes(frame)
        subprocess.run([ZSTD, "-dcq", str(frame_path), "-o", str(out_path)], check=True)
        assert out_path.read_bytes() == payload
        run_cli("decode-zstd-native-file-to", str(frame_path), str(vort_out_path), str(len(payload)))
        assert vort_out_path.read_bytes() == payload
        assert_vort_native_decode(frame, payload)

        treeless_payload = treeless_writer_huffman_text.encode()
        treeless_payload_path = tmp / "treeless-writer.payload"
        treeless_payload_path.write_bytes(treeless_payload)
        treeless_frame = bytes.fromhex(
            run_cli("encode-zstd-native-file-hex", str(treeless_payload_path), "literal_only", "true", "true")
        )
        if has_vort_native_treeless_second_block(treeless_frame):
            treeless_writer_cases += 1
        if zstd_decompress(treeless_frame) != treeless_payload:
            raise AssertionError("treeless writer frame failed system zstd decode")
        treeless_frame_path = tmp / "treeless-writer.zst"
        treeless_vort_out_path = tmp / "treeless-writer.vort.out"
        treeless_frame_path.write_bytes(treeless_frame)
        run_cli("decode-zstd-native-file-to", str(treeless_frame_path), str(treeless_vort_out_path), str(len(treeless_payload)))
        assert treeless_vort_out_path.read_bytes() == treeless_payload
        size_out = run_cli("size-zstd-native-file", str(treeless_frame_path), str(len(treeless_payload)))
        assert int(parse_field(size_out, "decoded_bytes")) == len(treeless_payload)

        older_candidate_payload = older_candidate_text.encode("latin1")
        older_candidate_frame = bytes.fromhex(
            run_cli("encode-zstd-native-bytes-hex", older_candidate_payload.hex(), "literal_only", "true", "true")
        )
        if zstd_decompress(older_candidate_frame) != older_candidate_payload:
            raise AssertionError("older duplicate candidate frame failed system zstd decode")
        older_candidate_frame_path = tmp / "older-candidate.zst"
        older_candidate_out_path = tmp / "older-candidate.vort.out"
        older_candidate_frame_path.write_bytes(older_candidate_frame)
        run_cli("decode-zstd-native-file-to", str(older_candidate_frame_path), str(older_candidate_out_path), str(len(older_candidate_payload)))
        assert older_candidate_out_path.read_bytes() == older_candidate_payload

    print(
        f"zstd_native_cli_diff_ok cases={len(cases)} external_cases={len(external_cases)} "
        f"huffman_cases={len(huffman_cases)} four_stream_cases={len(four_stream_cases)} "
        f"treeless_cases={len(treeless_cases)} fse_cases={len(fse_cases)} "
        f"direct_offset_cases={len(direct_offset_cases)} skippable_wrapped_cases={len(skippable_wrapped_cases)} "
        f"skippable_concatenated_cases={len(skippable_concatenated_cases)} "
        f"vort_skippable_concatenated_cases={len(vort_skippable_concatenated_cases)} "
        f"mixed_table_cases={len(mixed_table_cases)} "
        f"treeless_writer_cases={treeless_writer_cases} unsupported_cases={len(unsupported_cases)} "
        f"zstd={pathlib.Path(ZSTD).name}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
