#!/usr/bin/env python3
import argparse
import importlib
import random
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


OFFICIAL_ENCODED = bytes.fromhex("ffffff1f61626317000fff2601")
OFFICIAL_PLAIN = b"abc" * 100
OFFICIAL_HUFFMAN_LITERAL = bytes.fromhex(
    "0000000000000000000000000000000000000000000000000000000000000000"
    "0000000000000000000000000000000050555555555555555555554544040000"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "0400000000000000000000000000000000000000000000000000000000000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "d8523ed794115be9195ff9d67cdf8d0400000000"
)
OFFICIAL_HUFFMAN_MATCH = bytes.fromhex(
    "0000000000000000000000000000000000000000000000000000000000000000"
    "0000000000000000000000000000000030230000000000000000000000000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "0200000000000000000000000000002000000000000000000000000000000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "a8dc0000ff2601"
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
        return importlib.import_module("xpress_lz77")
    except ImportError:
        return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--oracle-dir", type=Path)
    parser.add_argument("--wimlib-probe", type=Path)
    args = parser.parse_args()
    oracle = load_oracle(args.oracle_dir)
    wimlib_probe = args.wimlib_probe or (
        Path(found) if (found := shutil.which("vort-wimlib-xpress-probe")) else None
    )

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
    huffman_self = 0
    huffman_external_decode = 0
    wimlib_decode = 0
    wimlib_encode = 0
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

        for name, data, plain in (
            ("huffman-literal", OFFICIAL_HUFFMAN_LITERAL, b"abcdefghijklmnopqrstuvwxyz"),
            ("huffman-match", OFFICIAL_HUFFMAN_MATCH, OFFICIAL_PLAIN),
        ):
            path = temp / f"official-{name}.xpress"
            output = temp / f"official-{name}.out"
            path.write_bytes(data)
            run(
                args.cli,
                "decode-xpress-huffman-file",
                path,
                output,
                len(plain),
            )
            if output.read_bytes() != plain:
                raise AssertionError(f"MS-XCA {name} example mismatch")
            if oracle is not None:
                if oracle.lz77_huffman_decompress_py(data, len(plain)) != plain:
                    raise AssertionError(f"oracle MS-XCA {name} mismatch")

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

            if len(plain) <= 65_536:
                huffman_encoded = temp / f"{name}.huffman"
                huffman_repeated = temp / f"{name}-repeat.huffman"
                huffman_decoded = temp / f"{name}-huffman.out"
                run(args.cli, "encode-xpress-huffman-file", source, huffman_encoded)
                run(args.cli, "encode-xpress-huffman-file", source, huffman_repeated)
                if huffman_encoded.read_bytes() != huffman_repeated.read_bytes():
                    raise AssertionError(f"non-deterministic XPRESS Huffman output for {name}")
                run(
                    args.cli,
                    "inspect-xpress-huffman-file",
                    huffman_encoded,
                    len(plain),
                )
                run(
                    args.cli,
                    "decode-xpress-huffman-file",
                    huffman_encoded,
                    huffman_decoded,
                    len(plain),
                )
                if huffman_decoded.read_bytes() != plain:
                    raise AssertionError(f"Vort XPRESS Huffman mismatch for {name}")
                huffman_self += 1
                if oracle is not None:
                    oracle_decoded = oracle.lz77_huffman_decompress_py(
                        huffman_encoded.read_bytes(), len(plain)
                    )
                    if oracle_decoded != plain:
                        raise AssertionError(f"oracle XPRESS Huffman mismatch for {name}")
                    huffman_external_decode += 1
                if wimlib_probe is not None:
                    wimlib_out = temp / f"{name}-wimlib.out"
                    run(
                        wimlib_probe,
                        "decode",
                        huffman_encoded,
                        wimlib_out,
                        len(plain),
                    )
                    if wimlib_out.read_bytes() != plain:
                        raise AssertionError(f"wimlib XPRESS decode mismatch for {name}")
                    wimlib_decode += 1

                    wimlib_encoded = temp / f"{name}-wimlib.xpress"
                    result = run(
                        wimlib_probe,
                        "encode",
                        source,
                        wimlib_encoded,
                        check=False,
                    )
                    if result.returncode not in (0, 3):
                        raise AssertionError(f"wimlib XPRESS encode failed for {name}")
                    if result.returncode == 0:
                        wimlib_vort_out = temp / f"{name}-wimlib-vort.out"
                        run(
                            args.cli,
                            "decode-xpress-huffman-file",
                            wimlib_encoded,
                            wimlib_vort_out,
                            len(plain),
                        )
                        if wimlib_vort_out.read_bytes() != plain:
                            raise AssertionError(f"wimlib XPRESS encode mismatch for {name}")
                        wimlib_encode += 1

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
        bad_huffman = temp / "bad-huffman.xpress"
        bad_huffman.write_bytes(bytes(260))
        expect_failure(
            args.cli,
            "inspect-xpress-huffman-file",
            bad_huffman,
            0,
            error_name="InvalidHuffmanCode",
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
        f"official=3 plain_self={self_cases} huffman_self={huffman_self} "
        f"oracle={oracle is not None} plain_external_decode={external_decode} "
        f"huffman_external_decode={huffman_external_decode} "
        f"wimlib={wimlib_probe is not None} wimlib_decode={wimlib_decode} "
        f"wimlib_encode={wimlib_encode} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
