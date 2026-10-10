#!/usr/bin/env python3
import argparse
import binascii
import gzip
import shutil
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path


EOF_MARKER = bytes.fromhex("1f8b08040000000000ff0600424302001b0003000000000000000000")


def run(*args: object, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def make_block(data: bytes) -> bytes:
    compressor = zlib.compressobj(6, zlib.DEFLATED, -15)
    compressed = compressor.compress(data) + compressor.flush()
    size = 18 + len(compressed) + 8
    if size > 65536:
        raise AssertionError("reference BGZF block is too large")
    header = bytearray.fromhex("1f8b08040000000000ff0600424302000000")
    header[16:18] = struct.pack("<H", size - 1)
    trailer = struct.pack("<II", binascii.crc32(data) & 0xFFFFFFFF, len(data))
    return bytes(header) + compressed + trailer


def make_bgzf(data: bytes, block_size: int = 32768) -> bytes:
    blocks = (
        make_block(data[pos : pos + block_size])
        for pos in range(0, len(data), block_size)
    )
    return b"".join(blocks) + EOF_MARKER


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--gzip", dest="gzip_tool", type=Path)
    args = parser.parse_args()
    gzip_tool = args.gzip_tool
    if gzip_tool is None:
        found = shutil.which("gzip")
        gzip_tool = Path(found) if found else None

    payload = bytes((index * 37 + index // 13) & 0xFF for index in range(180_000))
    writer_cases = 0
    reference_cases = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-bgzf-diff-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.bin"
        source.write_bytes(payload)
        first = temp / "vort-first.bgz"
        second = temp / "vort-second.bgz"
        for archive in (first, second):
            run(args.cli, "encode-bgzf-file", source, archive)
        if first.read_bytes() != second.read_bytes():
            raise AssertionError("Vort BGZF writer output is not deterministic")
        if gzip.decompress(first.read_bytes()) != payload:
            raise AssertionError("Python gzip rejected Vort BGZF output")
        if gzip_tool is not None:
            run(gzip_tool, "-t", first)
        decoded = temp / "vort-decoded.bin"
        run(args.cli, "decode-bgzf-file", first, decoded, len(payload))
        if decoded.read_bytes() != payload:
            raise AssertionError("Vort BGZF self decode mismatch")
        listing = run(args.cli, "inspect-bgzf-file", first).stdout
        if "eof=true" not in listing or "bgzf_blocks=" not in listing:
            raise AssertionError(f"Vort BGZF metadata mismatch: {listing}")
        writer_cases += 1

        reference = temp / "python.bgz"
        reference.write_bytes(make_bgzf(payload))
        reference_output = temp / "reference.out"
        run(args.cli, "decode-bgzf-file", reference, reference_output, len(payload))
        if reference_output.read_bytes() != payload:
            raise AssertionError("Vort rejected Python-generated BGZF")
        reference_cases += 1

        limited = run(
            args.cli,
            "decode-bgzf-file",
            first,
            temp / "limited.out",
            len(payload) - 1,
            check=False,
        )
        if limited.returncode == 0 or "OutputLimitExceeded" not in limited.stderr:
            raise AssertionError("Vort ignored the BGZF output limit")
        malformed += 1

        corrupt = bytearray(first.read_bytes())
        first_size = struct.unpack("<H", corrupt[16:18])[0] + 1
        corrupt[first_size - 8] ^= 1
        corrupt_path = temp / "bad-crc.bgz"
        corrupt_path.write_bytes(corrupt)
        failed = run(
            args.cli,
            "decode-bgzf-file",
            corrupt_path,
            temp / "bad-crc.out",
            len(payload),
            check=False,
        )
        if failed.returncode == 0 or "ChecksumMismatch" not in failed.stderr:
            raise AssertionError("Vort accepted a corrupt BGZF CRC")
        malformed += 1

        bad_extra = bytearray(first.read_bytes())
        bad_extra[12:14] = b"XX"
        bad_extra_path = temp / "bad-extra.bgz"
        bad_extra_path.write_bytes(bad_extra)
        if run(args.cli, "inspect-bgzf-file", bad_extra_path, check=False).returncode == 0:
            raise AssertionError("Vort accepted BGZF without a BC subfield")
        malformed += 1

    print(
        f"writer_cases={writer_cases} reference_cases={reference_cases} "
        f"gzip={gzip_tool is not None} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
