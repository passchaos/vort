#!/usr/bin/env python3
import argparse
import base64
import random
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


CHUNK_SIZES = {
    "xpress4k": 4096,
    "lzx": 32768,
    "xpress8k": 8192,
    "xpress16k": 16384,
}


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
        "tools/wof/wimlib_probe.c",
        f"-L{library_dir}",
        f"-Wl,-rpath,{library_dir}",
        "-lwim",
        "-o",
        output,
    )
    return output


def payload_for(algorithm: str) -> bytes:
    chunk_size = CHUNK_SIZES[algorithm]
    rng = random.Random(0x574F_4600 + chunk_size)
    first = (f"{algorithm} repeated chunk 0123456789\n".encode() * chunk_size)[:chunk_size]
    second = rng.randbytes(chunk_size)
    tail = (b"WOF partial final chunk\n" * chunk_size)[: chunk_size // 2 + 37]
    return first + second + tail


def encode_reference(probe: Path, algorithm: str, plain: bytes, temp: Path) -> bytes:
    chunk_size = CHUNK_SIZES[algorithm]
    chunks: list[bytes] = []
    for index, offset in enumerate(range(0, len(plain), chunk_size)):
        raw = plain[offset : offset + chunk_size]
        source = temp / f"{algorithm}-{index}.raw"
        encoded = temp / f"{algorithm}-{index}.encoded"
        source.write_bytes(raw)
        result = run(probe, "encode", algorithm, source, encoded, check=False)
        chunks.append(encoded.read_bytes() if result.returncode == 0 else raw)
    table = bytearray()
    cumulative = 0
    for chunk in chunks[:-1]:
        cumulative += len(chunk)
        table.extend(struct.pack("<I", cumulative))
    return bytes(table) + b"".join(chunks)


def decode_reference(
    probe: Path,
    algorithm: str,
    backing: bytes,
    decoded_size: int,
    temp: Path,
) -> bytes:
    chunk_size = CHUNK_SIZES[algorithm]
    chunk_count = (decoded_size + chunk_size - 1) // chunk_size
    table_size = max(0, chunk_count - 1) * 4
    if len(backing) <= table_size:
        raise AssertionError("invalid Vort WOF backing size")
    offsets = [0]
    offsets.extend(struct.unpack_from(f"<{chunk_count - 1}I", backing, 0))
    offsets.append(len(backing) - table_size)
    output = bytearray()
    for index in range(chunk_count):
        expected = min(chunk_size, decoded_size - len(output))
        stored = backing[table_size + offsets[index] : table_size + offsets[index + 1]]
        if len(stored) == expected:
            output.extend(stored)
        else:
            encoded = temp / f"vort-{algorithm}-{index}.encoded"
            decoded = temp / f"vort-{algorithm}-{index}.decoded"
            encoded.write_bytes(stored)
            run(probe, "decode", algorithm, encoded, decoded, expected)
            output.extend(decoded.read_bytes())
    return bytes(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--wimlib-dir", type=Path)
    parser.add_argument("--wimlib-probe", type=Path)
    args = parser.parse_args()

    pinned = 0
    external_decode = 0
    external_writer = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-wof-") as temp_text:
        temp = Path(temp_text)
        fixture = temp / "fixture.wof"
        fixture.write_bytes(
            base64.b64decode(Path("src/wof/testdata/xpress4k-small.wof.b64").read_text())
        )
        fixture_plain = b"WOF pinned XPRESS4K payload 0123456789\n" * 300
        fixture_out = temp / "fixture.out"
        run(
            args.cli,
            "decode-wof-file",
            fixture,
            fixture_out,
            "xpress4k",
            len(fixture_plain),
        )
        if fixture_out.read_bytes() != fixture_plain:
            raise AssertionError("pinned WOF fixture mismatch")
        pinned += 1

        probe = args.wimlib_probe
        if probe is None and args.wimlib_dir is not None:
            probe = build_probe(args.wimlib_dir, temp / "wimlib-wof-probe")
        if probe is None:
            found = shutil.which("vort-wimlib-wof-probe")
            probe = Path(found) if found else None

        if probe is not None:
            for algorithm in CHUNK_SIZES:
                plain = payload_for(algorithm)
                reference = encode_reference(probe, algorithm, plain, temp)
                backing = temp / f"reference-{algorithm}.wof"
                output = temp / f"reference-{algorithm}.out"
                range_output = temp / f"reference-{algorithm}.range"
                backing.write_bytes(reference)
                summary = run(
                    args.cli,
                    "inspect-wof-file",
                    backing,
                    algorithm,
                    len(plain),
                ).stdout
                if b"raw=true" not in summary or b"raw=false" not in summary:
                    raise AssertionError(f"missing mixed WOF chunks for {algorithm}")
                run(args.cli, "decode-wof-file", backing, output, algorithm, len(plain))
                if output.read_bytes() != plain:
                    raise AssertionError(f"Vort WOF decode mismatch for {algorithm}")
                range_offset = CHUNK_SIZES[algorithm] - 31
                range_len = CHUNK_SIZES[algorithm] + 79
                run(
                    args.cli,
                    "decode-wof-range",
                    backing,
                    range_output,
                    algorithm,
                    len(plain),
                    range_offset,
                    range_len,
                )
                if range_output.read_bytes() != plain[range_offset : range_offset + range_len]:
                    raise AssertionError(f"Vort WOF range mismatch for {algorithm}")
                external_decode += 1

                source = temp / f"vort-{algorithm}.source"
                vort_backing = temp / f"vort-{algorithm}.wof"
                source.write_bytes(plain)
                run(args.cli, "encode-wof-file", source, vort_backing, algorithm)
                if decode_reference(
                    probe,
                    algorithm,
                    vort_backing.read_bytes(),
                    len(plain),
                    temp,
                ) != plain:
                    raise AssertionError(f"wimlib WOF decode mismatch for {algorithm}")
                external_writer += 1

        bad_zero = bytearray(fixture.read_bytes())
        bad_zero[0:4] = b"\0" * 4
        bad_zero_path = temp / "bad-zero.wof"
        bad_zero_path.write_bytes(bad_zero)
        expect_failure(
            args.cli,
            "inspect-wof-file",
            bad_zero_path,
            "xpress4k",
            len(fixture_plain),
            error_name="InvalidWof",
        )
        malformed += 1
        bad_large = bytearray(fixture.read_bytes())
        bad_large[0:4] = struct.pack("<I", len(bad_large) * 2)
        bad_large_path = temp / "bad-large.wof"
        bad_large_path.write_bytes(bad_large)
        expect_failure(
            args.cli,
            "inspect-wof-file",
            bad_large_path,
            "xpress4k",
            len(fixture_plain),
            error_name="InvalidWof",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-wof-file",
            fixture,
            temp / "limited.out",
            "xpress4k",
            len(fixture_plain),
            len(fixture_plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-wof-range",
            fixture,
            temp / "range-oob.out",
            "xpress4k",
            len(fixture_plain),
            len(fixture_plain) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1

    print(
        f"pinned={pinned} wimlib={probe is not None} "
        f"external_decode={external_decode} external_writer={external_writer} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
