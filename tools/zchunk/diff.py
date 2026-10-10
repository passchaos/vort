#!/usr/bin/env python3
import argparse
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


def expect_failure(*args: object, error_name: str | None = None) -> None:
    result = run(*args, check=False)
    if result.returncode == 0:
        raise AssertionError(f"command unexpectedly succeeded: {args}")
    if error_name is not None and error_name.encode() not in result.stderr:
        raise AssertionError(
            f"missing {error_name} diagnostic: {result.stderr.decode(errors='replace')}"
        )


def payloads() -> list[tuple[str, bytes]]:
    state = 0x9E37_79B9
    random_data = bytearray()
    for _ in range(50_000):
        state = (state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        random_data.append(state >> 24)
    structured = bytearray()
    for index in range(5000):
        structured.extend(f'{{"id":{index},"format":"zchunk","bucket":{index % 29}}}\n'.encode())
    return [
        ("empty", b""),
        ("tiny", b"zchunk"),
        ("repetitive", b"independent zchunk payload\n" * 8192),
        ("structured", bytes(structured)),
        ("random", bytes(random_data)),
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--zck", type=Path)
    parser.add_argument("--unzck", type=Path)
    parser.add_argument("--read-header", type=Path)
    args = parser.parse_args()
    zck = args.zck or (Path(found) if (found := shutil.which("zck")) else None)
    if zck is not None:
        unzck = args.unzck or zck.with_name("unzck")
        read_header = args.read_header or zck.with_name("zck_read_header")
        if not unzck.exists() or not read_header.exists():
            raise AssertionError("zchunk oracle siblings are missing")
        version = run(zck, "--version").stdout.splitlines()[0].decode()
    else:
        unzck = None
        read_header = None
        version = "unavailable"

    self_cases = 0
    external_encode = 0
    external_decode = 0
    dictionary_cases = 0
    malformed = 0
    header_only = 0

    with tempfile.TemporaryDirectory(prefix="vort-zchunk-") as temp_text:
        temp = Path(temp_text)
        primary_encoded: Path | None = None
        primary_payload = b""
        for name, payload in payloads():
            source = temp / f"{name}.bin"
            source.write_bytes(payload)
            encoded = temp / f"{name}.vort.zck"
            repeated = temp / f"{name}.repeat.zck"
            decoded = temp / f"{name}.vort.out"
            chunk_size = 32 * 1024
            run(args.cli, "encode-zchunk-file", source, encoded, chunk_size, "zstd", "normal")
            run(args.cli, "encode-zchunk-file", source, repeated, chunk_size, "zstd", "normal")
            if encoded.read_bytes() != repeated.read_bytes():
                raise AssertionError(f"non-deterministic zchunk output for {name}")
            expected_chunks = 1 + (len(payload) + chunk_size - 1) // chunk_size
            listing = run(args.cli, "inspect-zchunk-file", encoded).stdout
            if f"zchunk_chunks={expected_chunks}".encode() not in listing:
                raise AssertionError(f"zchunk metadata mismatch for {name}: {listing!r}")
            run(args.cli, "decode-zchunk-file", encoded, decoded, len(payload))
            if decoded.read_bytes() != payload:
                raise AssertionError(f"zchunk round trip mismatch for {name}")
            if payload and expected_chunks > 2:
                extracted = temp / f"{name}.chunk2"
                run(
                    args.cli,
                    "extract-zchunk-chunk",
                    encoded,
                    2,
                    extracted,
                    chunk_size,
                )
                if extracted.read_bytes() != payload[chunk_size : 2 * chunk_size]:
                    raise AssertionError(f"indexed zchunk extraction mismatch for {name}")
            self_cases += 1
            if payload and primary_encoded is None:
                primary_encoded = encoded
                primary_payload = payload

            if zck is not None:
                assert unzck is not None and read_header is not None
                run(read_header, "--quiet", "--verify", encoded)
                if run(unzck, "--stdout", encoded).stdout != payload:
                    raise AssertionError(f"unzck rejected Vort output for {name}")
                external_decode += 1

                reference = temp / f"{name}.reference.zck"
                run(zck, "--manual-chunk", "--output", reference, source)
                reference_output = temp / f"{name}.reference.out"
                run(
                    args.cli,
                    "decode-zchunk-file",
                    reference,
                    reference_output,
                    len(payload),
                )
                if reference_output.read_bytes() != payload:
                    raise AssertionError(f"Vort rejected zck output for {name}")
                external_encode += 1

        assert primary_encoded is not None
        for compression, source_mode in (
            ("none", "normal"),
            ("zstd", "source-hashes"),
            ("none", "source-hashes"),
        ):
            source = temp / f"writer-{compression}-{source_mode}.bin"
            source.write_bytes(primary_payload * 256)
            encoded = temp / f"writer-{compression}-{source_mode}.zck"
            decoded = temp / f"writer-{compression}-{source_mode}.out"
            run(
                args.cli,
                "encode-zchunk-file",
                source,
                encoded,
                4096,
                compression,
                source_mode,
            )
            run(args.cli, "decode-zchunk-file", encoded, decoded, len(source.read_bytes()))
            if decoded.read_bytes() != source.read_bytes():
                raise AssertionError(f"Vort {compression}/{source_mode} mismatch")
            self_cases += 1
            if zck is not None:
                assert unzck is not None and read_header is not None
                run(read_header, "--quiet", "--verify", encoded)
                if run(unzck, "--stdout", encoded).stdout != source.read_bytes():
                    raise AssertionError(f"unzck rejected {compression}/{source_mode}")
                external_decode += 1

        if zck is not None:
            source = temp / "dictionary.bin"
            dictionary = temp / "dictionary.raw"
            payload = (b"dictionary-backed zchunk record\n" * 4096) + bytes(range(256))
            source.write_bytes(payload)
            dictionary.write_bytes(payload[:4096])
            encoded = temp / "dictionary.reference.zck"
            run(zck, "--manual-chunk", "--dict", dictionary, "--output", encoded, source)
            decoded = temp / "dictionary.vort.out"
            run(args.cli, "decode-zchunk-file", encoded, decoded, len(payload))
            if decoded.read_bytes() != payload:
                raise AssertionError("Vort rejected dictionary-backed zchunk")
            dictionary_chunk = temp / "dictionary.chunk"
            run(args.cli, "extract-zchunk-chunk", encoded, 0, dictionary_chunk, 4096)
            if dictionary_chunk.read_bytes() != dictionary.read_bytes():
                raise AssertionError("Vort dictionary chunk extraction mismatch")
            dictionary_cases += 1
            external_encode += 1

        listing = run(args.cli, "inspect-zchunk-file", primary_encoded).stdout.decode()
        marker = "header_bytes="
        header_size = int(listing.split(marker, 1)[1].split()[0])
        header_path = temp / "header-only.zck"
        header_path.write_bytes(primary_encoded.read_bytes()[:header_size])
        header_listing = run(args.cli, "inspect-zchunk-file", header_path).stdout
        if b"body_present=false" not in header_listing:
            raise AssertionError("Vort did not recognize header-only zchunk")
        expect_failure(
            args.cli,
            "decode-zchunk-file",
            header_path,
            temp / "header-only.out",
            len(primary_payload),
            error_name="TruncatedFrame",
        )
        header_only += 1

        expect_failure(
            args.cli,
            "decode-zchunk-file",
            primary_encoded,
            temp / "limited.out",
            len(primary_payload) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        original = primary_encoded.read_bytes()
        malformed_cases = [
            ("bad-magic", b"nope!", "InvalidMagic"),
            ("truncated", original[:-1], "TruncatedFrame"),
            ("trailing", original + b"x", "TrailingData"),
            ("header-checksum", original[:10] + bytes((original[10] ^ 1,)) + original[11:], "ChecksumMismatch"),
            ("body-checksum", original[:-1] + bytes((original[-1] ^ 1,)), "ChecksumMismatch"),
            ("bad-compint", original[:5] + bytes(16), "IntegerOverflow"),
        ]
        for name, data, error_name in malformed_cases:
            path = temp / f"{name}.zck"
            path.write_bytes(data)
            expect_failure(
                args.cli,
                "decode-zchunk-file",
                path,
                temp / f"{name}.out",
                512 * 1024 * 1024,
                error_name=error_name,
            )
            malformed += 1
        expect_failure(
            args.cli,
            "extract-zchunk-chunk",
            primary_encoded,
            999,
            temp / "missing.out",
            1024,
            error_name="ZchunkChunkOutOfRange",
        )
        malformed += 1

    print(
        f"self_cases={self_cases} oracle={version!r} "
        f"external_encode={external_encode} external_decode={external_decode} "
        f"dictionary={dictionary_cases} header_only={header_only} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
