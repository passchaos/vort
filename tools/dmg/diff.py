#!/usr/bin/env python3
import argparse
import base64
import hashlib
import random
import shutil
import subprocess
import tempfile
from pathlib import Path


CODECS = ("copy", "adc", "zlib", "bzip2", "lzfse", "xz")
DMG2IMG_CODECS = {"copy", "adc", "zlib", "bzip2"}
PINNED_PARTITION_SIZE = 5_201_920
PINNED_PARTITION_SHA256 = (
    "69a6e7366f3f71e4847a08542b2088ab56ecb61ba0534b22f84d43abf6266a77"
)


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
    rng = random.Random(0x5544_4946)
    first = (b"Apple UDIF compressed block payload 0123456789\n" * 256)[:4096]
    second = rng.randbytes(4096)
    third = bytes(4096)
    return first + second + third


def assert_7zip_extract(seven_zip: Path, dmg: Path, plain: bytes, temp: Path, name: str) -> None:
    output_dir = temp / f"7zip-{name}"
    output_dir.mkdir()
    result = run(
        seven_zip,
        "e",
        "-tDmg",
        "-y",
        "-bso0",
        "-bsp0",
        f"-o{output_dir}",
        dmg,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(
            f"7-Zip rejected {name}: "
            f"{result.stdout.decode(errors='replace')} "
            f"{result.stderr.decode(errors='replace')}"
        )
    files = [path for path in output_dir.rglob("*") if path.is_file()]
    if not any(path.read_bytes() == plain for path in files):
        raise AssertionError(f"7-Zip did not extract the expected partition for {name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--dmg2img", type=Path)
    parser.add_argument("--seven-zip", type=Path)
    args = parser.parse_args()
    dmg2img = args.dmg2img or (
        Path(found) if (found := shutil.which("dmg2img")) else None
    )
    seven_zip = args.seven_zip or (
        Path(found)
        if (found := shutil.which("7zz") or shutil.which("7z"))
        else None
    )
    self_cases = 0
    pinned = 0
    external_writer = 0
    external_decode = 0
    malformed = 0
    plain = payload()
    with tempfile.TemporaryDirectory(prefix="vort-dmg-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.raw"
        source.write_bytes(plain)

        for codec in CODECS:
            dmg = temp / f"vort-{codec}.dmg"
            decoded = temp / f"vort-{codec}.out"
            range_output = temp / f"vort-{codec}.range"
            mode = "always" if codec == "adc" else "fallback"
            run(args.cli, "encode-dmg", source, dmg, codec, 4096, mode)
            summary = run(args.cli, "inspect-dmg", dmg).stdout
            expected_kind = b"type=zero" if codec == "copy" else f"type={codec}".encode()
            if expected_kind not in summary and f"type={codec}".encode() not in summary:
                raise AssertionError(f"missing {codec} chunk in inspect output")
            run(args.cli, "decode-dmg-partition", dmg, decoded, 0, len(plain))
            if decoded.read_bytes() != plain:
                raise AssertionError(f"Vort DMG round trip mismatch for {codec}")
            range_offset = 4096 - 43
            range_len = 4096 + 101
            run(
                args.cli,
                "decode-dmg-range",
                dmg,
                range_output,
                0,
                range_offset,
                range_len,
            )
            if range_output.read_bytes() != plain[range_offset : range_offset + range_len]:
                raise AssertionError(f"Vort DMG range mismatch for {codec}")
            self_cases += 1

            if seven_zip is not None:
                assert_7zip_extract(seven_zip, dmg, plain, temp, codec)
                external_writer += 1
            if dmg2img is not None and codec in DMG2IMG_CODECS:
                reference_out = temp / f"dmg2img-{codec}.raw"
                run(dmg2img, "-s", "-p", 0, dmg, reference_out)
                if reference_out.read_bytes() != plain:
                    raise AssertionError(f"dmg2img decode mismatch for {codec}")
                external_writer += 1
        pinned_dmg = temp / "hdiutil-pinned.dmg"
        pinned_dmg.write_bytes(
            base64.b64decode(
                Path("src/dmg/testdata/hdiutil-hfs-xattrs.dmg.b64").read_text()
            )
        )
        pinned_output = temp / "hdiutil-pinned.raw"
        run(
            args.cli,
            "decode-dmg-partition",
            pinned_dmg,
            pinned_output,
            4,
            PINNED_PARTITION_SIZE,
        )
        if hashlib.sha256(pinned_output.read_bytes()).hexdigest() != PINNED_PARTITION_SHA256:
            raise AssertionError("pinned hdiutil partition digest mismatch")
        pinned += 1
        external_decode += 1
        if seven_zip is not None:
            assert_7zip_extract(
                seven_zip,
                pinned_dmg,
                pinned_output.read_bytes(),
                temp,
                "hdiutil-pinned",
            )
        if dmg2img is not None:
            reference_output = temp / "hdiutil-dmg2img.raw"
            run(dmg2img, "-s", "-p", 4, pinned_dmg, reference_output)
            reference_bytes = reference_output.read_bytes()
            if hashlib.sha256(reference_bytes[:PINNED_PARTITION_SIZE]).hexdigest() != PINNED_PARTITION_SHA256:
                raise AssertionError("dmg2img pinned hdiutil partition mismatch")

        valid = temp / "vort-zlib.dmg"
        short = temp / "short.dmg"
        short.write_bytes(valid.read_bytes()[:64])
        expect_failure(args.cli, "inspect-dmg", short, error_name="TruncatedFrame")
        malformed += 1

        bad_magic = bytearray(valid.read_bytes())
        bad_magic[-512] ^= 1
        bad_magic_path = temp / "bad-magic.dmg"
        bad_magic_path.write_bytes(bad_magic)
        expect_failure(args.cli, "inspect-dmg", bad_magic_path, error_name="InvalidMagic")
        malformed += 1

        bad_crc = bytearray(valid.read_bytes())
        bad_crc[0] ^= 1
        bad_crc_path = temp / "bad-crc.dmg"
        bad_crc_path.write_bytes(bad_crc)
        expect_failure(args.cli, "inspect-dmg", bad_crc_path, error_name="ChecksumMismatch")
        malformed += 1

        expect_failure(
            args.cli,
            "decode-dmg-partition",
            valid,
            temp / "limited.raw",
            0,
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1

        expect_failure(
            args.cli,
            "decode-dmg-range",
            valid,
            temp / "range.raw",
            0,
            len(plain) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1

    print(
        f"self={self_cases} pinned={pinned} dmg2img={dmg2img is not None} "
        f"seven_zip={seven_zip is not None} "
        f"external_writer={external_writer} external_decode={external_decode} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
