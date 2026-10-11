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


PINNED_SINGLE_SHA256 = "cd63bb0cf21cabea437c8e356b30046968ea470035111811e40e94fab256d9d8"
PINNED_SINGLE_RAW_SHA256 = "6a98be9974d949201d398787f433d1c3c529caaf6227a0834d173071b2bac68c"
PINNED_MULTI_RAW_SHA256 = "4f0fee9d6c5f1cef35d545607b13a8fe2af817859e9e7113baf0c3893fb5753a"


def run(*args: object, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def run_input(data: bytes, *args: object) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [str(arg) for arg in args],
        input=data,
        check=True,
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
    rng = random.Random(0x4557_4631)
    return (
        (b"EWF compressed chunk payload 0123456789\n" * 2048)[:32768]
        + rng.randbytes(32768)
        + bytes(32768)
        + (b"EWF final structured chunk\n" * 2048)[:32768]
    )


def read_fixture(path: str) -> bytes:
    text = Path(path).read_text()
    return bz2.decompress(base64.b64decode(text))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--libewf-dir", type=Path)
    args = parser.parse_args()

    def tool(name: str) -> Path | None:
        if args.libewf_dir is not None:
            candidate = args.libewf_dir / name
            return candidate if candidate.is_file() else None
        found = shutil.which(name)
        return Path(found) if found else None

    ewfinfo = tool("ewfinfo")
    ewfverify = tool("ewfverify")
    ewfexport = tool("ewfexport")
    ewfacquirestream = tool("ewfacquirestream")
    libewf = all(
        value is not None
        for value in (ewfinfo, ewfverify, ewfexport, ewfacquirestream)
    )

    plain = payload()
    self_cases = 0
    pinned = 0
    external_encode = 0
    external_decode = 0
    multisegment = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-ewf-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.raw"
        source.write_bytes(plain)
        images: dict[str, Path] = {}
        for compression in ("none", "zlib", "auto"):
            image = temp / f"vort-{compression}.E01"
            output = temp / f"vort-{compression}.raw"
            ranged = temp / f"vort-{compression}.range"
            run(args.cli, "encode-ewf", source, image, compression, 64)
            summary = run(args.cli, "inspect-ewf", image).stdout
            if b"segments=1" not in summary or b"chunks=4" not in summary:
                raise AssertionError(f"Vort EWF inspect mismatch for {compression}")
            run(args.cli, "decode-ewf", image, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError(f"Vort EWF round trip mismatch for {compression}")
            range_offset = 32768 - 31
            range_length = 32768 + 79
            run(
                args.cli,
                "decode-ewf-range",
                image,
                ranged,
                range_offset,
                range_length,
            )
            if ranged.read_bytes() != plain[
                range_offset : range_offset + range_length
            ]:
                raise AssertionError(f"Vort EWF range mismatch for {compression}")
            images[compression] = image
            self_cases += 1

            if libewf:
                run(ewfinfo, image)
                run(ewfverify, "-q", image)
                exported = run(ewfexport, "-u", "-q", "-t", "-", image).stdout
                if exported != plain:
                    raise AssertionError(f"libewf decode of Vort {compression} mismatch")
                external_encode += 1

        single = read_fixture("src/ewf/testdata/libewf-encase6-mixed.E01.bz2.b64")
        if hashlib.sha256(single).hexdigest() != PINNED_SINGLE_SHA256:
            raise AssertionError("pinned libewf single-segment digest mismatch")
        single_path = temp / "libewf-pinned.E01"
        single_output = temp / "libewf-pinned.raw"
        single_path.write_bytes(single)
        run(args.cli, "decode-ewf", single_path, single_output, 32768)
        if hashlib.sha256(single_output.read_bytes()).hexdigest() != PINNED_SINGLE_RAW_SHA256:
            raise AssertionError("Vort decode of pinned libewf image mismatch")
        pinned += 1
        external_decode += 1

        multi_paths: list[Path] = []
        for extension in ("E01", "E02", "E03", "E04"):
            segment = read_fixture(
                f"src/ewf/testdata/libewf-multi-raw.{extension}.bz2.b64"
            )
            path = temp / f"libewf-multi.{extension}"
            path.write_bytes(segment)
            multi_paths.append(path)
        multi_output = temp / "libewf-multi.raw"
        run(
            args.cli,
            "decode-ewf",
            multi_paths[0],
            multi_output,
            3 * 1024 * 1024,
            *multi_paths[1:],
        )
        if hashlib.sha256(multi_output.read_bytes()).hexdigest() != PINNED_MULTI_RAW_SHA256:
            raise AssertionError("Vort decode of pinned libewf segment set mismatch")
        pinned += 1
        external_decode += 1
        multisegment += 1

        valid = images["auto"]
        short = temp / "short.E01"
        short.write_bytes(valid.read_bytes()[:8])
        expect_failure(args.cli, "inspect-ewf", short, error_name="TruncatedFrame")
        malformed += 1

        bad_magic_bytes = bytearray(valid.read_bytes())
        bad_magic_bytes[0] ^= 1
        bad_magic = temp / "bad-magic.E01"
        bad_magic.write_bytes(bad_magic_bytes)
        expect_failure(args.cli, "inspect-ewf", bad_magic, error_name="InvalidMagic")
        malformed += 1

        bad_checksum_bytes = bytearray(valid.read_bytes())
        bad_checksum_bytes[13 + 72] ^= 1
        bad_checksum = temp / "bad-checksum.E01"
        bad_checksum.write_bytes(bad_checksum_bytes)
        expect_failure(
            args.cli,
            "inspect-ewf",
            bad_checksum,
            error_name="ChecksumMismatch",
        )
        malformed += 1

        expect_failure(
            args.cli,
            "decode-ewf",
            valid,
            temp / "limited.raw",
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-ewf-range",
            valid,
            temp / "bad-range.raw",
            len(plain) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1

        if libewf:
            target = temp / "libewf-reference"
            run_input(
                plain,
                ewfacquirestream,
                "-B",
                len(plain),
                "-b",
                64,
                "-c",
                "deflate:fast",
                "-f",
                "encase6",
                "-j",
                0,
                "-q",
                "-t",
                target,
            )
            reference = target.with_suffix(".E01")
            output = temp / "libewf-reference.vort.raw"
            run(args.cli, "decode-ewf", reference, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError("Vort decode of generated libewf image mismatch")
            external_decode += 1

            multi_plain = b"".join(
                bytes([(index * 17 + 3) & 0xFF]) * 32768 for index in range(96)
            )
            multi_target = temp / "libewf-generated-multi"
            run_input(
                multi_plain,
                ewfacquirestream,
                "-B",
                len(multi_plain),
                "-b",
                64,
                "-c",
                "deflate:none",
                "-f",
                "encase6",
                "-j",
                0,
                "-q",
                "-S",
                1048576,
                "-t",
                multi_target,
            )
            generated_segments = sorted(temp.glob("libewf-generated-multi.E*"))
            generated_output = temp / "libewf-generated-multi.vort.raw"
            run(
                args.cli,
                "decode-ewf",
                generated_segments[0],
                generated_output,
                len(multi_plain),
                *generated_segments[1:],
            )
            if generated_output.read_bytes() != multi_plain:
                raise AssertionError("Vort decode of generated libewf segment set mismatch")
            external_decode += 1
            multisegment += 1

    print(
        f"self={self_cases} pinned={pinned} libewf={libewf} "
        f"external_encode={external_encode} external_decode={external_decode} "
        f"multisegment={multisegment} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
