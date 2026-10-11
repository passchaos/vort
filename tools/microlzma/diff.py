#!/usr/bin/env python3
import argparse
import base64
import random
import shutil
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


def build_probe(source: Path, build: Path, output: Path) -> Path:
    run(
        "cc",
        "-O2",
        f"-I{source / 'src/liblzma/api'}",
        "tools/microlzma/xz_probe.c",
        f"-L{build}",
        f"-Wl,-rpath,{build}",
        "-llzma",
        "-o",
        output,
    )
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--xz-source", type=Path)
    parser.add_argument("--xz-build", type=Path)
    parser.add_argument("--xz-probe", type=Path)
    args = parser.parse_args()
    if (args.xz_source is None) != (args.xz_build is None):
        raise AssertionError("both --xz-source and --xz-build are required")

    plain_fixture = Path("src/lzms/testdata/lzms-small.txt").read_bytes()
    encoded_fixture = base64.b64decode(
        Path("src/lzma/testdata/microlzma-small.bin.b64").read_text()
    )
    pinned = 0
    external = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-microlzma-") as temp_text:
        temp = Path(temp_text)
        fixture = temp / "fixture.microlzma"
        output = temp / "fixture.out"
        fixture.write_bytes(encoded_fixture)
        run(
            args.cli,
            "decode-microlzma-file",
            fixture,
            output,
            len(plain_fixture),
            32 * 1024,
        )
        if output.read_bytes() != plain_fixture:
            raise AssertionError("pinned MicroLZMA fixture mismatch")
        pinned += 1

        probe = args.xz_probe
        if probe is None and args.xz_source is not None:
            probe = build_probe(args.xz_source, args.xz_build, temp / "xz-probe")
        if probe is None:
            found = shutil.which("vort-xz-microlzma-probe")
            probe = Path(found) if found else None

        if probe is not None:
            oracle_fixture = temp / "fixture-oracle.out"
            run(
                probe,
                "decode",
                fixture,
                oracle_fixture,
                len(plain_fixture),
                32 * 1024,
            )
            if oracle_fixture.read_bytes() != plain_fixture:
                raise AssertionError("XZ Utils pinned fixture mismatch")

            rng = random.Random(0x4D49_4352_4F)
            cases = (
                ("empty", b"", 4096, 3, 0, 2),
                ("tiny", b"MicroLZMA tiny payload\n", 4096, 3, 0, 2),
                ("repeated", b"MicroLZMA repeated 0123456789\n" * 2000, 32768, 3, 0, 2),
                ("delta", bytes((row + col) & 0xFF for row in range(256) for col in range(64)), 65536, 0, 4, 0),
                ("mixed", b"prefix\n" * 1000 + rng.randbytes(4096) + b"tail\n" * 1000, 131072, 4, 0, 4),
                ("source", Path("src/lzma/decoder.zig").read_bytes(), 1024 * 1024, 3, 0, 2),
            )
            for name, plain, dictionary, lc, lp, pb in cases:
                source = temp / f"{name}.bin"
                encoded = temp / f"{name}.microlzma"
                decoded = temp / f"{name}.out"
                oracle = temp / f"{name}-oracle.out"
                source.write_bytes(plain)
                run(probe, "encode", source, encoded, dictionary, lc, lp, pb)
                run(probe, "decode", encoded, oracle, len(plain), dictionary)
                if oracle.read_bytes() != plain:
                    raise AssertionError(f"XZ Utils round trip mismatch for {name}")
                run(
                    args.cli,
                    "decode-microlzma-file",
                    encoded,
                    decoded,
                    len(plain),
                    dictionary,
                )
                if decoded.read_bytes() != plain:
                    raise AssertionError(f"Vort MicroLZMA mismatch for {name}")
                external += 1

        truncated = temp / "truncated.microlzma"
        truncated.write_bytes(encoded_fixture[:-1])
        expect_failure(
            args.cli,
            "decode-microlzma-file",
            truncated,
            temp / "truncated.out",
            len(plain_fixture),
            32 * 1024,
            error_name="TruncatedFrame",
        )
        malformed += 1
        bad_properties = temp / "bad-properties.microlzma"
        bad = bytearray(encoded_fixture)
        bad[0] = (~0x6F) & 0xFF
        bad_properties.write_bytes(bad)
        expect_failure(
            args.cli,
            "decode-microlzma-file",
            bad_properties,
            temp / "bad-properties.out",
            len(plain_fixture),
            32 * 1024,
            error_name="InvalidLzmaHeader",
        )
        malformed += 1
        trailing = temp / "trailing.microlzma"
        trailing.write_bytes(encoded_fixture + b"\0")
        expect_failure(
            args.cli,
            "decode-microlzma-file",
            trailing,
            temp / "trailing.out",
            len(plain_fixture),
            32 * 1024,
            error_name="TrailingData",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-microlzma-file",
            fixture,
            temp / "short-output.out",
            len(plain_fixture) - 1,
            32 * 1024,
            error_name="SizeMismatch",
        )
        malformed += 1

    print(
        f"pinned={pinned} xz={probe is not None} "
        f"external={external} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
