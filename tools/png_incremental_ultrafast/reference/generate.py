#!/usr/bin/env python3
"""Generate only full-write fdeflate expectations; validate with system zlib."""
from __future__ import annotations

import datetime
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys
import zlib

WORK = Path(__file__).resolve().parent
REFERENCE = Path("/home/passchaos/Work/fdeflate")
PIN = "a713d02c560526c82e2b97519ed6720bdbc8a47a"
OWNER = Path("/nav_env/Temp/vort-png-incremental-ultrafast-reference")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def run(args: list[str], cwd: Path, source: bytes | None = None) -> bytes:
    result = subprocess.run(args, cwd=cwd, input=source, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise RuntimeError(f"command failed: {args}\n{result.stderr.decode(errors='replace')}")
    return result.stdout


def clean_reference() -> None:
    if run(["git", "rev-parse", "HEAD"], REFERENCE).decode().strip() != PIN:
        raise RuntimeError("reference HEAD mismatch")
    if run(["git", "status", "--porcelain"], REFERENCE):
        raise RuntimeError("reference must be clean")


def reference_hashes() -> dict[str, str]:
    paths = run(["git", "ls-files", "-z"], REFERENCE).decode().split("\0")
    return {p: sha((REFERENCE / p).read_bytes()) for p in paths if p == "Cargo.toml" or p.startswith("src/")}


def cases() -> list[dict]:
    result = []
    def add(name: str, group: str, source: bytes, **details) -> None:
        cuts = sorted({v for v in (1, 2, 3, 7, 8, 9, 15, 16, 17, 255, 256, 257, 258, 259, 515, 516, 599, 600, 4095, 4096, 4097, 4103, 8191, 8192, 8193) if 0 < v < len(source)})
        result.append({"id": name, "group": group, "source": source, "suggested_cuts": cuts, **details})
    lengths = [*range(9), 257, 258, 259, 516, 600, 4095, 4096, 4097, 4103, 8192, 8193, 10000]
    for n in lengths:
        add(f"zero_run_{n}", "zero_run", bytes(n), zero_run_length=n)
        add(f"zero_run_{n}_then_literals", "run_then_literals", bytes(n) + bytes(range(1, 9)), zero_run_length=n)
        add(f"literals_then_zero_run_{n}_then_literals", "literal_run_literal", bytes(range(17, 25)) + bytes(n) + bytes(range(241, 249)), zero_run_length=n)
    # Every legal prefix/suffix-zero combination with at least one nonzero byte.
    for prefix in range(8):
        for suffix in range(8 - prefix):
            word = bytes(prefix) + bytes(range(31, 39 - prefix - suffix)) + bytes(suffix)
            assert len(word) == 8 and any(word)
            for mode, source in (
                ("alone", word),
                ("run_before", bytes(16) + word),
                ("run_after", word + bytes(16) + bytes(range(81, 89))),
                ("run_both", bytes(16) + word + bytes(16) + bytes(range(129, 137))),
            ):
                add(f"word_p{prefix}_s{suffix}_{mode}", "word_prefix_suffix", source,
                    prefix_zeros=prefix, suffix_zeros=suffix, context=mode)
    for tail in range(8):
        add(f"tail_zero_{tail}_after_run", "tails", bytes(32 + tail), tail_length=tail, tail_kind="zeros_after_whole_word_run")
        add(f"tail_literal_{tail}_after_run", "tails", bytes(32) + bytes(range(201, 201 + tail)), tail_length=tail, tail_kind="nonzero_after_whole_word_run")
        add(f"tail_mixed_{tail}_after_literals", "tails", bytes(range(1, 17)) + bytes(0 if i % 2 == 0 else 253 - i for i in range(tail)), tail_length=tail, tail_kind="mixed")
        add(f"tail_zero_{tail}_after_suffix", "tails", bytes([7, 129, 255, 0, 0, 0, 0, 0]) + bytes(tail), tail_length=tail, tail_kind="zero_after_partial_word_run")
    # Large runs cross likely input boundaries at every 8-byte stream alignment.
    for alignment in range(8):
        for n in (4097, 8193):
            source = bytes(range(51, 51 + alignment)) + bytes(n) + bytes(range(171, 180))
            add(f"cross_input_run_{n}_alignment_{alignment}", "cross_input_boundary", source,
                zero_run_length=n, prefix_alignment=alignment, partition_modes=["single", "each_byte", "chunk_7", "chunk_8", "chunk_4096", "suggested_cuts"])
    for b in range(1, 256):
        add(f"literal_single_{b:03d}", "nonzero_single_literal", bytes([b]), literal=b)
    ascending = bytes(range(1, 256))
    permutations = {
        "ascending": ascending,
        "descending": ascending[::-1],
        "odd_then_even": bytes(range(1, 256, 2)) + bytes(range(2, 256, 2)),
        "stride37": bytes((i * 37) % 255 + 1 for i in range(255)),
    }
    for name, source in permutations.items():
        assert sorted(source) == list(range(1, 256))
        add(f"nonzero_permutation_{name}", "nonzero_literal_permutations", source)
    for shift in range(8):
        source = ascending[shift:] + ascending[:shift]
        add(f"nonzero_rotation_{shift}", "nonzero_literal_permutations", source, rotation=shift)
    add("all_byte_literals_ascending", "all_byte_literals", bytes(range(256)))
    add("all_byte_literals_descending", "all_byte_literals", bytes(range(255, -1, -1)))
    for n in (1, 7, 8, 9, 15, 16, 17, 31, 32, 64):
        for label, pattern in ("short", bytes([1, 2, 3, 4, 254, 255])), ("long", bytes([41, 65, 90, 127, 128, 160])):
            source = bytes(pattern[i % len(pattern)] for i in range(n))
            add(f"literal_code_{label}_length_{n}", "literal_code_lengths", source)
    assert len({r["id"] for r in result}) == len(result)
    return result


def main() -> None:
    if WORK != OWNER:
        raise RuntimeError("all helper writes must stay in the owned Temp directory")
    clean_reference()
    frozen = reference_hashes()
    lock_path = REFERENCE / "Cargo.lock"
    original_reference_lock = lock_path.read_bytes() if lock_path.exists() else None
    records = cases()
    protocol = b"".join((r["id"] + "\t" + r["source"].hex() + "\n").encode() for r in records)
    (WORK / "inputs.tsv").write_bytes(protocol)
    run(["cargo", "generate-lockfile", "--offline", "--manifest-path", str(WORK / "Cargo.toml")], WORK)
    build_command = ["cargo", "build", "--offline", "--locked", "--release", "--manifest-path", str(WORK / "Cargo.toml"), "--target-dir", str(WORK / "target")]
    run(build_command, WORK)
    executable = WORK / "target/release/vort-png-incremental-ultrafast-reference"
    observed = run([str(executable)], WORK, protocol)
    repeated = run([str(executable)], WORK, protocol)
    if observed != repeated:
        raise RuntimeError("full-write oracle output is not deterministic")
    rows = [json.loads(line) for line in observed.splitlines()]
    if len(rows) != len(records):
        raise RuntimeError("oracle row count mismatch")
    payload = bytearray()
    for expected_case, row in zip(records, rows):
        source = expected_case["source"]
        if row["id"] != expected_case["id"] or bytes.fromhex(row["source_hex"]) != source or row["write_data_calls"] != 1:
            raise RuntimeError("oracle source/protocol drift")
        compressed = bytes.fromhex(row["expected_hex"])
        decoder = zlib.decompressobj(zlib.MAX_WBITS)
        inflated = decoder.decompress(compressed, len(source) + 1) + decoder.flush()
        if inflated != source or not decoder.eof or decoder.unused_data or decoder.unconsumed_tail:
            raise RuntimeError(f"system zlib independent inflate failed: {row['id']}")
        if int.from_bytes(compressed[-4:], "big") != zlib.adler32(source) & 0xffffffff:
            raise RuntimeError("Adler32 footer mismatch")
        metadata = {k: v for k, v in expected_case.items() if k != "source"}
        final = {**metadata, **row, "source_len": len(source), "expected_len": len(compressed),
                 "source_sha256": sha(source), "expected_sha256": sha(compressed), "system_zlib_inflate": "pass"}
        payload.extend((json.dumps(final, sort_keys=True, separators=(",", ":")) + "\n").encode())
    clean_reference()
    if reference_hashes() != frozen or (lock_path.read_bytes() if lock_path.exists() else None) != original_reference_lock:
        raise RuntimeError("fdeflate source changed during generation")
    (WORK / "rust-output.jsonl").write_bytes(observed)
    (WORK / "fixtures.jsonl").write_bytes(payload)
    grouped = {}
    for r in records:
        grouped[r["group"]] = grouped.get(r["group"], 0) + 1
    owned_files = ["src/main.rs", "generate.py", "Cargo.toml", "Cargo.lock", "inputs.tsv", "rust-output.jsonl", "fixtures.jsonl"]
    manifest = {
        "schema": "vort.png_incremental_ultrafast_fullwrite_reference.v1", "pass": True,
        "generated_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "fdeflate_revision": PIN,
        "fdeflate_root": str(REFERENCE), "fdeflate_clean_before_after": True,
        "fdeflate_reference_lock_preserved": True, "fdeflate_source_sha256": frozen,
        "reference_contract": "Legacy full-write baseline: exactly one UltraFastCompressor::write_data(full_slice), then finish; 8-byte grouping over the complete source and final 0..7 literal tail. Candidate input partitioning must not select split-call fdeflate as an oracle. The new continuable stream framing has separate derived expectations in stream-fixtures.jsonl and stream-manifest.json.",
        "rows": len(rows), "coverage_groups": grouped,
        "source_total_bytes": sum(len(r["source"]) for r in records), "largest_source_bytes": max(len(r["source"]) for r in records),
        "independent_inflate": {"engine": "system Python zlib", "compile_version": zlib.ZLIB_VERSION, "runtime_version": zlib.ZLIB_RUNTIME_VERSION, "checks": "exact original bytes, eof, no unused/unconsumed input, Adler32 footer", "pass_rows": len(rows)},
        "deterministic_repeat": True, "fixture_sha256": sha(payload), "rust_stdout_sha256": sha(observed),
        "compiler": {"rustc": run(["rustc", "--version"], WORK).decode().strip(), "cargo": run(["cargo", "--version"], WORK).decode().strip(), "python": sys.version, "platform": platform.platform()},
        "build_command": build_command, "oracle_binary_sha256": sha(executable.read_bytes()),
        "owned_file_sha256": {p: sha((WORK / p).read_bytes()) for p in owned_files},
    }
    (WORK / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"pass": True, "rows": len(rows), "fixture_sha256": manifest["fixture_sha256"], "rust_stdout_sha256": manifest["rust_stdout_sha256"], "groups": grouped}, sort_keys=True))


if __name__ == "__main__":
    main()
