#!/usr/bin/env python3
import argparse
import random
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


FRAME_SIZE = 8192


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
    rng = random.Random(0x444158)
    repetitive = (b"PSP DAX differential frame\n" * 400)[:FRAME_SIZE]
    random_frame = rng.randbytes(FRAME_SIZE)
    zeros = bytes(FRAME_SIZE)
    structured = bytes((index * 13 + index // 17) & 0xFF for index in range(FRAME_SIZE))
    return (
        repetitive
        + random_frame
        + random_frame
        + zeros
        + structured
        + repetitive
        + repetitive[:2048]
    )


def maxcso_encode(executable: Path, source: Path, output: Path) -> None:
    run(
        executable,
        "--quiet",
        "--fast",
        "--format=dax",
        source,
        "-o",
        output,
    )


def maxcso_decode(executable: Path, image: Path, output: Path) -> None:
    run(executable, "--quiet", "--decompress", image, "-o", output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--maxcso", type=Path)
    args = parser.parse_args()
    maxcso = args.maxcso or (
        Path(found) if (found := shutil.which("maxcso")) else None
    )

    plain = payload()
    self_cases = 0
    external_encode = 0
    external_decode = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-dax-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.iso"
        source.write_bytes(plain)
        images: dict[str, Path] = {}
        for compression in ("zlib", "raw", "auto"):
            image = temp / f"vort-{compression}.dax"
            output = temp / f"vort-{compression}.iso"
            ranged = temp / f"vort-{compression}.range"
            run(args.cli, "encode-dax", source, image, compression, 6)
            summary = run(args.cli, "inspect-dax", image).stdout
            if b"frames=7" not in summary:
                raise AssertionError(f"Vort DAX inspect mismatch for {compression}")
            if compression == "zlib" and b"version=0" not in summary:
                raise AssertionError("Vort zlib DAX did not use version 0")
            if compression != "zlib" and b"version=1" not in summary:
                raise AssertionError(f"Vort {compression} DAX did not use NC areas")
            run(args.cli, "decode-dax", image, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError(f"Vort DAX round trip mismatch for {compression}")
            range_offset = FRAME_SIZE - 37
            range_length = 2 * FRAME_SIZE + 91
            run(
                args.cli,
                "decode-dax-range",
                image,
                ranged,
                range_offset,
                range_length,
            )
            if ranged.read_bytes() != plain[range_offset : range_offset + range_length]:
                raise AssertionError(f"Vort DAX range mismatch for {compression}")
            images[compression] = image
            self_cases += 1

            if maxcso is not None:
                external = temp / f"vort-{compression}.maxcso.iso"
                maxcso_decode(maxcso, image, external)
                if external.read_bytes() != plain:
                    raise AssertionError(f"maxcso DAX decode mismatch for {compression}")
                external_encode += 1

        partial_plain = plain + b"partial DAX logical tail"
        partial_source = temp / "partial.iso"
        partial_image = temp / "partial.dax"
        partial_output = temp / "partial.out"
        partial_source.write_bytes(partial_plain)
        run(args.cli, "encode-dax", partial_source, partial_image, "auto", 6)
        run(args.cli, "decode-dax", partial_image, partial_output, len(partial_plain))
        if partial_output.read_bytes() != partial_plain:
            raise AssertionError("Vort partial DAX round trip mismatch")
        self_cases += 1

        valid = images["auto"]
        expect_failure(
            args.cli,
            "decode-dax",
            valid,
            temp / "limited.iso",
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-dax-range",
            valid,
            temp / "bad-range.iso",
            len(plain) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1
        short = temp / "short.dax"
        short.write_bytes(valid.read_bytes()[:32])
        expect_failure(args.cli, "inspect-dax", short, error_name="TruncatedFrame")
        malformed += 1
        bad_offset_bytes = bytearray(valid.read_bytes())
        struct.pack_into("<I", bad_offset_bytes, 32, 1)
        bad_offset = temp / "bad-offset.dax"
        bad_offset.write_bytes(bad_offset_bytes)
        expect_failure(args.cli, "inspect-dax", bad_offset, error_name="InvalidDax")
        malformed += 1
        raw_bytes = bytearray(images["raw"].read_bytes())
        frame_count = (len(plain) + FRAME_SIZE - 1) // FRAME_SIZE
        areas_offset = 32 + frame_count * 6
        struct.pack_into("<I", raw_bytes, areas_offset + 4, 0)
        bad_area = temp / "bad-area.dax"
        bad_area.write_bytes(raw_bytes)
        expect_failure(args.cli, "inspect-dax", bad_area, error_name="InvalidDax")
        malformed += 1

        if maxcso is not None:
            image = temp / "maxcso.dax"
            output = temp / "maxcso.vort.iso"
            maxcso_encode(maxcso, source, image)
            run(args.cli, "decode-dax", image, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError("Vort decode mismatch for maxcso DAX")
            external_decode += 1

    print(
        f"self={self_cases} maxcso={maxcso is not None} "
        f"external_encode={external_encode} external_decode={external_decode} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
