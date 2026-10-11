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


SECTOR_SIZE = 512
GRAIN_SIZE = 65536
PINNED_BZIP2_SHA256 = "924c05b1a1cf61cfd33722349dcfe59eb65cd702f363e8e114362954edba5d34"
PINNED_VMDK_SHA256 = "0b67f248809938335a6f9375a8a76b3079f7c7e355df2837d5e05c9b45aaad5c"


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
    rng = random.Random(0x564D_444B)
    first = (b"VMDK compressed grain payload 0123456789\n" * 2048)[:GRAIN_SIZE]
    second = rng.randbytes(GRAIN_SIZE)
    third = bytes(GRAIN_SIZE)
    fourth = bytearray(GRAIN_SIZE)
    fourth[2048:6144] = (b"VMDK sparse tail grain\n" * 256)[:4096]
    return first + second + third + bytes(fourth)


def qemu_convert_to_raw(qemu_img: Path, image: Path, output: Path) -> bytes:
    run(qemu_img, "check", "-f", "vmdk", image)
    run(qemu_img, "convert", "-f", "vmdk", "-O", "raw", image, output)
    return output.read_bytes()


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
        Path(found)
        if (found := shutil.which("7zz") or shutil.which("7z"))
        else None
    )

    plain = payload()
    self_cases = 0
    pinned = 0
    external_encode = 0
    external_decode = 0
    layouts = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-vmdk-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.raw"
        source.write_bytes(plain)
        images: dict[str, Path] = {}
        for compression in ("none", "zlib"):
            image = temp / f"vort-{compression}.vmdk"
            output = temp / f"vort-{compression}.raw"
            ranged = temp / f"vort-{compression}.range"
            run(args.cli, "encode-vmdk", source, image, compression, 128)
            summary = run(args.cli, "inspect-vmdk", image).stdout
            expected = f"compressed={str(compression == 'zlib').lower()}".encode()
            if expected not in summary:
                raise AssertionError(f"wrong VMDK inspect compression for {compression}")
            if compression == "zlib" and b"footer=true" not in summary:
                raise AssertionError("Vort streamOptimized writer omitted footer")
            run(args.cli, "decode-vmdk", image, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError(f"Vort VMDK round trip mismatch for {compression}")
            range_offset = GRAIN_SIZE - 37
            range_length = GRAIN_SIZE + 91
            run(
                args.cli,
                "decode-vmdk-range",
                image,
                ranged,
                range_offset,
                range_length,
            )
            if ranged.read_bytes() != plain[
                range_offset : range_offset + range_length
            ]:
                raise AssertionError(f"Vort VMDK range mismatch for {compression}")
            images[compression] = image
            self_cases += 1

            if qemu_img is not None:
                qemu_output = temp / f"vort-{compression}.qemu.raw"
                if qemu_convert_to_raw(qemu_img, image, qemu_output) != plain:
                    raise AssertionError(f"QEMU decode of Vort {compression} mismatch")
                external_encode += 1
            if seven_zip is not None:
                extracted = run(seven_zip, "e", "-so", "-tVMDK", image).stdout
                if extracted != plain:
                    raise AssertionError(f"7-Zip decode of Vort {compression} mismatch")
                external_encode += 1

        fixture_text = Path(
            "src/vmdk/testdata/qemu-iotest-version3.vmdk.bz2.b64"
        ).read_text()
        fixture_bz2 = base64.b64decode(fixture_text)
        if hashlib.sha256(fixture_bz2).hexdigest() != PINNED_BZIP2_SHA256:
            raise AssertionError("pinned QEMU VMDK compressed fixture digest mismatch")
        fixture = bz2.decompress(fixture_bz2)
        if hashlib.sha256(fixture).hexdigest() != PINNED_VMDK_SHA256:
            raise AssertionError("pinned QEMU VMDK image digest mismatch")
        fixture_path = temp / "qemu-version3.vmdk"
        fixture_path.write_bytes(fixture)
        summary = run(args.cli, "inspect-vmdk", fixture_path).stdout
        if b"compressed=true" not in summary or b"footer=true" not in summary:
            raise AssertionError("pinned QEMU fixture metadata mismatch")
        for index in (0, 1, 9, 37, 99):
            offset = index * 64 * 1024 * 10 + index * 512
            output = temp / f"qemu-version3-{index}.raw"
            run(args.cli, "decode-vmdk-range", fixture_path, output, offset, 512)
            if output.read_bytes() != bytes([index % 10 + 0x30]) * 512:
                raise AssertionError(f"pinned QEMU VMDK range mismatch at {index}")
        pinned += 1
        external_decode += 1

        valid = images["zlib"]
        short = temp / "short.vmdk"
        short.write_bytes(valid.read_bytes()[:64])
        expect_failure(args.cli, "inspect-vmdk", short, error_name="TruncatedFrame")
        malformed += 1

        bad_magic_bytes = bytearray(valid.read_bytes())
        bad_magic_bytes[0] ^= 1
        bad_magic = temp / "bad-magic.vmdk"
        bad_magic.write_bytes(bad_magic_bytes)
        expect_failure(args.cli, "inspect-vmdk", bad_magic, error_name="InvalidMagic")
        malformed += 1

        bad_flags_bytes = bytearray(valid.read_bytes())
        flags = struct.unpack_from("<I", bad_flags_bytes, 8)[0]
        struct.pack_into("<I", bad_flags_bytes, 8, flags & ~(1 << 17))
        bad_flags = temp / "bad-flags.vmdk"
        bad_flags.write_bytes(bad_flags_bytes)
        expect_failure(args.cli, "inspect-vmdk", bad_flags, error_name="InvalidVmdk")
        malformed += 1

        bad_footer_bytes = bytearray(valid.read_bytes())
        struct.pack_into("<I", bad_footer_bytes, len(bad_footer_bytes) - 512 + 12, 3)
        bad_footer = temp / "bad-footer.vmdk"
        bad_footer.write_bytes(bad_footer_bytes)
        expect_failure(args.cli, "inspect-vmdk", bad_footer, error_name="InvalidVmdk")
        malformed += 1

        expect_failure(
            args.cli,
            "decode-vmdk",
            valid,
            temp / "limited.raw",
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-vmdk-range",
            valid,
            temp / "bad-range.raw",
            len(plain) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1

        if qemu_img is not None:
            qemu_sparse = temp / "qemu-sparse.vmdk"
            qemu_stream = temp / "qemu-stream.vmdk"
            run(
                qemu_img,
                "convert",
                "-f",
                "raw",
                "-O",
                "vmdk",
                "-o",
                "subformat=monolithicSparse,zeroed_grain=on",
                source,
                qemu_sparse,
            )
            run(
                qemu_img,
                "convert",
                "-f",
                "raw",
                "-O",
                "vmdk",
                "-c",
                "-o",
                "subformat=streamOptimized",
                source,
                qemu_stream,
            )
            for name, image in (("sparse", qemu_sparse), ("stream", qemu_stream)):
                output = temp / f"qemu-{name}.vort.raw"
                run(args.cli, "decode-vmdk", image, output, len(plain))
                if output.read_bytes() != plain:
                    raise AssertionError(f"Vort decode of QEMU {name} mismatch")
                external_decode += 1
            layouts += 2

            overlay = temp / "qemu-overlay.vmdk"
            run(
                qemu_img,
                "create",
                "-f",
                "vmdk",
                "-F",
                "vmdk",
                "-b",
                images["none"],
                "-o",
                "subformat=monolithicSparse,zeroed_grain=on",
                overlay,
                len(plain),
            )
            expect_failure(
                args.cli,
                "decode-vmdk",
                overlay,
                temp / "missing-backing.raw",
                len(plain),
                error_name="MissingVmdkBackingFile",
            )
            malformed += 1
            overlay_output = temp / "qemu-overlay.vort.raw"
            run(
                args.cli,
                "decode-vmdk",
                overlay,
                overlay_output,
                len(plain),
                source,
            )
            if overlay_output.read_bytes() != plain:
                raise AssertionError("Vort decode of QEMU VMDK backing chain mismatch")
            external_decode += 1
            layouts += 1

    print(
        f"self={self_cases} pinned={pinned} qemu_img={qemu_img is not None} "
        f"seven_zip={seven_zip is not None} external_encode={external_encode} "
        f"external_decode={external_decode} layouts={layouts} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
