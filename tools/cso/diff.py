#!/usr/bin/env python3
import argparse
import random
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


BLOCK_SIZE = 2048


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
    rng = random.Random(0x43534F)
    repetitive = (b"PSP compressed-image differential payload\n" * 80)[:BLOCK_SIZE]
    random_block = rng.randbytes(BLOCK_SIZE)
    zeros = bytes(BLOCK_SIZE)
    structured = bytes((index * 17 + index // 19) & 0xFF for index in range(BLOCK_SIZE))
    return repetitive + random_block + zeros + structured + repetitive + random_block


def maxcso_encode(
    executable: Path,
    source: Path,
    output: Path,
    image_format: str,
    block_size: int = BLOCK_SIZE,
) -> None:
    run(
        executable,
        "--quiet",
        "--fast",
        f"--format={image_format}",
        f"--block={block_size}",
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
    parser.add_argument("--seven-zip", type=Path)
    args = parser.parse_args()
    maxcso = args.maxcso or (
        Path(found) if (found := shutil.which("maxcso")) else None
    )
    seven_zip = args.seven_zip or (
        Path(found) if (found := shutil.which("7zz") or shutil.which("7z")) else None
    )

    plain = payload()
    self_cases = 0
    external_encode = 0
    external_decode = 0
    seven_zip_decode = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-cso-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.iso"
        source.write_bytes(plain)
        images: dict[str, Path] = {}
        cases = (
            ("cso1", "raw"),
            ("cso1", "auto"),
            ("cso2", "deflate"),
            ("cso2", "lz4"),
            ("cso2", "auto"),
            ("zso", "raw"),
            ("zso", "auto"),
        )
        for image_format, compression in cases:
            suffix = "zso" if image_format == "zso" else "cso"
            image = temp / f"vort-{image_format}-{compression}.{suffix}"
            output = temp / f"vort-{image_format}-{compression}.iso"
            ranged = temp / f"vort-{image_format}-{compression}.range"
            run(
                args.cli,
                "encode-cso",
                source,
                image,
                image_format,
                compression,
                BLOCK_SIZE,
                6,
            )
            summary = run(args.cli, "inspect-cso", image).stdout
            if f"format={image_format}".encode() not in summary or b"blocks=6" not in summary:
                raise AssertionError(f"Vort inspect mismatch for {image_format}/{compression}")
            run(args.cli, "decode-cso", image, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError(f"Vort round trip mismatch for {image_format}/{compression}")
            range_offset = BLOCK_SIZE - 37
            range_length = 2 * BLOCK_SIZE + 91
            run(
                args.cli,
                "decode-cso-range",
                image,
                ranged,
                range_offset,
                range_length,
            )
            if ranged.read_bytes() != plain[range_offset : range_offset + range_length]:
                raise AssertionError(f"Vort range mismatch for {image_format}/{compression}")
            images[f"{image_format}-{compression}"] = image
            self_cases += 1

            if maxcso is not None:
                external = temp / f"vort-{image_format}-{compression}.maxcso.iso"
                maxcso_decode(maxcso, image, external)
                if external.read_bytes() != plain:
                    raise AssertionError(
                        f"maxcso decode mismatch for {image_format}/{compression}"
                    )
                external_encode += 1
            if seven_zip is not None:
                probe = run(seven_zip, "e", "-so", image, check=False)
                if probe.returncode == 0 and probe.stdout == plain:
                    seven_zip_decode += 1

        aligned = temp / "vort-aligned.cso"
        aligned_output = temp / "vort-aligned.iso"
        run(args.cli, "encode-cso", source, aligned, "cso1", "auto", BLOCK_SIZE, 6, 3)
        run(args.cli, "decode-cso", aligned, aligned_output, len(plain))
        if aligned_output.read_bytes() != plain:
            raise AssertionError("Vort shifted-index round trip mismatch")
        self_cases += 1
        if maxcso is not None:
            maxcso_output = temp / "vort-aligned.maxcso.iso"
            maxcso_decode(maxcso, aligned, maxcso_output)
            if maxcso_output.read_bytes() != plain:
                raise AssertionError("maxcso shifted-index decode mismatch")
            external_encode += 1

        valid = images["cso1-auto"]
        expect_failure(
            args.cli,
            "decode-cso",
            valid,
            temp / "limited.iso",
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-cso-range",
            valid,
            temp / "bad-range.iso",
            len(plain) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1
        short = temp / "short.cso"
        short.write_bytes(valid.read_bytes()[:24])
        expect_failure(args.cli, "inspect-cso", short, error_name="TruncatedFrame")
        malformed += 1
        descending_bytes = bytearray(valid.read_bytes())
        struct.pack_into("<I", descending_bytes, 28, 1)
        descending = temp / "descending.cso"
        descending.write_bytes(descending_bytes)
        expect_failure(args.cli, "inspect-cso", descending, error_name="InvalidCso")
        malformed += 1

        if maxcso is not None:
            for image_format in ("cso1", "cso2", "zso"):
                suffix = "zso" if image_format == "zso" else "cso"
                image = temp / f"maxcso-{image_format}.{suffix}"
                output = temp / f"maxcso-{image_format}.vort.iso"
                maxcso_encode(maxcso, source, image, image_format)
                run(args.cli, "decode-cso", image, output, len(plain))
                if output.read_bytes() != plain:
                    raise AssertionError(f"Vort decode mismatch for maxcso {image_format}")
                external_decode += 1

    print(
        f"self={self_cases} maxcso={maxcso is not None} "
        f"seven_zip={seven_zip is not None} seven_zip_decode={seven_zip_decode} "
        f"external_encode={external_encode} external_decode={external_decode} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
