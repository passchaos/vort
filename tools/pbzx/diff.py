#!/usr/bin/env python3
import argparse
import random
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


def run(*args: object, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def expect_failure(*args: object, error_name: str) -> None:
    result = run(*args, check=False)
    if result.returncode == 0:
        raise AssertionError(f"command unexpectedly succeeded: {args}")
    if error_name.encode() not in result.stderr:
        raise AssertionError(
            f"missing {error_name}: {result.stderr.decode(errors='replace')}"
        )


def payload() -> bytes:
    rng = random.Random(0x5042_5A58)
    return (
        (b"Apple PBZX external payload 0123456789\n" * 256)[:4096]
        + rng.randbytes(4096)
        + (b"PBZX final partial chunk\n" * 200)[:1733]
    )


def build_reference(xz_cli: Path, plain: bytes, chunk_size: int, temp: Path) -> bytes:
    output = bytearray(b"pbzx" + struct.pack(">Q", chunk_size))
    for index, position in enumerate(range(0, len(plain), chunk_size)):
        chunk = plain[position : position + chunk_size]
        if index == 1:
            selected = chunk
        else:
            source = temp / f"reference-{index}.raw"
            source.write_bytes(chunk)
            selected = run(xz_cli, "-c", "-6", source).stdout
        output.extend(struct.pack(">QQ", len(chunk), len(selected)))
        output.extend(selected)
    return bytes(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--xz", type=Path)
    parser.add_argument("--pbzx-tool", type=Path)
    args = parser.parse_args()
    xz_cli = args.xz or (Path(found) if (found := shutil.which("xz")) else None)
    pbzx_tool = args.pbzx_tool or (
        Path(found) if (found := shutil.which("pbzx-tool")) else None
    )

    self_cases = 0
    external_encode = 0
    external_decode = 0
    malformed = 0
    plain = payload()
    with tempfile.TemporaryDirectory(prefix="vort-pbzx-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.raw"
        source.write_bytes(plain)
        for mode in ("stored", "xz", "auto"):
            encoded = temp / f"vort-{mode}.pbzx"
            decoded = temp / f"vort-{mode}.raw"
            range_output = temp / f"vort-{mode}.range"
            run(args.cli, "encode-pbzx", source, encoded, mode, 4096)
            run(args.cli, "inspect-pbzx", encoded)
            run(args.cli, "decode-pbzx", encoded, decoded, len(plain))
            if decoded.read_bytes() != plain:
                raise AssertionError(f"Vort PBZX round trip mismatch for {mode}")
            range_offset = 4096 - 37
            range_len = 4096 + 79
            run(
                args.cli,
                "decode-pbzx-range",
                encoded,
                range_output,
                range_offset,
                range_len,
            )
            if range_output.read_bytes() != plain[range_offset : range_offset + range_len]:
                raise AssertionError(f"Vort PBZX range mismatch for {mode}")
            self_cases += 1
            if pbzx_tool is not None:
                reference_out = temp / f"reference-decode-{mode}.raw"
                run(pbzx_tool, "decompress", encoded, reference_out)
                if reference_out.read_bytes() != plain:
                    raise AssertionError(f"reference PBZX decode mismatch for {mode}")
                external_encode += 1

        if xz_cli is not None:
            reference = temp / "reference.pbzx"
            reference.write_bytes(build_reference(xz_cli, plain, 4096, temp))
            output = temp / "reference.out"
            summary = run(args.cli, "inspect-pbzx", reference).stdout
            if b"stored=true" not in summary or b"stored=false" not in summary:
                raise AssertionError("reference PBZX did not preserve mixed chunks")
            run(args.cli, "decode-pbzx", reference, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError("Vort decode of system-XZ PBZX mismatch")
            external_decode += 1

        valid = temp / "vort-auto.pbzx"
        short = temp / "short.pbzx"
        short.write_bytes(b"pbzx")
        expect_failure(args.cli, "inspect-pbzx", short, error_name="TruncatedFrame")
        malformed += 1

        bad_magic = bytearray(valid.read_bytes())
        bad_magic[0] ^= 1
        bad_magic_path = temp / "bad-magic.pbzx"
        bad_magic_path.write_bytes(bad_magic)
        expect_failure(args.cli, "inspect-pbzx", bad_magic_path, error_name="InvalidMagic")
        malformed += 1

        truncated = temp / "truncated.pbzx"
        truncated.write_bytes(valid.read_bytes()[:-1])
        expect_failure(args.cli, "inspect-pbzx", truncated, error_name="TruncatedFrame")
        malformed += 1

        expect_failure(
            args.cli,
            "decode-pbzx",
            valid,
            temp / "limited.raw",
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1

        expect_failure(
            args.cli,
            "decode-pbzx-range",
            valid,
            temp / "range.raw",
            len(plain) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1

    print(
        f"self={self_cases} xz={xz_cli is not None} pbzx={pbzx_tool is not None} "
        f"external_encode={external_encode} external_decode={external_decode} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
