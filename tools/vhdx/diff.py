#!/usr/bin/env python3
import argparse
import base64
import bz2
import hashlib
import random
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


MIB = 1024 * 1024
PINNED_IMAGE_SHA256 = "e80721dc35569be346e1f97a5a8d525b348e9f0d775359faac9e5236d3786149"
PINNED_RAW_SHA256 = "0dcde7c94a6d08ba49304eb929e45dbf9460e018db91060efd692cd516750824"


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
    rng = random.Random(0x5648_4458)
    structured = (b"VHDX payload block 0123456789\n" * 40000)[:MIB]
    return structured + bytes(MIB) + rng.randbytes(MIB)


def read_fixture() -> bytes:
    text = Path("src/vhdx/testdata/qemu-9.2-dynamic.vhdx.bz2.b64").read_text()
    image = bz2.decompress(base64.b64decode(text))
    if hashlib.sha256(image).hexdigest() != PINNED_IMAGE_SHA256:
        raise AssertionError("pinned QEMU VHDX digest mismatch")
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
    with tempfile.TemporaryDirectory(prefix="vort-vhdx-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.raw"
        source.write_bytes(plain)
        images: dict[str, Path] = {}
        for image_type in ("dynamic", "fixed"):
            image = temp / f"vort-{image_type}.vhdx"
            output = temp / f"vort-{image_type}.raw"
            ranged = temp / f"vort-{image_type}.range"
            run(args.cli, "encode-vhdx", source, image, image_type, MIB)
            summary = run(args.cli, "inspect-vhdx", image).stdout
            expected_fixed = f"fixed={str(image_type == 'fixed').lower()}".encode()
            if expected_fixed not in summary or b"block_bytes=1048576" not in summary:
                raise AssertionError(f"Vort VHDX inspect mismatch for {image_type}")
            run(args.cli, "decode-vhdx", image, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError(f"Vort VHDX round trip mismatch for {image_type}")
            range_offset = MIB - 37
            range_length = MIB + 91
            run(
                args.cli,
                "decode-vhdx-range",
                image,
                ranged,
                range_offset,
                range_length,
            )
            if ranged.read_bytes() != plain[range_offset : range_offset + range_length]:
                raise AssertionError(f"Vort VHDX range mismatch for {image_type}")
            images[image_type] = image
            self_cases += 1

            if qemu_img is not None:
                run(qemu_img, "info", "-f", "vhdx", image)
                run(qemu_img, "check", "-f", "vhdx", image)
                qemu_raw = temp / f"vort-{image_type}.qemu.raw"
                run(qemu_img, "convert", "-f", "vhdx", "-O", "raw", image, qemu_raw)
                if qemu_raw.read_bytes() != plain:
                    raise AssertionError(f"QEMU decode of Vort {image_type} VHDX mismatch")
                external_encode += 1
            if seven_zip is not None:
                extracted = run(seven_zip, "e", "-so", "-tVHDX", image).stdout
                if extracted != plain:
                    raise AssertionError(f"7-Zip decode of Vort {image_type} VHDX mismatch")
                external_encode += 1

        parent_path = temp / "parent.vhdx"
        parent_path.write_bytes(images["dynamic"].read_bytes())
        child_plain = bytearray(plain)
        child_plain[3 * 512 : 4 * 512] = bytes(512)
        child_plain[2 * MIB : 3 * MIB] = bytes(
            byte ^ 0xFF for byte in child_plain[2 * MIB : 3 * MIB]
        )
        child_source = temp / "child.raw"
        child_image = temp / "child.vhdx"
        child_output = temp / "child.vort.raw"
        child_source.write_bytes(child_plain)
        run(
            args.cli,
            "encode-vhdx",
            child_source,
            child_image,
            "differencing",
            MIB,
            parent_path,
        )
        child_summary = run(args.cli, "inspect-vhdx", child_image, parent_path).stdout
        if b"parent=true" not in child_summary:
            raise AssertionError("Vort differencing VHDX metadata mismatch")
        expect_failure(
            args.cli,
            "decode-vhdx",
            child_image,
            temp / "missing-parent.raw",
            len(child_plain),
            error_name="MissingVhdxParent",
        )
        malformed += 1
        run(
            args.cli,
            "decode-vhdx",
            child_image,
            child_output,
            len(child_plain),
            parent_path,
        )
        if child_output.read_bytes() != child_plain:
            raise AssertionError("Vort differencing VHDX round trip mismatch")
        parent_cases += 1
        if seven_zip is not None:
            extracted = run(seven_zip, "e", "-so", "-tVHDX", child_image).stdout
            if extracted != child_plain:
                raise AssertionError("7-Zip decode of Vort differencing VHDX mismatch")
            external_encode += 1

        fixture = read_fixture()
        fixture_path = temp / "qemu-pinned.vhdx"
        fixture_output = temp / "qemu-pinned.raw"
        fixture_path.write_bytes(fixture)
        run(args.cli, "decode-vhdx", fixture_path, fixture_output, 32768)
        if hashlib.sha256(fixture_output.read_bytes()).hexdigest() != PINNED_RAW_SHA256:
            raise AssertionError("Vort decode of pinned QEMU VHDX mismatch")
        pinned += 1
        external_decode += 1

        valid = images["dynamic"]
        short = temp / "short.vhdx"
        short.write_bytes(valid.read_bytes()[:512])
        expect_failure(args.cli, "inspect-vhdx", short, error_name="InvalidMagic")
        malformed += 1

        bad_headers_bytes = bytearray(valid.read_bytes())
        bad_headers_bytes[64 * 1024 + 100] ^= 1
        bad_headers_bytes[128 * 1024 + 100] ^= 1
        bad_headers = temp / "bad-headers.vhdx"
        bad_headers.write_bytes(bad_headers_bytes)
        expect_failure(args.cli, "inspect-vhdx", bad_headers, error_name="InvalidVhdx")
        malformed += 1

        bad_regions_bytes = bytearray(valid.read_bytes())
        bad_regions_bytes[192 * 1024 + 100] ^= 1
        bad_regions_bytes[256 * 1024 + 100] ^= 1
        bad_regions = temp / "bad-regions.vhdx"
        bad_regions.write_bytes(bad_regions_bytes)
        expect_failure(args.cli, "inspect-vhdx", bad_regions, error_name="InvalidVhdx")
        malformed += 1

        bad_bat_bytes = bytearray(valid.read_bytes())
        bat_offset = 2 * MIB
        struct.pack_into("<Q", bad_bat_bytes, bat_offset, MIB | 6)
        bad_bat = temp / "bad-bat.vhdx"
        bad_bat.write_bytes(bad_bat_bytes)
        expect_failure(args.cli, "inspect-vhdx", bad_bat, error_name="TruncatedFrame")
        malformed += 1

        expect_failure(
            args.cli,
            "decode-vhdx",
            valid,
            temp / "limited.raw",
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-vhdx-range",
            valid,
            temp / "bad-range.raw",
            len(plain) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1

        if qemu_img is not None:
            for image_type in ("dynamic", "fixed"):
                image = temp / f"qemu-{image_type}.vhdx"
                output = temp / f"qemu-{image_type}.vort.raw"
                run(
                    qemu_img,
                    "convert",
                    "-f",
                    "raw",
                    "-O",
                    "vhdx",
                    "-o",
                    f"subformat={image_type},block_size={MIB}",
                    source,
                    image,
                )
                run(args.cli, "decode-vhdx", image, output, len(plain))
                if output.read_bytes() != plain:
                    raise AssertionError(f"Vort decode of QEMU {image_type} VHDX mismatch")
                external_decode += 1

    print(
        f"self={self_cases} pinned={pinned} qemu_img={qemu_img is not None} "
        f"seven_zip={seven_zip is not None} external_encode={external_encode} "
        f"external_decode={external_decode} parent={parent_cases} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
