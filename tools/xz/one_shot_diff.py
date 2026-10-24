#!/usr/bin/env python3
"""Independent bounded XZ one-shot prepass/replay, reuse and caller guards."""
import argparse
from contextlib import nullcontext
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import lzma
from pathlib import Path
import platform
import random
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("xz_progressive_recipes", ROOT / "tools/xz/progressive_diff.py")
recipes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recipes)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def run(*args, input=None):
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, capture_output=True, input=input)
    if result.returncode:
        raise RuntimeError(f"command failed: {' '.join(map(str, args))}\n{result.stderr.decode(errors='replace')}")
    return result


def prepare(directory, xz, seven_zip):
    require(seven_zip.exists(), "modern 7-Zip is required for all eight BCJ filters")
    rng = random.Random(0x15A0726)
    text = b"XZ one-shot validate all members before replay into caller storage.\n" * 1500
    json_data = b"\n".join(f'{{"id":{i},"kind":"workspace","bucket":{i % 31}}}'.encode() for i in range(1300))
    families = {"empty": b"", "tiny": b"abc", "text": text, "json": json_data,
                "random": rng.randbytes(75001), "repeat-8m": b"R" * (8 * 1024 * 1024)}
    cases, commands = [], []
    def add(name, encoded, expected, reference="Python liblzma", concatenated=False, modern=False):
        if not modern:
            actual = run(xz, "--decompress", "--stdout", input=encoded).stdout if concatenated or encoded.endswith(bytes(4)) else lzma.decompress(encoded)
            require(actual == expected, (name, "independent liblzma/XZ output"))
        source, plain = directory / f"corpus-{len(cases)}.xz", directory / f"corpus-{len(cases)}.plain"
        source.write_bytes(encoded)
        plain.write_bytes(expected)
        cases.append({"name": name, "input": source.name, "expected": plain.name, "concatenated": concatenated,
                      "input_bytes": len(encoded), "expected_bytes": len(expected), "input_sha256": digest(encoded),
                      "expected_sha256": digest(expected), "reference": reference})
    for name, data in families.items():
        for check in (lzma.CHECK_NONE, lzma.CHECK_CRC32, lzma.CHECK_CRC64, lzma.CHECK_SHA256):
            add(f"{name}-check{check}", lzma.compress(data, check=check,
                filters=[{"id": lzma.FILTER_LZMA2, "dict_size": 65536}]), data)
    filter_cases = [
        ("delta", [{"id": lzma.FILTER_DELTA, "dist": 7}], bytes(range(251)) * 100),
        ("x86", [{"id": lzma.FILTER_X86, "start_offset": 4096}], bytes.fromhex("90e81000000090e9f0ffffff") * 1000),
        ("powerpc", [{"id": lzma.FILTER_POWERPC}], bytes.fromhex("480000014bfffffd") * 1000),
        ("ia64", [{"id": lzma.FILTER_IA64}], bytes.fromhex("1600000000a000000000000000000000") * 700),
        ("arm", [{"id": lzma.FILTER_ARM}], bytes.fromhex("040000ebfcffffeb") * 1000),
        ("arm-thumb", [{"id": lzma.FILTER_ARMTHUMB}], bytes.fromhex("00f000f8fff7ffff") * 1000),
        ("sparc", [{"id": lzma.FILTER_SPARC}], bytes.fromhex("400000007fffffff") * 1000),
        ("x86-delta", [{"id": lzma.FILTER_X86}, {"id": lzma.FILTER_DELTA, "dist": 4}], text[:16000]),
        ("delta-x86", [{"id": lzma.FILTER_DELTA, "dist": 4}, {"id": lzma.FILTER_X86}], text[:16000]),
        ("delta256-delta", [{"id": lzma.FILTER_DELTA, "dist": 256}, {"id": lzma.FILTER_DELTA, "dist": 7}], text[:16000]),
    ]
    for name, filters, data in filter_cases:
        add(f"filter-{name}", lzma.compress(data, filters=filters + [{"id": lzma.FILTER_LZMA2, "dict_size": 65536}]), data)
    for name, data in (("ARM64", bytes.fromhex("0000009400000090") * 1000),
                       ("RISCV", bytes.fromhex("ef0000001300000097010000e7800100") * 700)):
        source, archive = directory / name, directory / f"{name}.xz"
        source.write_bytes(data)
        command = [seven_zip, "a", "-txz", f"-mf={name}", "-mx=1", "-md=64k", archive, source]
        run(*command)
        extract = [seven_zip, "x", "-so", "-bd", archive]
        require(run(*extract).stdout == data, (name, "modern reference round trip"))
        commands.extend([[str(value) for value in args] for args in (command, extract)])
        add(f"filter-{name.lower()}", archive.read_bytes(), data, "7-Zip 26.02", modern=True)
    for lc, lp, pb in ((0, 0, 0), (4, 0, 4), (0, 4, 1), (2, 2, 3)):
        raw = recipes.raw_encode(text[:8192], lc, lp, pb)
        add(f"declared-properties-{lc}-{lp}-{pb}", recipes.xz_wrap(raw, text[:8192]), text[:8192], "liblzma-validated header recipe")
    stored = rng.randbytes(70001)
    add("stored-declared", recipes.xz_wrap(recipes.stored_raw(stored), stored), stored, "liblzma-validated stored recipe")
    source = directory / "multi-input"
    mixed = text[:30000] + rng.randbytes(75001) + json_data
    source.write_bytes(mixed)
    command = [xz, "--compress", "--stdout", "--check=crc64", "--block-size=16384", "--lzma2=dict=64KiB", source]
    archive = run(*command).stdout
    commands.append([str(value) for value in command])
    add("multiblock", archive, mixed, "XZ Utils --block-size=16384")
    first = lzma.compress(text[:8192], check=lzma.CHECK_CRC32, filters=[{"id": lzma.FILTER_LZMA2, "dict_size": 65536}])
    second = lzma.compress(json_data, check=lzma.CHECK_SHA256, filters=[{"id": lzma.FILTER_LZMA2, "dict_size": 65536}])
    add("concatenated-padding", first + bytes(4) + second + bytes(4), text[:8192] + json_data, concatenated=True)
    add("single-padding", first + bytes(4), text[:8192])
    manifest = {"schema": "vort-xz-bounded-one-shot-corpus-v1", "reference_only": True,
                "created_utc": datetime.now(timezone.utc).isoformat(), "cases": cases, "commands": commands}
    (directory / "corpus.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--baseline-probe", type=Path)
    parser.add_argument("--baseline-source", type=Path, default=ROOT / "tools/one_shot/legacy_probe.zig")
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--prepared-dir", type=Path)
    parser.add_argument("--xz", type=Path, default=Path(shutil.which("xz") or "xz"))
    parser.add_argument("--seven-zip", type=Path, default=Path("/tmp/vort-7zip-26.02.21l9nV/7zz"))
    parser.add_argument("--zig", type=Path, default=Path("/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig"))
    parser.add_argument("--report", type=Path)
    parser.add_argument("--work-dir", type=Path)
    args = parser.parse_args()
    require(args.prepare_only or args.probe, "--probe is required unless --prepare-only")
    require(not args.prepare_only or args.work_dir, "--prepare-only needs persistent --work-dir")
    if args.work_dir:
        args.work_dir = args.work_dir.resolve()
        args.work_dir.mkdir(parents=True, exist_ok=True)
        require(not any(args.work_dir.iterdir()), "--work-dir must be empty")
    workspace = nullcontext(str(args.work_dir)) if args.work_dir else tempfile.TemporaryDirectory(prefix="vort-xz-one-shot-")
    with workspace as directory:
        temp = Path(directory)
        corpus_dir = args.prepared_dir.resolve() if args.prepared_dir else temp
        manifest = json.loads((corpus_dir / "corpus.json").read_text()) if args.prepared_dir else prepare(temp, args.xz, args.seven_zip)
        if args.prepare_only:
            print(f"xz_reference_corpus={len(manifest['cases'])} prepare_only=true native_validation=false path={temp}")
            return
        args.probe = args.probe.resolve()
        rows, loaded = [], {}
        def check(name, encoded, expected, concatenated=False, **options):
            index = len(rows)
            paths = [temp / f"case-{index}-{suffix}" for suffix in ("input", "expected", "output", "config.json")]
            paths[0].write_bytes(encoded)
            paths[1].write_bytes(expected)
            config = {"concatenated": concatenated, **options}
            paths[3].write_text(json.dumps(config) + "\n")
            stats = json.loads(run(args.probe, *paths).stdout)
            if args.baseline_probe and len(expected) <= 256 * 1024 and options.get("max_working_memory", (1 << 64) - 1) == (1 << 64) - 1 and options.get("max_dictionary_size", 65536) == 65536 and not options.get("borrowed_alias"):
                capacity = len(expected) - int(options.get("short_output", False))
                baseline_into = temp / f"baseline-{index}-into.json"
                baseline_size = temp / f"baseline-{index}-size.json"
                into_mode, size_mode = ("concat-into", "concat-size") if concatenated else ("into", "size")
                run(args.baseline_probe, into_mode, paths[0], len(expected), 65536, capacity, baseline_into)
                size_capacity = min(capacity, options.get("max_output_len", capacity))
                run(args.baseline_probe, size_mode, paths[0], len(expected), 65536, size_capacity, baseline_size)
                old_into, old_size = json.loads(baseline_into.read_text()), json.loads(baseline_size.read_text())
                if "max_output_len" not in options:
                    require(old_into["error"] == stats["error"], (name, "pre-change Into error ordering", old_into, stats))
                    if old_into["error"] is None:
                        old_hash = bytes(old_into["decoded_sha256"]).decode() if isinstance(old_into["decoded_sha256"], list) else old_into["decoded_sha256"]
                        require(old_into["count"] == len(expected) and old_hash == digest(expected), (name, "pre-change output"))
                    else:
                        require(old_into["unchanged"], (name, "pre-change caller protection"))
                require(old_size["error"] == stats["limited_size_error"], (name, "pre-change size error ordering", old_size, stats))
                stats["baseline_into"] = old_into
                stats["baseline_size"] = old_size
            if options.get("expected_error") or options.get("expect_failure"):
                require(stats["error"] is not None and stats["caller_unchanged"], (name, "late error must preserve caller output"))
                if options.get("expected_error"):
                    require(stats["error"] == options["expected_error"], (name, "exact error", stats))
            else:
                require(stats["error"] is None and paths[2].read_bytes() == expected, (name, "decode equality"))
                require(stats["legacy_into_verified"] and stats["size_verified"] and stats["warm_no_alloc_verified"],
                        (name, "legacy/size/reuse validation"))
            rows.append({"case_index": index, "case": name, "config": config, "input_bytes": len(encoded),
                         "expected_bytes": len(expected), "input_sha256": digest(encoded), "expected_sha256": digest(expected),
                         "output_sha256": digest(paths[2].read_bytes()), **stats})
            return stats
        for case in manifest["cases"]:
            encoded = (corpus_dir / case["input"]).read_bytes()
            expected = (corpus_dir / case["expected"]).read_bytes()
            require(digest(encoded) == case["input_sha256"] and digest(expected) == case["expected_sha256"], "prepared corpus hashes")
            loaded[case["name"]] = encoded, expected, case["concatenated"]
            check(case["name"], encoded, expected, case["concatenated"])
            print(f"xz bounded one-shot {case['name']} cases={len(rows)} reference=ok", flush=True)
        for name in ("tiny-check1", "text-check4", "filter-x86-delta", "multiblock", "concatenated-padding"):
            encoded, expected, concatenated = loaded[name]
            check(f"{name}-budget", encoded, expected, concatenated, check_limits=True)
            check(f"{name}-OOM", encoded, expected, concatenated, oom=True)
        for name in ("tiny-check1", "text-check4", "random-check4", "multiblock", "concatenated-padding"):
            encoded, expected, concatenated = loaded[name]
            check(f"{name}-alias", encoded, expected, concatenated, alias=True)
        encoded, expected, _ = loaded["text-check4"]
        check("borrowed-prepare-replay-alias-rejected", encoded, expected, borrowed_alias=True, expected_error="InvalidBlockPlan")
        encoded, expected, _ = loaded["repeat-8m-check4"]
        check("8MiB-plain-256KiB-work", encoded, expected, max_working_memory=256 * 1024)
        encoded, expected, _ = loaded["empty-check0"]
        check("empty-zero-work", encoded, expected, max_working_memory=0)
        encoded, expected, _ = loaded["text-check4"]
        check("dictionary-limit-not-caller-limit", encoded, expected, max_dictionary_size=4096, expected_error="OutputLimitExceeded")
        check("working-memory-zero", encoded, expected, max_working_memory=0, expected_error="WorkingMemoryLimitExceeded")
        chunks = recipes.xz_chunks(encoded)
        payload_end = chunks[-1]["end"] + 1
        check_start = payload_end + (-(payload_end - chunks[0]["start"]) % 4)
        damaged = bytearray(encoded)
        damaged[check_start] ^= 1
        check("late-block-CRC", bytes(damaged), expected, expected_error="ChecksumMismatch")
        check("late-block-CRC-short-caller", bytes(damaged), expected, short_output=True, expect_failure=True)
        damaged = bytearray(encoded)
        damaged[-13] ^= 1
        check("late-Index-CRC", bytes(damaged), expected, expected_error="ChecksumMismatch")
        damaged = bytearray(encoded)
        damaged[-12] ^= 1
        check("late-Footer-CRC", bytes(damaged), expected, expected_error="ChecksumMismatch")
        check("trailing-byte", encoded + b"x", expected, expected_error="TrailingData")
        check("truncated-Footer", encoded[:-2], expected, expected_error="TruncatedFrame")
        check("undersized-caller", encoded, expected, short_output=True, expected_error="OutputTooSmall")
        check("output-limit", encoded, expected, max_output_len=len(expected) - 1, expected_error="OutputLimitExceeded")
        raw = recipes.raw_encode(expected)
        check("Index-size-mismatch-valid-CRC", recipes.xz_wrap(raw, expected, index_delta=1), expected, expect_failure=True)
        damaged = bytearray(encoded)
        backward = int.from_bytes(damaged[-8:-4], "little")
        damaged[-8:-4] = struct.pack("<I", backward + 1)
        damaged[-12:-8] = struct.pack("<I", zlib.crc32(damaged[-8:-2]))
        check("Footer-backward-size-valid-CRC", bytes(damaged), expected, expect_failure=True)
        first, _, _ = loaded["tiny-check1"]
        check("bad-second-member-preserves-first-caller", first + bytes(damaged), b"abc" + expected, True, expect_failure=True)
        cpu = re.search(r"^model name\s*:\s*(.+)$", Path("/proc/cpuinfo").read_text(), re.MULTILINE)
        report = {"schema": "vort-xz-bounded-one-shot-v1", "claim": "independent wire/prepass/replay/reuse/progress/memory correctness; no throughput claim",
                  "created_utc": datetime.now(timezone.utc).isoformat(), "cpu": cpu.group(1) if cpu else platform.processor(),
                  "platform": platform.platform(), "invocation": sys.argv, "python_version": sys.version,
                  "python_sha256": digest(Path(sys.executable).read_bytes()), "lzma_module_origin": lzma.__spec__.origin,
                  "xz_version": run(args.xz, "--version").stdout.decode().strip(), "xz_sha256": digest(args.xz.resolve().read_bytes()),
                  "seven_zip_version": run(args.seven_zip, "i").stdout.decode().splitlines()[1],
                  "seven_zip_sha256": digest(args.seven_zip.read_bytes()), "zig_version": run(args.zig, "version").stdout.decode().strip(),
                  "zig_sha256": digest(args.zig.read_bytes()), "probe_sha256": digest(args.probe.read_bytes()),
                  "baseline_probe_sha256": digest(args.baseline_probe.read_bytes()) if args.baseline_probe else None,
                  "baseline_revision": "4d0a93f0" if args.baseline_probe else None,
                  "baseline": {"path": str(args.baseline_probe.resolve()), "source": str(args.baseline_source.resolve()),
                               "source_sha256": digest(args.baseline_source.read_bytes()), "binary_sha256": digest(args.baseline_probe.read_bytes()),
                               "revision": "4d0a93f0", "build": "Zig 0.16.0 ReleaseSafe",
                               "protocol": "BINARY MODE INPUT EXPECTED DICTIONARY OUTPUT_CAPACITY REPORT_JSON"} if args.baseline_probe else None,
                  "memory_scope": "workspace-owned allocations; caller output and convenience returned output excluded",
                  "repository_commit": run("git", "rev-parse", "HEAD").stdout.decode().strip(), "corpus": manifest,
                  "source_sha256": {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in
                                    [ROOT / "src/xz.zig", ROOT / "src/core.zig", ROOT / "src/io/working_allocator.zig",
                                     *sorted((ROOT / "src/xz").rglob("*.zig")), *sorted((ROOT / "src/lzma").rglob("*.zig")),
                                     ROOT / "tools/xz/progressive_diff.py", ROOT / "tools/xz/one_shot_probe.zig", Path(__file__).resolve()]},
                  "rows": rows}
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(f"xz_bounded_one_shot_cases={len(rows)} corpus={len(manifest['cases'])} "
              f"warm_noalloc={sum(row['warm_no_alloc_verified'] for row in rows)} OOM={sum(row['oom_failures'] for row in rows)}")


if __name__ == "__main__":
    main()
