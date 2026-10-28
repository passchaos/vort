#!/usr/bin/env python3
"""Native old/new/libbz2 one-shot ratio and allocation-inclusive timing evidence."""
from __future__ import annotations

import _bz2
import argparse
import bz2
import csv
import ctypes
import io
import json
import os
import platform
import shutil
import statistics
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from bwt_campaign import ROOT, corpus, git, random_bytes, record_failures, run, sha
from huffman_wire import inspect


def diagnostics(data: bytes) -> dict:
    result = inspect(data)
    for block in result["blocks"]:
        ranks = block.pop("selector_ranks")
        selections = block.pop("selectors")
        block["selector_rank_counts"] = [ranks.count(rank) for rank in range(block["groups"])]
        block["selected_group_counts"] = [selections.count(group) for group in range(block["groups"])]
        if block["selector_count"] != (block["symbol_count"] + 49) // 50:
            raise AssertionError("generated stream has unused or missing selectors")
        if block["entropy_bits"] != 18 + block["selector_bits"] + block["table_bits"] + block["data_bits"]:
            raise AssertionError("entropy physical-cost mismatch")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--current", type=Path, required=True)
    parser.add_argument("--baseline-commit", required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--zig", default="zig")
    parser.add_argument("--cpu", type=int, default=2)
    parser.add_argument("--iterations", type=int, default=3)
    parser.add_argument("--samples", type=int, default=5)
    parser.add_argument("--repeats", type=int, default=2)
    args = parser.parse_args()
    current = args.current.resolve()
    if min(args.iterations, args.samples, args.repeats) < 1 or args.cpu not in os.sched_getaffinity(0):
        parser.error("positive counts and an allowed CPU are required")
    if current != (ROOT / "zig-out/bin/vort-bzip2-bwt-bench").resolve():
        parser.error("--current must name the artifact rebuilt by this campaign")
    report = {
        "schema": "vort.bzip2_huffman_campaign.v1", "status": "running",
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "driver_argv": sys.argv, "cpu": args.cpu, "iterations": args.iterations,
        "samples": args.samples, "repeats": args.repeats, "runs": [], "summary": [],
        "timing_scope": "native awake clock around output/scratch allocation, complete encode, sampled output use, final shrinking and free; file I/O, hash, exact BWT preflight and full decode are outside timing",
        "warm_state": "preflight retains two raw BWT outputs and the variant's encoded output; empty input omits raw BWT; all samples retained",
        "policy": "one codec thread pinned to one CPU; variant order reversed between repeats; ordinary host background recorded; no RSS or cold-start claim",
        "reference_options": {"verbosity": 0, "workFactor": 30, "blockSize100k": "per case 1 or 9"},
        "reference_build": "installed shared library; original compile flags unavailable; exact binary hash/version recorded",
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    def save() -> None:
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    save()
    with record_failures(report, args.report), tempfile.TemporaryDirectory(prefix="vort-bzip2-huffman-") as tmp:
        temp = Path(tmp)
        commit = git("rev-parse", args.baseline_commit).decode().strip()
        report["baseline_commit"] = commit
        report["current_head_before_commit"] = git("rev-parse", "HEAD").decode().strip()
        closure = git("ls-tree", "-r", "--name-only", commit, "src/bzip2", "src/core.zig", "src/io").decode().splitlines()
        borrowed = ["src/bzip2_bench.zig", "src/bzip2/test_support/bwt_full_doubling.zig",
                    "tools/bzip2/bwt_bench.zig", "tools/bzip2/libbz2_runtime.zig", "tools/benchmark_provenance.zig"]
        code_paths = sorted(set(closure + borrowed + ["build.zig", "src/bzip2.zig", "tools/bzip2/huffman_campaign.py",
                            "tools/bzip2/bwt_campaign.py", "tools/bzip2/huffman_wire.py", "tools/bzip2/huffman_wire_smoke.py"] +
                            [p.relative_to(ROOT).as_posix() for p in (ROOT / "src/bzip2").rglob("*.zig")]))
        report["current_sources"] = {p: sha((ROOT / p).read_bytes()) for p in code_paths}
        report["baseline_sources"] = {p: sha(git("show", f"{commit}:{p}")) for p in closure}
        report["zig_version"] = run([args.zig, "version"], text=True).stdout.strip()
        compiler = Path(shutil.which(args.zig) or args.zig).resolve()
        report["compiler"] = {"path": str(compiler), "sha256": sha(compiler.read_bytes())}
        report["python"] = {"version": platform.python_version(), "executable": sys.executable,
                            "sha256": sha(Path(sys.executable).resolve().read_bytes())}
        linked = next(line for line in run(["ldd", _bz2.__file__], text=True).stdout.splitlines() if "libbz2" in line)
        library = Path(linked.split("=>", 1)[1].split()[0]).resolve()
        runtime = ctypes.CDLL(str(library))
        runtime.BZ2_bzlibVersion.restype = ctypes.c_char_p
        version = runtime.BZ2_bzlibVersion().decode()
        external_paths = [library, Path(_bz2.__file__).resolve(), Path("/usr/bin/bzip2").resolve()]
        report["external_files"] = {str(p): sha(p.read_bytes()) for p in external_paths}
        report["reference_library"] = str(library)
        report["reference_version"] = version
        prepared = corpus(commit)
        logs = b"".join(f"2026-10-29T00:{n // 60:02d}:{n % 60:02d} service=vort codec=bzip2 request={n} status=200\n".encode() for n in range(1200))[:65536]
        source = prepared["source"]
        inputs = {"empty": (b"", 9), "tiny": (b"hello bzip2\n", 1),
                  **{name: (payload, 1 if name == "random16k" else 9) for name, payload in prepared.items()},
                  "random899k": (random_bytes(899000), 9), "logs64k": (logs, 9),
                  "binary": (Path("/usr/bin/bzip2").read_bytes(), 9),
                  "already_compressed": (bz2.compress(prepared["random64k"], compresslevel=9), 9),
                  "mixed64k": (prepared["json64k"][:16384] + prepared["random16k"] + (source * 4)[:16384] + logs[:16384], 9),
                  "longruns900k": (b"A" * 900000, 9), "multiblock": (bytes(range(251)) * 1000, 1)}
        report["corpus"] = {name: {"bytes": len(data), "sha256": sha(data), "block_size": level} for name, (data, level) in inputs.items()}
        build_current = [args.zig, "build", "-j2", "build-bzip2-bwt-bench", "-Doptimize=ReleaseFast", "--summary", "all"]
        report["current_build"] = {"command": build_current, "link_libc": True}
        result = run(build_current, cwd=ROOT, text=True)
        report["current_build"].update(exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr)
        old_root = temp / "baseline"
        for name in closure:
            path = old_root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(git("show", f"{commit}:{name}"))
        for name in borrowed:
            path = old_root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((ROOT / name).read_bytes())
        old = temp / "baseline-bench"
        build_old = [args.zig, "build-exe", "-OReleaseFast", "-lc", "--dep", "bzip2_bench", "--dep", "benchmark_provenance",
                     f"-Mroot={old_root / 'tools/bzip2/bwt_bench.zig'}", "-OReleaseFast", f"-Mbzip2_bench={old_root / 'src/bzip2_bench.zig'}",
                     "-OReleaseFast", f"-Mbenchmark_provenance={old_root / 'tools/benchmark_provenance.zig'}", f"-femit-bin={old}"]
        report["baseline_build"] = {"command": build_old,
            "generated_sources": {p.relative_to(old_root).as_posix(): sha(p.read_bytes()) for p in old_root.rglob("*.zig")}}
        result = run(build_old, text=True)
        report["baseline_build"].update(exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr)
        report["binaries"] = {"baseline": sha(old.read_bytes()), "current": sha(current.read_bytes())}
        report["load_before_timing"] = os.getloadavg()
        save()
        target = None
        for name, (payload, level) in inputs.items():
            source_path = temp / f"{name}.input"
            source_path.write_bytes(payload)
            times = {variant: [] for variant in ("baseline", "current", "reference")}
            signatures, wire = {}, {}
            for repeat in range(args.repeats):
                order = ("baseline", "current", "reference") if repeat % 2 == 0 else ("reference", "current", "baseline")
                for variant in order:
                    binary = old if variant == "baseline" else current
                    scope = "reference_encode" if variant == "reference" else "encode"
                    output = temp / f"{name}-{variant}.bz2"
                    command = ["taskset", "-c", str(args.cpu), str(binary), "--input", str(source_path), "--scope", scope,
                               "--block-size", str(level), "--iterations", str(args.iterations), "--samples", str(args.samples), "--output", str(output)]
                    if variant == "reference": command += ["--reference-library", str(library)]
                    raw = run(command, text=True).stdout
                    encoded = output.read_bytes()
                    if bz2.decompress(encoded) != payload: raise AssertionError("independent decoded-output mismatch")
                    if not encoded.startswith(f"BZh{level}".encode()): raise AssertionError("wrong encoded block-size header")
                    signature = (sha(encoded), len(encoded))
                    if variant in signatures and signatures[variant] != signature: raise AssertionError("nondeterministic wire")
                    signatures[variant] = signature
                    if variant not in wire: wire[variant] = diagnostics(encoded)
                    rows = list(csv.DictReader(io.StringIO(raw), strict=True))
                    if len(rows) != args.samples: raise AssertionError("wrong sample count")
                    checksum = (len(encoded) + encoded[0] + encoded[len(encoded) // 2] + encoded[-1]) * args.iterations
                    for n, row in enumerate(rows):
                        expected = {"scope": scope, "algorithm": "current", "block_size": str(level), "input_bytes": str(len(payload)),
                                    "input_sha256": sha(payload), "output_bytes": str(len(encoded)), "output_sha256": sha(encoded),
                                    "iterations": str(args.iterations), "sample": str(n), "optimize": "ReleaseFast", "cpu_affinity": str(args.cpu),
                                    "affinity_cpu_count": "1", "benchmark_threads": "1", "codec_thread_policy": "single", "checksum": str(checksum),
                                    "reference_version": version if variant == "reference" else "none", "executable_sha256": report["binaries"]["baseline" if variant == "baseline" else "current"]}
                        if any(row.get(k) != v for k, v in expected.items()): raise AssertionError("row metadata/identity/consumption mismatch")
                        if payload:
                            if not 0 <= int(row["raw_bwt_original_pointer"]) < len(payload): raise AssertionError("bad raw BWT pointer")
                        elif row["raw_bwt_original_pointer"] != "": raise AssertionError("empty input has a raw BWT pointer")
                        metadata = tuple(row[k] for k in ("zig_version", "target_arch", "target_os", "target_abi", "target_cpu", "cpu_model"))
                        if target is None: target = metadata
                        if target != metadata or int(row["elapsed_ns"]) <= 0: raise AssertionError("target or timer mismatch")
                        times[variant].append(int(row["elapsed_ns"]) / args.iterations)
                    report["runs"].append({"case": name, "variant": variant, "repeat": repeat, "command": command, "csv": raw, "decode": "ok"})
                    save()
            if signatures["current"][1] > signatures["baseline"][1]: raise AssertionError("fixed-size bound regressed")
            if wire["current"]["block_count"] != wire["baseline"]["block_count"]: raise AssertionError("BWT block geometry changed")
            for a, b in zip(wire["baseline"]["blocks"], wire["current"]["blocks"]):
                if any(a[k] != b[k] for k in ("symbol_count", "alphabet_size", "transformed_bytes", "original_pointer")):
                    raise AssertionError("non-entropy block content changed")
                if b["entropy_bits"] > a["entropy_bits"]: raise AssertionError("per-block fixed bit bound regressed")
            medians = {v: statistics.median(ns) for v, ns in times.items()}
            report["summary"].append({"case": name, "input_bytes": len(payload), "block_size": level,
                "output_bytes": {v: s[1] for v, s in signatures.items()}, "output_sha256": {v: s[0] for v, s in signatures.items()},
                "median_ns": medians, "mib_s": {v: len(payload) * 1e9 / (1024 * 1024) / ns for v, ns in medians.items()},
                "current_speedup": medians["baseline"] / medians["current"], "current_over_reference": medians["reference"] / medians["current"], "wire": wire})
            print(f"{name}: old={signatures['baseline'][1]} current={signatures['current'][1]} libbz2={signatures['reference'][1]} old/current_speedup={medians['baseline']/medians['current']:.3f}", flush=True)
            save()
        count = len(inputs) * 3 * args.repeats
        if len(report["runs"]) != count or len(report["summary"]) != len(inputs): raise AssertionError("incomplete run/case count")
        if sum(len(list(csv.DictReader(io.StringIO(r["csv"])))) for r in report["runs"]) != count * args.samples:
            raise AssertionError("incomplete sample count")
        if report["current_sources"] != {p: sha((ROOT / p).read_bytes()) for p in code_paths}: raise AssertionError("source files changed during timing")
        if report["binaries"]["current"] != sha(current.read_bytes()): raise AssertionError("current binary changed during timing")
        if report["external_files"] != {str(p): sha(p.read_bytes()) for p in external_paths}: raise AssertionError("reference/input artifact changed")
        report["load_after_timing"] = os.getloadavg()
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        report["status"] = "ok"
        save()


if __name__ == "__main__":
    main()
