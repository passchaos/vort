#!/usr/bin/env python3
"""Independent Bzip2 CRC-before-publication, cursor replay and memory checks."""
import argparse
import bz2
from contextlib import nullcontext
import ctypes
import ctypes.util
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import random
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BLOCK_MAGIC = 0x314159265359
END_MAGIC = 0x177245385090
RANDOMIZED = bytes.fromhex("425a68313141592653597d0435b980077dc10000186000200050669a052534e42abb456c0d8856d02af5555da546c026d2ab6a889f1772453850907d0435b9")


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def run(*args):
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"command failed: {' '.join(map(str, args))}\n{result.stderr.decode(errors='replace')}")
    return result


def layout(data):
    bits = "".join(f"{byte:08b}" for byte in data)
    blocks = [match.start() for match in re.finditer(f"{BLOCK_MAGIC:048b}", bits)]
    ends = [match.start() for match in re.finditer(f"{END_MAGIC:048b}", bits)]
    return {"block_bits": blocks, "end_bits": ends, "nonbyte_blocks": sum(position % 8 != 0 for position in blocks)}


def replace_bits(data, offset, width, value):
    output = bytearray(data)
    for bit in range(width):
        position = offset + bit
        mask = 1 << (7 - position % 8)
        output[position // 8] = (output[position // 8] & ~mask) | (mask if value & (1 << (width - 1 - bit)) else 0)
    return bytes(output)


def read_bits(data, offset, width):
    result = 0
    for bit in range(width):
        position = offset + bit
        result = (result << 1) | ((data[position // 8] >> (7 - position % 8)) & 1)
    return result


def prepare(directory, bzip2):
    rng = random.Random(0xB2122026)
    text = b"Bzip2 transformed links replay caller output after block CRC.\n" * 4000
    json_data = b"\n".join(f'{{"id":{i},"kind":"bzip2","bucket":{i % 31}}}'.encode() for i in range(5000))
    families = {"empty": b"", "tiny": b"abc", "text": text, "json": json_data,
                "random": rng.randbytes(130001), "pattern": bytes(range(251)) * 801,
                "runs": b"A" * 600000 + b"B" * 10003 + b"tail", "rle-8m": b"R" * (8 * 1024 * 1024)}
    cases = []
    def add(name, encoded, expected, reference):
        require(bz2.decompress(encoded) == expected, (name, "system bz2 reference"))
        source, plaintext = directory / f"corpus-{len(cases)}.bz2", directory / f"corpus-{len(cases)}.plain"
        source.write_bytes(encoded)
        plaintext.write_bytes(expected)
        require(run(bzip2, "-d", "-c", source).stdout == expected, (name, "bzip2 CLI reference"))
        cases.append({"name": name, "input": source.name, "expected": plaintext.name,
                      "input_bytes": len(encoded), "expected_bytes": len(expected), "input_sha256": digest(encoded),
                      "expected_sha256": digest(expected), "reference": reference, "layout": layout(encoded)})
    for name, payload in families.items():
        for level in (1, 9):
            add(f"{name}-level{level}", bz2.compress(payload, compresslevel=level), payload, f"Python bz2 level{level}")
    payload = b"Q" * (40 * 1024 * 1024)
    add("rle-40m-level9", bz2.compress(payload, compresslevel=9), payload, "Python bz2 level9")
    add("legacy-randomized", RANDOMIZED, b"a\n" * 2500, "pinned bzip2 0.1 randomized fixture from tools/bzip2/diff.py")
    multi = random.Random(17).randbytes(200123)
    add("multiblock-unaligned", bz2.compress(multi, compresslevel=1), multi, "Python bz2 level1")
    require(cases[-1]["layout"]["nonbyte_blocks"] > 0 and len(cases[-1]["layout"]["block_bits"]) > 1,
            "reference corpus must exercise non-byte-aligned next block")
    manifest = {"schema": "vort-bzip2-independent-corpus-v1", "reference_only": True,
                "created_utc": datetime.now(timezone.utc).isoformat(), "cases": cases}
    (directory / "corpus.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--prepared-dir", type=Path)
    parser.add_argument("--bzip2", type=Path, default=Path(shutil.which("bzip2") or "bzip2"))
    parser.add_argument("--zig", type=Path, default=Path("/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig"))
    parser.add_argument("--report", type=Path)
    parser.add_argument("--work-dir", type=Path)
    args = parser.parse_args()
    require(args.prepare_only or args.probe, "--probe is required unless --prepare-only")
    require(not args.prepare_only or args.work_dir, "--prepare-only requires persistent --work-dir")
    if args.work_dir:
        args.work_dir = args.work_dir.resolve()
        args.work_dir.mkdir(parents=True, exist_ok=True)
        require(not any(args.work_dir.iterdir()), "--work-dir must be empty")
    workspace = nullcontext(str(args.work_dir)) if args.work_dir else tempfile.TemporaryDirectory(prefix="vort-bzip2-contracts-")
    with workspace as workspace_path:
        temp = Path(workspace_path)
        corpus_dir = args.prepared_dir.resolve() if args.prepared_dir else temp
        cases = json.loads((corpus_dir / "corpus.json").read_text())["cases"] if args.prepared_dir else prepare(temp, args.bzip2)
        if args.prepare_only:
            print(f"bzip2_reference_corpus={len(cases)} prepare_only=true native_validation=false path={temp}")
            return
        args.probe = args.probe.resolve()
        rows = []
        def check(name, encoded, expected, pattern="mixed", **options):
            index = len(rows)
            paths = [temp / f"case-{index}-{suffix}" for suffix in ("input", "expected", "output", "config.json")]
            paths[0].write_bytes(encoded)
            paths[1].write_bytes(expected)
            config = {"pattern": pattern, **options}
            paths[3].write_text(json.dumps(config) + "\n")
            stats = json.loads(run(args.probe, *paths).stdout)
            require(paths[2].read_bytes() == expected[:stats["output_written"]], (name, "published plaintext prefix"))
            require(stats["max_decoded_capacity"] == 0, (name, "library must not retain plaintext block"))
            require(stats["peak_working_bytes"] <= options.get("max_working_memory", (1 << 64) - 1), (name, "working quota"))
            if options.get("expected_error"):
                require(stats["error"] == options["expected_error"], (name, "exact error", stats))
            elif options.get("expect_failure"):
                require(stats["error"] is not None, (name, "malformed input accepted"))
            else:
                require(stats["error"] is None and paths[2].read_bytes() == expected, (name, "complete decode"))
                require(stats["one_shot_verified"], (name, "shared one-shot cursor parity"))
            require(stats["input_read"] == stats["snapshot"]["input_read"] and stats["output_written"] == stats["snapshot"]["output_written"],
                    (name, "snapshot counts"))
            rows.append({"case_index": index, "case": name, "config": config, "input_bytes": len(encoded),
                         "expected_bytes": len(expected), "input_sha256": digest(encoded), "expected_sha256": digest(expected),
                         "output_sha256": digest(paths[2].read_bytes()), **stats})
            return stats
        loaded = {}
        for case in cases:
            encoded, expected = (corpus_dir / case["input"]).read_bytes(), (corpus_dir / case["expected"]).read_bytes()
            require(digest(encoded) == case["input_sha256"] and digest(expected) == case["expected_sha256"], "prepared corpus integrity")
            loaded[case["name"]] = encoded, expected, case["layout"]
            patterns = ("wide_zero",) if len(expected) > 1024 * 1024 else ("one", "mixed", "wide_zero")
            for pattern in patterns:
                stats = check(case["name"], encoded, expected, pattern)
                if expected:
                    require(stats["first_output_validated_bytes"] > 0, (case["name"], "block validated before publication"))
                    require(stats["first_output_input_offset"] * 8 >= case["layout"]["block_bits"][0] + 80,
                            (case["name"], "CRC field reached before first output"))
            print(f"bzip2 {case['name']} checks={len(rows)} reference=ok", flush=True)
        for name in ("rle-8m-level9", "rle-40m-level9"):
            encoded, expected, _ = loaded[name]
            stats = check(f"{name}-5m-work", encoded, expected, "wide_zero", max_working_memory=5 * 1024 * 1024)
            require(stats["max_transformed_capacity"] <= 900000 and stats["max_links_capacity"] <= 3600000,
                    (name, "format-bounded BWT memory"))
        for name in ("tiny-level1", "text-level1", "legacy-randomized"):
            encoded, expected, _ = loaded[name]
            check(f"{name}-reset", encoded, expected, reset_after=True)
            check(f"{name}-reconfigure", encoded, expected, reconfigure=True)
            check(f"{name}-move", encoded, expected, move_active=True)
            check(f"{name}-limits", encoded, expected, check_limits=True)
            check(f"{name}-OOM", encoded, expected, oom=True)
        for name in ("tiny-level1", "rle-8m-level9"):
            encoded, expected, positions = loaded[name]
            damaged_crc = replace_bits(encoded, positions["block_bits"][0] + 48, 1,
                                       read_bits(encoded, positions["block_bits"][0] + 48, 1) ^ 1)
            result = check(f"{name}-block-CRC", damaged_crc, expected, "wide_zero", expected_error="ChecksumMismatch")
            require(result["output_written"] == 0, (name, "bad block must publish nothing"))
            combined_crc = replace_bits(encoded, positions["end_bits"][-1] + 48, 1,
                                        read_bits(encoded, positions["end_bits"][-1] + 48, 1) ^ 1)
            result = check(f"{name}-combined-CRC", combined_crc, expected, "wide_zero", expected_error="ChecksumMismatch")
            require(result["output_written"] == len(expected), (name, "combined CRC arrives after validated block output"))
        encoded, expected, positions = loaded["multiblock-unaligned"]
        second = positions["block_bits"][1]
        partial = bz2.BZ2Decompressor()
        first_parts = [partial.decompress(encoded[:(second + 7) // 8])]
        while not partial.eof:
            drained = partial.decompress(b"")
            if not drained:
                break
            first_parts.append(drained)
        first_plaintext = b"".join(first_parts)
        require(first_plaintext and expected.startswith(first_plaintext), "independent first block plaintext")
        corrupt = replace_bits(encoded, second + 48, 1, read_bits(encoded, second + 48, 1) ^ 1)
        result = check("second-block-CRC-preserves-first", corrupt, expected, "wide_zero", expected_error="ChecksumMismatch")
        require(result["output_written"] == len(first_plaintext), "second block CRC must preserve only first block")
        first, first_data, _ = loaded["tiny-level1"]
        second, second_data, _ = loaded["json-level9"]
        concatenated = first + second
        check("concatenated", concatenated, first_data + second_data)
        check("stop-next-concatenated", concatenated, first_data + second_data, "wide_zero", stop_next=True)
        check("concatenated-limit", concatenated, first_data + second_data, "wide_zero", stop_next=True,
              max_output_len=len(first_data) + len(second_data) - 1, expected_error="OutputLimitExceeded")
        check("opaque-suffix-stop", first + b"opaque outer suffix", first_data, "wide_zero", stop_only=True,
              first_stream_retry_granularity=12)
        check("exact-output-and-pledge", first, first_data, max_output_len=len(first_data), expected_output_len=len(first_data))
        check("below-output-limit", first, first_data, max_output_len=len(first_data) - 1, expected_error="OutputLimitExceeded")
        check("below-decoded-block-limit", first, first_data, max_decoded_block_len=len(first_data) - 1,
              expected_error="OutputLimitExceeded")
        check("zero-compressed-block-limit", first, first_data, max_compressed_block_len=0, expected_error="OutputLimitExceeded")
        check("zero-working-limit", first, first_data, max_working_memory=0, expected_error="WorkingMemoryLimitExceeded")
        check("wrong-pledged-length", first, first_data, expected_output_len=len(first_data) + 1, expected_error="SizeMismatch")
        check("missing-footer", first[:-2], first_data, expected_error="TruncatedFrame")
        check("truncated-header", b"BZh", b"", expected_error="TruncatedFrame")
        check("invalid-header", b"BZh0", b"", expected_error="InvalidBzip2Header")
        check("invalid-marker", replace_bits(first, 32, 48, 0), first_data, expect_failure=True)
        check("invalid-primary-index", replace_bits(first, 113, 24, (1 << 24) - 1), first_data, expect_failure=True)
        bitmap = read_bits(first, 137, 16)
        groups = 153 + bitmap.bit_count() * 16
        check("invalid-groups", replace_bits(first, groups, 3, 7), first_data, expect_failure=True)
        check("invalid-selectors", replace_bits(first, groups + 3, 15, 0), first_data, expect_failure=True)
        selector_count = read_bits(first, groups + 3, 15)
        code_length_offset = groups + 18
        for _ in range(selector_count):
            while read_bits(first, code_length_offset, 1):
                code_length_offset += 1
            code_length_offset += 1
        check("invalid-Huffman-length", replace_bits(first, code_length_offset, 5, 31), first_data,
              expected_error="InvalidHuffmanCode")
        check("unrecognized-suffix", first + b"invalid!", first_data, expect_failure=True)
        library = ctypes.CDLL(ctypes.util.find_library("bz2"))
        library.BZ2_bzlibVersion.restype = ctypes.c_char_p
        reference_version = library.BZ2_bzlibVersion().decode()
        maps = Path("/proc/self/maps").read_text().splitlines()
        reference_path = next(Path(line.split()[-1]).resolve() for line in maps if "/libbz2.so" in line)
        cpu = re.search(r"^model name\s*:\s*(.+)$", Path("/proc/cpuinfo").read_text(), re.MULTILINE)
        report = {"schema": "vort-bzip2-stream-contracts-v1", "claim": "independent wire/CRC/publication/progress/memory correctness; no throughput claim",
                  "created_utc": datetime.now(timezone.utc).isoformat(), "cpu": cpu.group(1) if cpu else platform.processor(),
                  "platform": platform.platform(), "invocation": sys.argv, "python_version": sys.version,
                  "reference_version": reference_version, "reference_library": str(reference_path),
                  "reference_library_sha256": digest(reference_path.read_bytes()), "bzip2_sha256": digest(args.bzip2.resolve().read_bytes()),
                  "zig_version": run(args.zig, "version").stdout.decode().strip(), "zig_sha256": digest(args.zig.read_bytes()),
                  "probe_build": "Zig ReleaseFast independent bzip2 module", "probe_sha256": digest(args.probe.read_bytes()),
                  "memory_scope": "decoder-owned allocations; caller expected/output buffers excluded",
                  "repository_commit": run("git", "rev-parse", "HEAD").stdout.decode().strip(),
                  "source_sha256": {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in
                                    [ROOT / "src/bzip2.zig", ROOT / "src/core.zig", ROOT / "src/io/working_allocator.zig",
                                     *sorted((ROOT / "src/bzip2").rglob("*.zig")), ROOT / "tools/bzip2/stream_contract_probe.zig", Path(__file__).resolve()]},
                  "corpus": cases, "rows": rows}
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(f"bzip2_contract_cases={len(rows)} corpus={len(cases)} libbz2={reference_version} "
              f"CRC_errors={sum(row['error'] == 'ChecksumMismatch' for row in rows)} "
              f"OOM={sum(row['oom_failures'] for row in rows)} resource={sum(row['resource_checks'] for row in rows)}")


if __name__ == "__main__":
    main()
