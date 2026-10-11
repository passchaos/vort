#!/usr/bin/env python3
import argparse
import importlib
import random
import subprocess
import sys
import tempfile
from pathlib import Path


OFFICIAL_ENCODED = bytes.fromhex("ffffff1f61626317000fff2601")
OFFICIAL_PLAIN = b"abc" * 100


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
        return importlib.import_module("xpress_lz77")
    except ImportError:
        return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--oracle-dir", type=Path)
    args = parser.parse_args()
    oracle = load_oracle(args.oracle_dir)

    rng = random.Random(0x5850_5245_5353)
    cases = {
        "empty": b"",
        "tiny": b"hello XPRESS",
        "official-plain": OFFICIAL_PLAIN,
        "repeated": b"XPRESS repeated payload 0123456789\n" * 300,
        "multi-window": (b"abcdefgh" * 2500) + (b"abcdefgh" * 2500),
        "long-match": b"Z" * 70_000,
        "random": rng.randbytes(9000),
    }
    self_cases = 0
    external_decode = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-xpress-") as temp_text:
        temp = Path(temp_text)
        official = temp / "official.xpress"
        official.write_bytes(OFFICIAL_ENCODED)
        official_out = temp / "official.out"
        run(
            args.cli,
            "decode-xpress-plain-file",
            official,
            official_out,
            len(OFFICIAL_PLAIN),
        )
        if official_out.read_bytes() != OFFICIAL_PLAIN:
            raise AssertionError("MS-XCA XPRESS example mismatch")

        for name, plain in cases.items():
            source = temp / f"{name}.bin"
            encoded = temp / f"{name}.xpress"
            repeated = temp / f"{name}-repeat.xpress"
            decoded = temp / f"{name}.out"
            source.write_bytes(plain)
            run(args.cli, "encode-xpress-plain-file", source, encoded)
            run(args.cli, "encode-xpress-plain-file", source, repeated)
            if encoded.read_bytes() != repeated.read_bytes():
                raise AssertionError(f"non-deterministic XPRESS output for {name}")
            summary = run(
                args.cli,
                "inspect-xpress-plain-file",
                encoded,
                len(plain),
            ).stdout
            if f"decoded_bytes={len(plain)}".encode() not in summary:
                raise AssertionError(f"XPRESS summary mismatch for {name}: {summary!r}")
            run(
                args.cli,
                "decode-xpress-plain-file",
                encoded,
                decoded,
                len(plain),
            )
            if decoded.read_bytes() != plain:
                raise AssertionError(f"Vort XPRESS self decode mismatch for {name}")
            self_cases += 1

            if oracle is not None:
                oracle_decoded = oracle.lz77_plain_decompress_py(encoded.read_bytes())
                if oracle_decoded != plain:
                    raise AssertionError(f"oracle XPRESS decode mismatch for {name}")
                external_decode += 1

        limited = temp / "limited.out"
        expect_failure(
            args.cli,
            "decode-xpress-plain-file",
            temp / "repeated.xpress",
            limited,
            len(cases["repeated"]) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        malformed_cases = (
            ("truncated-flags", b"\x00\x00\x00", "TruncatedFrame"),
            ("missing-literal", b"\x00\x00\x00\x00", "TruncatedFrame"),
            ("invalid-match", b"\x00\x00\x00\x80\x00\x00", "InvalidMatch"),
            (
                "truncated-extension",
                b"\x00\x00\x00\x40a\x07\x00\x0f",
                "TruncatedFrame",
            ),
            (
                "invalid-wide-length",
                b"\x00\x00\x00\x40a\x07\x00\x0f\xff\x01\x00",
                "InvalidXpress",
            ),
        )
        for name, data, error_name in malformed_cases:
            path = temp / f"{name}.xpress"
            path.write_bytes(data)
            expect_failure(
                args.cli,
                "inspect-xpress-plain-file",
                path,
                1024,
                error_name=error_name,
            )
            malformed += 1

    print(
        f"official=1 self={self_cases} oracle={oracle is not None} "
        f"external_decode={external_decode} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
