#!/usr/bin/env python3
import argparse
import base64
import hashlib
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


def write_tree(root: Path) -> dict[str, bytes]:
    (root / "nested").mkdir(parents=True)
    rng = random.Random(0x5749_4D)
    payloads = {
        "nested/config.txt": b"WIM nested configuration\n",
        "large.bin": (b"WIM multi-chunk payload 0123456789\n" * 5000)[:150_000],
        "random.bin": rng.randbytes(70_000),
    }
    for name, data in payloads.items():
        (root / name).write_bytes(data)
    return payloads


def verify_vort(
    cli: Path,
    image: Path,
    compression: str,
    payloads: dict[str, bytes],
    temp: Path,
) -> None:
    listing = run(cli, "list-wim-file", image).stdout
    if f"compression={compression}".encode() not in listing:
        raise AssertionError(f"WIM compression mismatch: {listing!r}")
    for name, expected in payloads.items():
        digest = hashlib.sha1(expected).hexdigest()
        if digest.encode() not in listing:
            raise AssertionError(f"WIM lookup missing {name}/{digest}")
        output = temp / f"{compression}-{name.replace('/', '-')}.out"
        run(cli, "extract-wim-resource", image, digest, output, len(expected))
        if output.read_bytes() != expected:
            raise AssertionError(f"WIM extraction mismatch for {compression}/{name}")
    xml = temp / f"{compression}.xml"
    run(cli, "extract-wim-xml", image, xml, 16 * 1024 * 1024)
    if b"<WIM>" not in xml.read_bytes().replace(b"\x00", b""):
        raise AssertionError(f"WIM XML mismatch for {compression}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--wimlib-imagex", type=Path)
    args = parser.parse_args()
    wimlib = args.wimlib_imagex or (
        Path(found) if (found := shutil.which("wimlib-imagex")) else None
    )

    fixture_cases = 0
    codec_cases = 0
    solid_cases = 0
    split_cases = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-wim-") as temp_text:
        temp = Path(temp_text)
        fixture = temp / "fixture.wim"
        fixture.write_bytes(
            base64.b64decode(Path("src/wim/testdata/xpress-small.wim.b64").read_text())
        )
        fixture_out = temp / "fixture.out"
        fixture_hash = "a541b150d52c83c6e19004c5239d228ccdad70ba"
        run(args.cli, "extract-wim-resource", fixture, fixture_hash, fixture_out, 1024)
        if fixture_out.read_bytes() != b"hello WIM XPRESS payload\n":
            raise AssertionError("checked-in WIM fixture mismatch")
        fixture_cases += 1

        source = temp / "tree"
        payloads = write_tree(source)
        if wimlib is not None:
            rng = random.Random(0x5357_4D)
            for cli_name, expected_name in (
                ("none", "none"),
                ("XPRESS", "xpress"),
                ("LZX", "lzx"),
            ):
                image = temp / f"{expected_name}.wim"
                run(
                    wimlib,
                    "capture",
                    source,
                    image,
                    "test",
                    f"--compress={cli_name}",
                    "--no-acls",
                )
                run(wimlib, "verify", image)
                verify_vort(args.cli, image, expected_name, payloads, temp)
                codec_cases += 1

            solid = temp / "solid.esd"
            run(
                wimlib,
                "capture",
                source,
                solid,
                "test",
                "--compress=LZMS",
                "--solid",
                "--no-acls",
            )
            solid_listing = run(args.cli, "list-wim-file", solid).stdout
            if b"wim_version=0xe00 compression=lzms" not in solid_listing:
                raise AssertionError("solid ESD header mismatch")
            solid_cases += 1

            split_source = temp / "split-tree"
            split_source.mkdir()
            split_payload = rng.randbytes(1_300_000)
            (split_source / "large.bin").write_bytes(split_payload)
            split_input = temp / "split-input.wim"
            run(
                wimlib,
                "capture",
                split_source,
                split_input,
                "split",
                "--compress=XPRESS",
                "--no-acls",
            )
            first_part = temp / "split.swm"
            run(wimlib, "split", split_input, first_part, 1)
            second_part = temp / "split2.swm"
            first_listing = run(args.cli, "list-wim-file", first_part).stdout
            second_listing = run(args.cli, "list-wim-file", second_part).stdout
            if b"part=1/2" not in first_listing or b"part=2/2" not in second_listing:
                raise AssertionError("split SWM header mismatch")
            split_cases += 2

        original = fixture.read_bytes()
        malformed_cases = []
        bad_magic = bytearray(original)
        bad_magic[0:8] = b"not-wim!"
        malformed_cases.append(("bad-magic", bytes(bad_magic), "InvalidMagic"))
        bad_header = bytearray(original)
        bad_header[8:12] = struct.pack("<I", 96)
        malformed_cases.append(("bad-header", bytes(bad_header), "InvalidWim"))
        bad_version = bytearray(original)
        bad_version[12:16] = struct.pack("<I", 0xDEAD)
        malformed_cases.append(
            ("bad-version", bytes(bad_version), "UnsupportedWimVersion")
        )
        bad_chunk = bytearray(original)
        bad_chunk[20:24] = struct.pack("<I", 12345)
        malformed_cases.append(("bad-chunk", bytes(bad_chunk), "InvalidWim"))
        for name, data, error_name in malformed_cases:
            path = temp / f"{name}.wim"
            path.write_bytes(data)
            expect_failure(args.cli, "list-wim-file", path, error_name=error_name)
            malformed += 1
        expect_failure(
            args.cli,
            "extract-wim-resource",
            fixture,
            fixture_hash,
            temp / "limited.out",
            24,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "extract-wim-resource",
            fixture,
            "00" * 20,
            temp / "missing.out",
            1024,
            error_name="WimResourceNotFound",
        )
        malformed += 1

    print(
        f"fixture={fixture_cases} wimlib={wimlib is not None} "
        f"codecs={codec_cases} solid={solid_cases} split={split_cases} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
