#!/usr/bin/env python3
import argparse
import base64
import random
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path
from cli_match_diff import verify as verify_matching_cli


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


def build_probe(wimlib_dir: Path, output: Path) -> Path:
    library_dir = wimlib_dir / ".libs"
    run(
        "cc",
        "-O2",
        f"-I{wimlib_dir / 'include'}",
        "tools/lzms/wimlib_probe.c",
        f"-L{library_dir}",
        f"-Wl,-rpath,{library_dir}",
        "-lwim",
        "-o",
        output,
    )
    return output


def x86_payload() -> bytes:
    data = bytearray(b"MZ" + b"\0" * 30)
    target = 8192
    for _ in range(3000):
        position = len(data)
        data.append(0xE8)
        data.extend(struct.pack("<i", target - position))
        data.extend(b"\x48\x8d\x05")
        operand_position = len(data)
        data.extend(struct.pack("<i", target - (operand_position - 3)))
        data.extend(b"\x90" * 5)
    return bytes(data)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--wimlib-dir", type=Path)
    parser.add_argument("--wimlib-probe", type=Path)
    args = parser.parse_args()

    pinned_plain = Path("src/lzms/testdata/lzms-small.txt").read_bytes()
    pinned_encoded = base64.b64decode(
        Path("src/lzms/testdata/lzms-small.bin.b64").read_text()
    )
    pinned_cases = 0
    external_cases = 0
    vort_encode_cases = 0
    malformed = 0
    matching_cli = 0
    matching_cli_failures = 0
    with tempfile.TemporaryDirectory(prefix="vort-lzms-") as temp_text:
        temp = Path(temp_text)
        pinned_path = temp / "pinned.lzms"
        pinned_out = temp / "pinned.out"
        pinned_path.write_bytes(pinned_encoded)
        run(
            args.cli,
            "decode-lzms-file",
            pinned_path,
            pinned_out,
            len(pinned_plain),
        )
        if pinned_out.read_bytes() != pinned_plain:
            raise AssertionError("pinned LZMS fixture mismatch")
        pinned_cases += 1

        probe = args.wimlib_probe
        if probe is None and args.wimlib_dir is not None:
            probe = build_probe(args.wimlib_dir, temp / "wimlib-lzms-probe")
        if probe is None:
            found = shutil.which("vort-wimlib-lzms-probe")
            probe = Path(found) if found else None

        if probe is not None:
            run(probe, "decode", pinned_path, temp / "pinned-wimlib.out", len(pinned_plain))
            if (temp / "pinned-wimlib.out").read_bytes() != pinned_plain:
                raise AssertionError("wimlib pinned LZMS decode mismatch")

            rng = random.Random(0x4C5A_4D53)
            cases = {
                "repeated": b"LZMS repeated payload 0123456789\n" * 2000,
                "delta": bytes((row + column) & 0xFF for row in range(512) for column in range(64)),
                "x86": x86_payload(),
                "mixed": (b"structured-prefix\n" * 1000) + rng.randbytes(4096) + (b"structured-tail\n" * 1000),
                "source": Path("src/lzms/decoder.zig").read_bytes(),
            }
            for name, plain in cases.items():
                source = temp / f"{name}.bin"
                encoded = temp / f"{name}.lzms"
                decoded = temp / f"{name}.out"
                oracle = temp / f"{name}-oracle.out"
                source.write_bytes(plain)
                run(probe, "encode", source, encoded)
                run(probe, "decode", encoded, oracle, len(plain))
                if oracle.read_bytes() != plain:
                    raise AssertionError(f"wimlib LZMS round trip mismatch for {name}")
                run(args.cli, "decode-lzms-file", encoded, decoded, len(plain))
                if decoded.read_bytes() != plain:
                    raise AssertionError(f"Vort LZMS decode mismatch for {name}")
                external_cases += 1

                vort_encoded = temp / f"{name}-vort.lzms"
                vort_oracle = temp / f"{name}-vort-oracle.out"
                run(args.cli, "encode-lzms-file", source, vort_encoded)
                run(probe, "decode", vort_encoded, vort_oracle, len(plain))
                if vort_oracle.read_bytes() != plain:
                    raise AssertionError(
                        f"wimlib decode of Vort LZMS mismatch for {name}"
                    )
                if name == "repeated" and vort_encoded.stat().st_size >= len(plain):
                    raise AssertionError("Vort LZMS did not compress repeated input")
                vort_encode_cases += 1

        odd = temp / "odd.lzms"
        odd.write_bytes(b"\0" * 5)
        expect_failure(
            args.cli,
            "decode-lzms-file",
            odd,
            temp / "odd.out",
            64,
            error_name="InvalidLzms",
        )
        malformed += 1
        truncated = temp / "truncated.lzms"
        truncated.write_bytes(pinned_encoded[:-2])
        expect_failure(
            args.cli,
            "decode-lzms-file",
            truncated,
            temp / "truncated.out",
            len(pinned_plain),
            error_name="InvalidLzms",
        )
        malformed += 1
        short = temp / "short.lzms"
        short.write_bytes(b"\0\0")
        expect_failure(
            args.cli,
            "decode-lzms-file",
            short,
            temp / "short.out",
            64,
            error_name="InvalidLzms",
        )
        malformed += 1

        matching_cli, matching_cli_failures = verify_matching_cli(args.cli, temp, run)

    print(
        f"pinned={pinned_cases} wimlib={probe is not None} "
        f"external={external_cases} vort_encode={vort_encode_cases} "
        f"malformed={malformed}"
        f" matching_cli={matching_cli} matching_cli_failures={matching_cli_failures}"
    )


if __name__ == "__main__":
    main()
