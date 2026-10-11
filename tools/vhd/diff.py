#!/usr/bin/env python3
import argparse
import base64
import bz2
import hashlib
import random
import shutil
import subprocess
import tempfile
from pathlib import Path


PINNED_IMAGE_SHA256 = "855483113cc44d4b13971a2e7441b10f5d93e73c87d110a4a74b0f7147b46ee1"
PINNED_RAW_SHA256 = "0dcde7c94a6d08ba49304eb929e45dbf9460e018db91060efd692cd516750824"
SECTOR_SIZE = 512
BLOCK_SIZE = 4096


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
    rng = random.Random(0x5648_4431)
    first = (b"VHD dynamic block payload\n" * 256)[:BLOCK_SIZE]
    zeros = bytes(BLOCK_SIZE)
    random_block = rng.randbytes(BLOCK_SIZE)
    structured = bytes((index * 13 + index // 17) & 0xFF for index in range(BLOCK_SIZE))
    return first + zeros + random_block + structured


def read_fixture() -> bytes:
    text = Path("src/vhd/testdata/qemu-9.2-dynamic.vhd.bz2.b64").read_text()
    image = bz2.decompress(base64.b64decode(text))
    if hashlib.sha256(image).hexdigest() != PINNED_IMAGE_SHA256:
        raise AssertionError("pinned QEMU VHD digest mismatch")
    return image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--qemu-img", type=Path)
    parser.add_argument("--seven-zip", type=Path)
    args = parser.parse_args()
    qemu_img = args.qemu_img or (
        Path(found) if (found := shutil.which("qemu-img")) else None
    )
    seven_zip = args.seven_zip or (
        Path(found) if (found := shutil.which("7zz") or shutil.which("7z")) else None
    )

    plain = payload()
    self_cases = 0
    pinned = 0
    external_encode = 0
    external_decode = 0
    parent_cases = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-vhd-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.raw"
        source.write_bytes(plain)
        images: dict[str, Path] = {}
        for disk_type in ("fixed", "dynamic"):
            image = temp / f"vort-{disk_type}.vhd"
            output = temp / f"vort-{disk_type}.raw"
            ranged = temp / f"vort-{disk_type}.range"
            run(args.cli, "encode-vhd", source, image, disk_type, BLOCK_SIZE)
            summary = run(args.cli, "inspect-vhd", image).stdout
            if f"type={disk_type}".encode() not in summary:
                raise AssertionError(f"Vort VHD inspect mismatch for {disk_type}")
            run(args.cli, "decode-vhd", image, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError(f"Vort VHD round trip mismatch for {disk_type}")
            range_offset = BLOCK_SIZE - 37
            range_length = BLOCK_SIZE + 91
            run(
                args.cli,
                "decode-vhd-range",
                image,
                ranged,
                range_offset,
                range_length,
            )
            if ranged.read_bytes() != plain[range_offset : range_offset + range_length]:
                raise AssertionError(f"Vort VHD range mismatch for {disk_type}")
            images[disk_type] = image
            self_cases += 1

            if qemu_img is not None:
                run(qemu_img, "info", "-f", "vpc", image)
                qemu_raw = temp / f"vort-{disk_type}.qemu.raw"
                run(qemu_img, "convert", "-f", "vpc", "-O", "raw", image, qemu_raw)
                if qemu_raw.read_bytes() != plain:
                    raise AssertionError(f"QEMU decode of Vort {disk_type} VHD mismatch")
                external_encode += 1
            if seven_zip is not None:
                extracted = run(seven_zip, "e", "-so", "-tVHD", image).stdout
                if extracted != plain:
                    raise AssertionError(f"7-Zip decode of Vort {disk_type} VHD mismatch")
                external_encode += 1

        child_plain = bytearray(plain)
        child_plain[BLOCK_SIZE + 512 : BLOCK_SIZE + 1024] = b"P" * 512
        child_source = temp / "child.raw"
        child_image = temp / "child.vhd"
        child_output = temp / "child.vort.raw"
        child_source.write_bytes(child_plain)
        run(
            args.cli,
            "encode-vhd",
            child_source,
            child_image,
            "differencing",
            BLOCK_SIZE,
            images["dynamic"],
        )
        expect_failure(
            args.cli,
            "decode-vhd",
            child_image,
            temp / "missing-parent.raw",
            len(child_plain),
            error_name="MissingVhdParent",
        )
        malformed += 1
        run(
            args.cli,
            "decode-vhd",
            child_image,
            child_output,
            len(child_plain),
            images["dynamic"],
        )
        if child_output.read_bytes() != child_plain:
            raise AssertionError("Vort differencing VHD round trip mismatch")
        parent_cases += 1

        fixture = read_fixture()
        fixture_path = temp / "qemu-pinned.vhd"
        fixture_output = temp / "qemu-pinned.raw"
        fixture_path.write_bytes(fixture)
        run(args.cli, "decode-vhd", fixture_path, fixture_output, 32768)
        if hashlib.sha256(fixture_output.read_bytes()).hexdigest() != PINNED_RAW_SHA256:
            raise AssertionError("Vort decode of pinned QEMU VHD mismatch")
        pinned += 1
        external_decode += 1

        valid = images["dynamic"]
        short = temp / "short.vhd"
        short.write_bytes(valid.read_bytes()[:511])
        expect_failure(args.cli, "inspect-vhd", short, error_name="TruncatedFrame")
        malformed += 1

        bad_footer_bytes = bytearray(valid.read_bytes())
        bad_footer_bytes[-1] ^= 1
        bad_footer = temp / "bad-footer.vhd"
        bad_footer.write_bytes(bad_footer_bytes)
        expect_failure(args.cli, "inspect-vhd", bad_footer, error_name="ChecksumMismatch")
        malformed += 1

        bad_header_bytes = bytearray(valid.read_bytes())
        bad_header_bytes[512 + 100] ^= 1
        bad_header = temp / "bad-header.vhd"
        bad_header.write_bytes(bad_header_bytes)
        expect_failure(args.cli, "inspect-vhd", bad_header, error_name="ChecksumMismatch")
        malformed += 1

        expect_failure(
            args.cli,
            "decode-vhd",
            valid,
            temp / "limited.raw",
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-vhd-range",
            valid,
            temp / "bad-range.raw",
            len(plain) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1

        if qemu_img is not None:
            for disk_type in ("fixed", "dynamic"):
                image = temp / f"qemu-{disk_type}.vhd"
                output = temp / f"qemu-{disk_type}.vort.raw"
                run(
                    qemu_img,
                    "convert",
                    "-f",
                    "raw",
                    "-O",
                    "vpc",
                    "-o",
                    f"subformat={disk_type},force_size=on",
                    source,
                    image,
                )
                run(args.cli, "decode-vhd", image, output, len(plain))
                if output.read_bytes() != plain:
                    raise AssertionError(f"Vort decode of QEMU {disk_type} VHD mismatch")
                external_decode += 1

    print(
        f"self={self_cases} pinned={pinned} qemu_img={qemu_img is not None} "
        f"seven_zip={seven_zip is not None} external_encode={external_encode} "
        f"external_decode={external_decode} parent={parent_cases} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
