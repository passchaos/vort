#!/usr/bin/env python3
"""Compare exact Bzip2 output, requested heap and uninstrumented encode timing."""
from __future__ import annotations

import argparse
import bz2
import csv
import io
import json
import os
import statistics
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from bwt_campaign import ROOT, git, random_bytes, record_failures, run, sha


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-commit", required=True)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--cpu", type=int, default=2)
    parser.add_argument("--zig", default="zig")
    parser.add_argument("--samples", type=int, default=5)
    parser.add_argument("--repeats", type=int, default=2)
    args = parser.parse_args()
    if args.samples < 1 or args.repeats < 1 or args.cpu not in os.sched_getaffinity(0):
        parser.error("positive samples/repeats and an available CPU are required")
    report = {"schema": "vort.bzip2_encoder_memory_campaign.v1", "status": "running",
              "started_utc": datetime.now(timezone.utc).isoformat(), "argv": __import__("sys").argv,
              "cpu": args.cpu, "samples": args.samples, "repeats": args.repeats,
              "resource_scope": "successful allocator requests covering codec-owned output/scratch; excludes caller input/output, metadata, stack, bookkeeping and backend remap internal transients",
              "timing_scope": "separate native probe without allocation counters; awake clock around encoding allocations/shrink/free and sampled output consumption; excludes I/O, hash and full decode",
              "resources": [], "timings": [], "summary": []}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    def save() -> None:
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    save()
    with record_failures(report, args.report), tempfile.TemporaryDirectory(prefix="vort-bzip2-encoder-memory-") as tmp:
        temp = Path(tmp)
        commit = git("rev-parse", args.baseline_commit).decode().strip()
        report["baseline_commit"] = commit
        closure = git("ls-tree", "-r", "--name-only", commit, "src/bzip2", "src/bzip2.zig", "src/core.zig", "src/io").decode().splitlines()
        tools = ["src/bzip2_bench.zig", "tools/bzip2/bwt_bench.zig", "tools/bzip2/libbz2_runtime.zig",
                 "tools/bzip2/encoder_resource_probe.zig", "tools/benchmark_provenance.zig"]
        current_files = sorted(set(closure + tools + ["build.zig", "tools/bzip2/encoder_memory_campaign.py", "tools/bzip2/bwt_campaign.py"] +
                            [p.relative_to(ROOT).as_posix() for p in (ROOT / "src/bzip2").rglob("*.zig")]))
        report["current_sources"] = {p: sha((ROOT / p).read_bytes()) for p in current_files}
        report["baseline_sources"] = {p: sha(git("show", f"{commit}:{p}")) for p in closure}
        report["zig_version"] = run([args.zig, "version"], text=True).stdout.strip()
        current_build = [args.zig, "build", "-j2", "build-bzip2-resource-probe", "build-bzip2-bwt-bench", "-Doptimize=ReleaseFast", "--summary", "all"]
        result = run(current_build, cwd=ROOT, text=True)
        report["current_build"] = {"command": current_build, "exit_code": result.returncode, "stdout": result.stdout, "stderr": result.stderr}
        old_root = temp / "baseline"
        for name in closure:
            p = old_root / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(git("show", f"{commit}:{name}"))
        for name in tools:
            p = old_root / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes((ROOT / name).read_bytes())
        old_bench, old_probe = temp / "old-bench", temp / "old-resource"
        builds = [
            [args.zig, "build-exe", "-OReleaseFast", "-lc", "--dep", "bzip2_bench", "--dep", "benchmark_provenance",
             f"-Mroot={old_root / 'tools/bzip2/bwt_bench.zig'}", "-OReleaseFast", f"-Mbzip2_bench={old_root / 'src/bzip2_bench.zig'}",
             "-OReleaseFast", f"-Mbenchmark_provenance={old_root / 'tools/benchmark_provenance.zig'}", f"-femit-bin={old_bench}"],
            [args.zig, "build-exe", "-OReleaseFast", "-lc", "--dep", "bzip2", "--dep", "benchmark_provenance",
             f"-Mroot={old_root / 'tools/bzip2/encoder_resource_probe.zig'}", "-OReleaseFast", f"-Mbzip2={old_root / 'src/bzip2.zig'}",
             "-OReleaseFast", f"-Mbenchmark_provenance={old_root / 'tools/benchmark_provenance.zig'}", f"-femit-bin={old_probe}"]]
        report["baseline_builds"] = []
        for command in builds:
            result = run(command, text=True)
            report["baseline_builds"].append({"command": command, "exit_code": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
        report["generated_baseline_sources"] = {p.relative_to(old_root).as_posix(): sha(p.read_bytes()) for p in old_root.rglob("*.zig")}
        current_bench = ROOT / "zig-out/bin/vort-bzip2-bwt-bench"
        current_probe = ROOT / "zig-out/bin/vort-bzip2-encoder-resource-probe"
        binaries = {"old_bench": old_bench, "old_probe": old_probe, "current_bench": current_bench, "current_probe": current_probe}
        report["binaries"] = {name: sha(path.read_bytes()) for name, path in binaries.items()}
        source = git("show", f"{commit}:src/bzip2/encoder.zig")
        cases = {"empty1": (b"", 1), "empty9": (b"", 9), "tiny": (b"hello bzip2\n", 9),
                 "one_byte": (b"A", 9), "binary256": (bytes(range(256)), 9),
                 "random4k": (random_bytes(4096), 9), "source": (source, 9),
                 "random64k": (random_bytes(65536), 9), "random899k": (random_bytes(899000), 9),
                 "periodic64k": (b"abac" * 16384, 9), "longruns": (b"A" * (259 * 3470), 9),
                 "rle_expansion_multiblock": ((b"AAAABBBB" * 10000) + b"AAAA", 1),
                 "bulk6m": (random_bytes(6 * 1024 * 1024), 1)}
        report["inputs"] = {name: {"bytes": len(data), "sha256": sha(data), "block_size": level} for name, (data, level) in cases.items()}
        report["load_before"] = os.getloadavg()
        report["background_before"] = run(["ps", "-eo", "pid,psr,pcpu,comm", "--sort=-pcpu"], text=True).stdout.splitlines()[:12]
        save()
        target = None
        for name, (payload, level) in cases.items():
            source_path = temp / f"{name}.input"
            source_path.write_bytes(payload)
            for strategy in ("fast", "balanced", "ratio"):
                resource_rows = {}
                expected_wire = None
                for kind in ("oneshot", "incremental"):
                    for variant in ("baseline", "current"):
                        binary = old_probe if variant == "baseline" else current_probe
                        output = temp / f"{name}-{strategy}-{kind}-{variant}.bz2"
                        input_step, output_step = (1, 7) if len(payload) <= 4096 else (65536, 32768)
                        command = ["taskset", "-c", str(args.cpu), str(binary), "--input", str(source_path), "--output", str(output),
                                   "--kind", kind, "--strategy", strategy, "--block-size", str(level),
                                   "--input-step", str(input_step), "--output-step", str(output_step)]
                        row = json.loads(run(command, text=True).stdout)
                        encoded = output.read_bytes()
                        if bz2.decompress(encoded) != payload or row["source_sha256"] != sha(payload) or row["output_sha256"] != sha(encoded):
                            raise AssertionError("resource full-output identity/decode mismatch")
                        if row["kind"] != kind or row["strategy"] != strategy or row["block_size"] != level or row["final_live"] != 0:
                            raise AssertionError("resource settings or ownership mismatch")
                        provenance = row["provenance"]
                        if provenance["optimize"] != "ReleaseFast" or provenance["cpu_affinity"] != str(args.cpu) or provenance["affinity_cpu_count"] != 1:
                            raise AssertionError("resource build/affinity mismatch")
                        if provenance["executable_sha256"] != sha(binary.read_bytes()): raise AssertionError("resource executable mismatch")
                        metadata = tuple(provenance[k] for k in ("zig_version", "target_arch", "target_os", "target_abi", "target_cpu", "cpu_model"))
                        if target is None: target = metadata
                        if metadata != target: raise AssertionError("resource target mismatch")
                        signature = (sha(encoded), len(encoded))
                        if expected_wire is None: expected_wire = signature
                        if signature != expected_wire: raise AssertionError("one-shot/stream/old/new wire mismatch")
                        if kind == "oneshot" and row["live_output"] != len(encoded): raise AssertionError("unexpected owned output bytes")
                        if kind == "incremental" and row["caller_output_capacity"] != len(payload) * 2 + 4096:
                            raise AssertionError("caller output counted inconsistently")
                        resource_rows[f"{kind}_{variant}"] = row
                        report["resources"].append({"case": name, "strategy": strategy, "kind": kind, "variant": variant, "command": command, "report": row, "decode": "ok"})
                        save()
                times = {"baseline": [], "current": []}
                iterations = 1 if len(payload) > 900000 else 3
                for repeat in range(args.repeats):
                    order = ("baseline", "current") if repeat % 2 == 0 else ("current", "baseline")
                    for variant in order:
                        binary = old_bench if variant == "baseline" else current_bench
                        output = temp / f"{name}-{strategy}-{variant}-timed.bz2"
                        command = ["taskset", "-c", str(args.cpu), str(binary), "--input", str(source_path), "--output", str(output),
                                   "--scope", "encode", "--strategy", strategy, "--block-size", str(level),
                                   "--iterations", str(iterations), "--samples", str(args.samples)]
                        raw = run(command, text=True).stdout
                        encoded = output.read_bytes()
                        if (sha(encoded), len(encoded)) != expected_wire or bz2.decompress(encoded) != payload:
                            raise AssertionError("timing full-output identity/decode mismatch")
                        rows = list(csv.DictReader(io.StringIO(raw), strict=True))
                        if len(rows) != args.samples: raise AssertionError("wrong sample count")
                        checksum = (len(encoded) + encoded[0] + encoded[len(encoded) // 2] + encoded[-1]) * iterations
                        for index, row in enumerate(rows):
                            expected = {"scope": "encode", "strategy": strategy, "block_size": str(level), "input_bytes": str(len(payload)),
                                        "input_sha256": sha(payload), "output_bytes": str(len(encoded)), "output_sha256": sha(encoded),
                                        "iterations": str(iterations), "sample": str(index), "optimize": "ReleaseFast", "cpu_affinity": str(args.cpu),
                                        "affinity_cpu_count": "1", "checksum": str(checksum), "executable_sha256": sha(binary.read_bytes())}
                            if any(row.get(k) != v for k, v in expected.items()): raise AssertionError("timing row identity/configuration mismatch")
                            if tuple(row[k] for k in ("zig_version", "target_arch", "target_os", "target_abi", "target_cpu", "cpu_model")) != target:
                                raise AssertionError("timing target mismatch")
                            if int(row["elapsed_ns"]) <= 0: raise AssertionError("invalid native clock")
                            times[variant].append(int(row["elapsed_ns"]) / iterations)
                        report["timings"].append({"case": name, "strategy": strategy, "variant": variant, "repeat": repeat, "command": command, "csv": raw, "decode": "ok"})
                        save()
                old_ns, new_ns = statistics.median(times["baseline"]), statistics.median(times["current"])
                report["summary"].append({"case": name, "strategy": strategy, "input_bytes": len(payload), "block_size": level,
                    "encoded_bytes": expected_wire[1], "output_sha256": expected_wire[0], "baseline_median_ns": old_ns,
                    "current_median_ns": new_ns, "speedup": old_ns / new_ns,
                    "resources": {key: {field: row[field] for field in ("peak", "allocations", "resizes", "remaps", "largest_request", "retained_rle_capacity", "retained_output_capacity", "final_live")} for key, row in resource_rows.items()}})
                print(f"{name}/{strategy}: exact=ok speedup={old_ns/new_ns:.3f} heaps={[resource_rows[k]['peak'] for k in ('oneshot_baseline','oneshot_current','incremental_baseline','incremental_current')]}", flush=True)
                save()
        if len(report["resources"]) != len(cases) * 3 * 4 or len(report["timings"]) != len(cases) * 3 * 2 * args.repeats:
            raise AssertionError("incomplete comparison")
        if len(report["summary"]) != len(cases) * 3: raise AssertionError("incomplete summaries")
        if report["current_sources"] != {p: sha((ROOT / p).read_bytes()) for p in current_files}: raise AssertionError("source drift")
        if report["binaries"] != {name: sha(path.read_bytes()) for name, path in binaries.items()}: raise AssertionError("binary drift")
        report["load_after"] = os.getloadavg()
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        report["status"] = "ok"
        save()


if __name__ == "__main__":
    main()
