#!/usr/bin/env python3
import argparse
import importlib
import random
import subprocess
import sys
import tempfile
from pathlib import Path


OFFICIAL_ENCODED = bytes.fromhex(
    "38b08846232000204720410010a24701a045204400084501507900c045200524"
    "138805b4024a44ef0358028c091601484500be009e000401189000"
)
OFFICIAL_PLAIN = (
    b"F# F# G A A G F# E D D E F# F# E E F# F# G A A G F# E D D E F# "
    b"E D D E E F# D E F# G F# D E F# G F# E D E A F# F# G A A G F# E "
    b"D D E F# E D D\x00"
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


def load_oracle(path: Path | None):
    if path is not None:
        sys.path.insert(0, str(path))
    try:
        return importlib.import_module("lznt1")
    except ImportError:
        return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--oracle-dir", type=Path)
    args = parser.parse_args()
    oracle = load_oracle(args.oracle_dir)

    rng = random.Random(0x4C5A_4E54_31)
    cases = {
        "empty": b"",
        "tiny": b"hello LZNT1",
        "repeated": b"LZNT1 repeated payload 0123456789\n" * 200,
        "boundary": bytes(range(256)) * 16,
        "multi": (b"multi-chunk LZNT1 payload abcdefghijklmnopqrstuvwxyz\n" * 300)[:14000],
        "random": rng.randbytes(512),
    }
    self_cases = 0
    external_decode = 0
    external_encode = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-lznt1-") as temp_text:
        temp = Path(temp_text)
        official = temp / "official.lznt1"
        official.write_bytes(OFFICIAL_ENCODED)
        official_out = temp / "official.out"
        run(args.cli, "decode-lznt1-file", official, official_out, len(OFFICIAL_PLAIN))
        if official_out.read_bytes() != OFFICIAL_PLAIN:
            raise AssertionError("MS-XCA official example mismatch")

        for name, plain in cases.items():
            source = temp / f"{name}.bin"
            encoded = temp / f"{name}.lznt1"
            repeated = temp / f"{name}-repeat.lznt1"
            decoded = temp / f"{name}.out"
            source.write_bytes(plain)
            run(args.cli, "encode-lznt1-file", source, encoded, "no-marker")
            run(args.cli, "encode-lznt1-file", source, repeated, "no-marker")
            if encoded.read_bytes() != repeated.read_bytes():
                raise AssertionError(f"non-deterministic LZNT1 output for {name}")
            summary = run(args.cli, "inspect-lznt1-file", encoded, len(plain)).stdout
            if f"decoded_bytes={len(plain)}".encode() not in summary:
                raise AssertionError(f"LZNT1 summary mismatch for {name}: {summary!r}")
            run(args.cli, "decode-lznt1-file", encoded, decoded, len(plain))
            if decoded.read_bytes() != plain:
                raise AssertionError(f"Vort LZNT1 self decode mismatch for {name}")
            self_cases += 1

            if oracle is not None:
                if oracle.decompress(encoded.read_bytes()) != plain:
                    raise AssertionError(f"oracle decode mismatch for {name}")
                external_decode += 1
                oracle_encoded = temp / f"{name}-oracle.lznt1"
                oracle_encoded.write_bytes(oracle.compress(plain))
                oracle_out = temp / f"{name}-oracle.out"
                run(args.cli, "decode-lznt1-file", oracle_encoded, oracle_out, len(plain))
                if oracle_out.read_bytes() != plain:
                    raise AssertionError(f"oracle encode mismatch for {name}")
                external_encode += 1

        limited = temp / "limited.out"
        expect_failure(
            args.cli,
            "decode-lznt1-file",
            temp / "repeated.lznt1",
            limited,
            len(cases["repeated"]) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        malformed_cases = (
            ("truncated-header", b"\x00", "TruncatedFrame"),
            ("bad-signature", b"\x00\x20x", "InvalidLznt1"),
            ("truncated-payload", b"\x01\x30x", "TruncatedFrame"),
            ("invalid-match", b"\x02\xb0\x01\x00\x00", "InvalidMatch"),
            ("trailing-data", b"\x00\x00\x01", "TrailingData"),
        )
        for name, data, error_name in malformed_cases:
            path = temp / f"{name}.lznt1"
            path.write_bytes(data)
            expect_failure(
                args.cli,
                "inspect-lznt1-file",
                path,
                1024,
                error_name=error_name,
            )
            malformed += 1

    print(
        f"official=1 self={self_cases} oracle={oracle is not None} "
        f"external_decode={external_decode} external_encode={external_encode} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
