#!/usr/bin/env python3
import argparse
from datetime import datetime, timezone
import hashlib
import json
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

MAGIC_END = b"bvx$"
MAGIC_RAW = b"bvx-"
MAGIC_V1 = b"bvx1"
MAGIC_V2 = b"bvx2"
MAGIC_LZVN = b"bvxn"
V1_HEADER_SIZE = 772
V2_FIXED_SIZE = 32


def run(*args: object, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=ROOT,
    )


def build_apple_status_probe(reference: Path, workspace: Path, reference_dir: Path | None = None,
                             required: bool = False) -> Path | None:
    checkout = run("git", "-C", reference_dir or reference.parent, "rev-parse", "--show-toplevel", check=False)
    if checkout.returncode == 0:
        root = Path(checkout.stdout.decode().strip())
        static_library = root / "build/bin/liblzfse.a"
        if static_library.exists():
            probe = workspace / "apple-status-probe"
            run("cc", "-O2", f"-I{root / 'src'}", ROOT / "tools/lzfse/apple_status_probe.c",
                static_library, "-o", probe)
            return probe
    if required:
        raise RuntimeError("Apple status probe requires the reference checkout's build/bin/liblzfse.a")
    return None


def scan(data: bytes) -> list[tuple[str, int, int, int]]:
    position = 0
    blocks: list[tuple[str, int, int, int]] = []
    while True:
        if len(data) - position < 4:
            raise AssertionError("truncated LZFSE magic")
        magic = data[position : position + 4]
        if magic == MAGIC_END:
            position += 4
            if position != len(data):
                raise AssertionError("trailing LZFSE data")
            return blocks
        start = position
        if magic == MAGIC_RAW:
            if len(data) - position < 8:
                raise AssertionError("truncated raw header")
            raw_size = struct.unpack_from("<I", data, position + 4)[0]
            position += 8 + raw_size
            kind = "raw"
        elif magic == MAGIC_LZVN:
            if len(data) - position < 12:
                raise AssertionError("truncated LZVN header")
            raw_size, payload_size = struct.unpack_from("<II", data, position + 4)
            position += 12 + payload_size
            kind = "lzvn"
        elif magic == MAGIC_V1:
            if len(data) - position < V1_HEADER_SIZE:
                raise AssertionError("truncated V1 header")
            raw_size = struct.unpack_from("<I", data, position + 4)[0]
            literal_size, lmd_size = struct.unpack_from("<II", data, position + 20)
            position += V1_HEADER_SIZE + literal_size + lmd_size
            kind = "v1"
        elif magic == MAGIC_V2:
            if len(data) - position < V2_FIXED_SIZE:
                raise AssertionError("truncated V2 header")
            raw_size = struct.unpack_from("<I", data, position + 4)[0]
            packed0, packed1, packed2 = struct.unpack_from("<QQQ", data, position + 8)
            header_size = packed2 & 0xFFFF_FFFF
            literal_size = (packed0 >> 20) & 0xF_FFFF
            lmd_size = (packed1 >> 40) & 0xF_FFFF
            if header_size < V2_FIXED_SIZE:
                raise AssertionError("invalid V2 header size")
            position += header_size + literal_size + lmd_size
            kind = "v2"
        else:
            raise AssertionError(f"invalid LZFSE magic {magic!r}")
        if position > len(data):
            raise AssertionError(f"truncated {kind} payload")
        blocks.append((kind, start, position, raw_size))


def decode_frequencies(encoded: bytes) -> list[int]:
    bit_value = int.from_bytes(encoded, "little")
    bit_offset = 0
    bit_counts = [2, 3, 2, 5, 2, 3, 2, 8, 2, 3, 2, 5, 2, 3, 2, 14] * 2
    values = [
        0,
        2,
        1,
        4,
        0,
        3,
        1,
        0,
        0,
        2,
        1,
        5,
        0,
        3,
        1,
        0,
        0,
        2,
        1,
        6,
        0,
        3,
        1,
        0,
        0,
        2,
        1,
        7,
        0,
        3,
        1,
        0,
    ]
    frequencies: list[int] = []
    for _ in range(360):
        bits = (bit_value >> bit_offset) & 0x3FFF
        bit_count = bit_counts[bits & 31]
        if bit_count == 8:
            frequency = 8 + ((bits >> 4) & 15)
        elif bit_count == 14:
            frequency = 24 + ((bits >> 4) & 1023)
        else:
            frequency = values[bits & 31]
        frequencies.append(frequency)
        bit_offset += bit_count
    if (bit_offset + 7) // 8 != len(encoded):
        raise AssertionError("V2 frequency byte count mismatch")
    return frequencies


def v2_block_to_v1(data: bytes, start: int, end: int) -> bytes:
    raw_size = struct.unpack_from("<I", data, start + 4)[0]
    packed0, packed1, packed2 = struct.unpack_from("<QQQ", data, start + 8)
    header_size = packed2 & 0xFFFF_FFFF
    literal_count = packed0 & 0xF_FFFF
    literal_size = (packed0 >> 20) & 0xF_FFFF
    match_count = (packed0 >> 40) & 0xF_FFFF
    literal_bits = ((packed0 >> 60) & 7) - 7
    literal_states = [(packed1 >> shift) & 1023 for shift in (0, 10, 20, 30)]
    lmd_size = (packed1 >> 40) & 0xF_FFFF
    lmd_bits = ((packed1 >> 60) & 7) - 7
    l_state = (packed2 >> 32) & 1023
    m_state = (packed2 >> 42) & 1023
    d_state = (packed2 >> 52) & 1023
    frequencies = decode_frequencies(data[start + V2_FIXED_SIZE : start + header_size])
    header = bytearray(V1_HEADER_SIZE)
    struct.pack_into(
        "<7Ii4Hi3H",
        header,
        0,
        0x31787662,
        raw_size,
        literal_size + lmd_size,
        literal_count,
        match_count,
        literal_size,
        lmd_size,
        literal_bits,
        *literal_states,
        lmd_bits,
        l_state,
        m_state,
        d_state,
    )
    for index, frequency in enumerate(frequencies):
        struct.pack_into("<H", header, 50 + index * 2, frequency)
    return bytes(header) + data[start + header_size : end]


def convert_v2_to_v1(data: bytes) -> tuple[bytes, int]:
    converted = bytearray()
    converted_count = 0
    for kind, start, end, _ in scan(data):
        if kind == "v2":
            converted.extend(v2_block_to_v1(data, start, end))
            converted_count += 1
        else:
            converted.extend(data[start:end])
    converted.extend(MAGIC_END)
    return bytes(converted), converted_count


def expect_failure(*args: object, error_name: str | None = None) -> None:
    result = run(*args, check=False)
    if result.returncode == 0:
        raise AssertionError(f"command unexpectedly succeeded: {args}")
    if error_name is not None and error_name.encode() not in result.stderr:
        raise AssertionError(
            f"missing {error_name} diagnostic: {result.stderr.decode(errors='replace')}"
        )


def payloads() -> list[tuple[str, bytes]]:
    state = 0x1234_5678
    random_data = bytearray()
    for _ in range(50_000):
        state ^= (state << 13) & 0xFFFF_FFFF
        state ^= state >> 17
        state ^= (state << 5) & 0xFFFF_FFFF
        random_data.append(state & 0xFF)
    structured = bytearray()
    for index in range(12_000):
        structured.extend(f'{{"id":{index},"kind":"lzfse","bucket":{index % 31}}}\n'.encode())
    return [
        ("empty", b""),
        ("tiny", b"abc"),
        ("lzvn", b"Apple LZVN payload abcabcabc\n" * 128),
        ("structured", bytes(structured)),
        ("random", bytes(random_data)),
        ("zeros", bytes(100_000)),
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--lzfse", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    args.cli = args.cli.resolve()
    reference = args.lzfse or (Path(found) if (found := shutil.which("lzfse")) else None)
    if reference is not None:
        reference = reference.resolve()
    self_cases = 0
    external_encode = 0
    external_decode = 0
    v1_cases = 0
    malformed = 0
    kind_counts = {"raw": 0, "lzvn": 0, "v1": 0, "v2": 0}
    vort_kind_counts = dict.fromkeys(kind_counts, 0)
    rows = []
    apple_status_sha256 = None

    with tempfile.TemporaryDirectory(prefix="vort-lzfse-") as temp_text:
        temp = Path(temp_text)
        apple_status = build_apple_status_probe(reference, temp) if reference else None
        if apple_status:
            apple_status_sha256 = hashlib.sha256(apple_status.read_bytes()).hexdigest()
        valid_for_malformed: Path | None = None
        v2_for_malformed: Path | None = None
        for name, payload in payloads():
            source = temp / f"{name}.bin"
            source.write_bytes(payload)
            for strategy in ("auto", "fse", "lzvn", "stored"):
                encoded = temp / f"{name}.{strategy}.vort.lzfse"
                repeated = temp / f"{name}.{strategy}.repeat.lzfse"
                decoded = temp / f"{name}.{strategy}.vort.out"
                run(args.cli, "encode-lzfse-file", source, encoded, 32768, strategy)
                run(args.cli, "encode-lzfse-file", source, repeated, 32768, strategy)
                wire = encoded.read_bytes()
                if wire != repeated.read_bytes():
                    raise AssertionError(f"non-deterministic Vort LZFSE output for {name}/{strategy}")
                blocks = scan(wire)
                for kind, _, _, _ in blocks:
                    vort_kind_counts[kind] += 1
                listing = run(args.cli, "inspect-lzfse-file", encoded, len(payload)).stdout
                if f"decoded_bytes={len(payload)}".encode() not in listing:
                    raise AssertionError(f"Vort LZFSE metadata mismatch for {name}/{strategy}: {listing!r}")
                run(args.cli, "decode-lzfse-file", encoded, decoded, len(payload))
                if decoded.read_bytes() != payload:
                    raise AssertionError(f"Vort LZFSE round trip mismatch for {name}/{strategy}")
                self_cases += 1
                if payload and valid_for_malformed is None:
                    valid_for_malformed = encoded
                rows.append({"case": name, "strategy": strategy, "input_bytes": len(payload),
                             "encoded_bytes": len(wire), "input_sha256": hashlib.sha256(payload).hexdigest(),
                             "output_sha256": hashlib.sha256(wire).hexdigest(),
                             "blocks": {kind: sum(block[0] == kind for block in blocks) for kind in kind_counts}})
                if reference is not None and (payload or apple_status):
                    reference_decoded = temp / f"{name}.{strategy}.reference.out"
                    if payload:
                        run(reference, "-decode", "-i", encoded, "-o", reference_decoded)
                    else:
                        run(apple_status, encoded, reference_decoded, 0)
                    if reference_decoded.read_bytes() != payload:
                        raise AssertionError(f"Apple decoder rejected Vort output for {name}/{strategy}")
                    external_decode += 1
                    converted, converted_count = convert_v2_to_v1(wire)
                    if converted_count:
                        converted_path = temp / f"{name}.{strategy}.vort-v1.lzfse"
                        converted_path.write_bytes(converted)
                        run(args.cli, "decode-lzfse-file", converted_path, decoded, len(payload))
                        run(reference, "-decode", "-i", converted_path, "-o", reference_decoded)
                        if decoded.read_bytes() != payload or reference_decoded.read_bytes() != payload:
                            raise AssertionError(f"Vort V2-to-V1 conversion mismatch for {name}/{strategy}")
                        v1_cases += converted_count

            if reference is not None and payload:

                reference_encoded = temp / f"{name}.reference.lzfse"
                run(reference, "-encode", "-i", source, "-o", reference_encoded)
                reference_blocks = scan(reference_encoded.read_bytes())
                for kind, _, _, _ in reference_blocks:
                    kind_counts[kind] += 1
                reference_output = temp / f"{name}.reference-vort.out"
                run(
                    args.cli,
                    "decode-lzfse-file",
                    reference_encoded,
                    reference_output,
                    len(payload),
                )
                if reference_output.read_bytes() != payload:
                    raise AssertionError(f"Vort rejected Apple output for {name}")
                external_encode += 1

                converted, converted_count = convert_v2_to_v1(reference_encoded.read_bytes())
                if converted_count:
                    converted_path = temp / f"{name}.v1.lzfse"
                    converted_path.write_bytes(converted)
                    converted_output = temp / f"{name}.v1.out"
                    run(
                        args.cli,
                        "decode-lzfse-file",
                        converted_path,
                        converted_output,
                        len(payload),
                    )
                    if converted_output.read_bytes() != payload:
                        raise AssertionError(f"Vort rejected V1 conversion for {name}")
                    apple_v1_output = temp / f"{name}.v1-apple.out"
                    run(reference, "-decode", "-i", converted_path, "-o", apple_v1_output)
                    if apple_v1_output.read_bytes() != payload:
                        raise AssertionError(f"Apple rejected V1 conversion for {name}")
                    v1_cases += converted_count
                    if v2_for_malformed is None:
                        v2_for_malformed = reference_encoded

        assert valid_for_malformed is not None
        expect_failure(
            args.cli,
            "decode-lzfse-file",
            valid_for_malformed,
            temp / "limited.out",
            1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        malformed_cases = [
            ("bad-magic", b"nope", "InvalidMagic"),
            ("missing-end", valid_for_malformed.read_bytes()[:-4], "TruncatedFrame"),
            ("trailing", valid_for_malformed.read_bytes() + b"x", "TrailingData"),
            (
                "bad-lzvn-distance",
                MAGIC_LZVN
                + struct.pack("<II", 1, 9)
                + bytes((0xF1, 0x06, 0, 0, 0, 0, 0, 0, 0))
                + MAGIC_END,
                "InvalidLzvnStream",
            ),
        ]
        for name, data, error_name in malformed_cases:
            path = temp / f"{name}.lzfse"
            path.write_bytes(data)
            expect_failure(
                args.cli,
                "decode-lzfse-file",
                path,
                temp / f"{name}.out",
                1024 * 1024,
                error_name=error_name,
            )
            malformed += 1
        if v2_for_malformed is not None:
            corrupt = bytearray(v2_for_malformed.read_bytes())
            corrupt[32] ^= 0xFF
            path = temp / "corrupt-v2.lzfse"
            path.write_bytes(corrupt)
            expect_failure(
                args.cli,
                "decode-lzfse-file",
                path,
                temp / "corrupt-v2.out",
                512 * 1024 * 1024,
            )
            malformed += 1

    if vort_kind_counts["v1"] + vort_kind_counts["v2"] == 0:
        raise AssertionError("Vort writer produced no real FSE blocks")
    if args.report:
        reference_git = run("git", "-C", reference.parent, "rev-parse", "HEAD", check=False) if reference else None
        source_paths = [ROOT / "src/lzfse.zig", *sorted((ROOT / "src/lzfse").rglob("*.zig")),
                        Path(__file__).resolve(), ROOT / "tools/lzfse/apple_status_probe.c"]
        report = {"schema": "vort-lzfse-cli-diff-v2",
                  "claim": "functional interoperability and deterministic wire sizes; no throughput claim",
                  "created_utc": datetime.now(timezone.utc).isoformat(),
                  "repository_commit": run("git", "rev-parse", "HEAD").stdout.decode().strip(),
                  "cli_sha256": hashlib.sha256(args.cli.read_bytes()).hexdigest(),
                  "reference_probe_sha256": hashlib.sha256(reference.read_bytes()).hexdigest() if reference else None,
                  "apple_status_probe_sha256": apple_status_sha256,
                  "reference_git": reference_git.stdout.decode().strip() if reference_git and reference_git.returncode == 0 else None,
                  "source_sha256": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in source_paths},
                  "vort_blocks": vort_kind_counts, "reference_blocks": kind_counts, "rows": rows}
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(
        f"self_cases={self_cases} lzfse={reference is not None} "
        f"external_encode={external_encode} external_decode={external_decode} "
        f"v1_cases={v1_cases} malformed={malformed} "
        f"vort_fse_blocks={vort_kind_counts['v1'] + vort_kind_counts['v2']} "
        f"vort_kinds=raw:{vort_kind_counts['raw']},lzvn:{vort_kind_counts['lzvn']},"
        f"v1:{vort_kind_counts['v1']},v2:{vort_kind_counts['v2']} "
        f"kinds=raw:{kind_counts['raw']},lzvn:{kind_counts['lzvn']},"
        f"v1:{kind_counts['v1']},v2:{kind_counts['v2']}"
    )


if __name__ == "__main__":
    main()
