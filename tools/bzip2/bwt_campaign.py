#!/usr/bin/env python3
"""Compare exact BWT output and allocation-inclusive native encoding timings."""
from __future__ import annotations

import argparse
import _bz2
import bz2
import csv
import ctypes
import hashlib
import io
import json
import os
import platform
import statistics
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def run(argv: list[str], **kwargs) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(argv, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, **kwargs)
    except subprocess.CalledProcessError as error:
        print(error.stderr.decode() if isinstance(error.stderr, bytes) else error.stderr, file=sys.stderr)
        raise


def git(*args: str) -> bytes:
    return run(["git", "-C", str(ROOT), *args]).stdout


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


@contextmanager
def record_failures(report: dict, path: Path):
    try:
        yield
    except BaseException as error:
        report["status"] = "interrupted" if isinstance(error, KeyboardInterrupt) else "failed"
        report["error"] = f"{type(error).__name__}: {error}"
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        path.write_text(json.dumps(report, indent=2) + "\n")
        raise


def random_bytes(length: int) -> bytes:
    state = 0x62A735819CAF0241
    result = bytearray()
    mask = (1 << 64) - 1
    for _ in range(length):
        state ^= state >> 12
        state ^= (state << 25) & mask
        state ^= state >> 27
        result.append(((state * 0x2545F4914F6CDD1D) & mask) >> 56)
    return bytes(result)


def corpus(commit: str) -> dict[str, bytes]:
    structured = b"".join(
        json.dumps({"service": "vort", "codec": "bzip2", "sequence": n, "status": "ok"},
                   separators=(",", ":")).encode() + b"\n" for n in range(1200)
    )[:65536]
    near = bytearray(b"abac" * 16384)
    near[len(near) // 2] = ord("X")
    return {
        "unique256": bytes((n * 73 + 19) % 256 for n in range(256)),
        "random16k": random_bytes(16384),
        "random64k": random_bytes(65536),
        "random900k": random_bytes(900000),
        "source": git("show", f"{commit}:src/bzip2/encoder.zig"),
        "json64k": structured,
        "periodic64k": b"abac" * 16384,
        "periodic900k": b"abac" * 225000,
        "nearly_periodic64k": bytes(near),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--current", type=Path, required=True)
    parser.add_argument("--baseline-commit", required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--zig", default="zig")
    parser.add_argument("--cpu", type=int, default=0)
    parser.add_argument("--iterations", type=int, default=3)
    parser.add_argument("--samples", type=int, default=5)
    parser.add_argument("--repeats", type=int, default=2)
    args = parser.parse_args()
    if min(args.iterations, args.samples, args.repeats) < 1:
        parser.error("iterations, samples and repeats must be positive")
    current = args.current.resolve()
    if current != (ROOT / "zig-out/bin/vort-bzip2-bwt-bench").resolve():
        parser.error("--current must name zig-out/bin/vort-bzip2-bwt-bench, rebuilt by this campaign")
    commit = git("rev-parse", args.baseline_commit).decode().strip()
    if args.cpu not in os.sched_getaffinity(0):
        parser.error("selected CPU is outside the allowed affinity")
    inputs = corpus(commit)
    closure = git("ls-tree", "-r", "--name-only", commit, "src/bzip2", "src/core.zig", "src/io/stream_count.zig").decode().splitlines()
    tool_paths = ["src/bzip2_bench.zig", "src/bzip2/test_support/bwt_full_doubling.zig",
                  "tools/bzip2/bwt_bench.zig", "tools/bzip2/libbz2_runtime.zig", "tools/benchmark_provenance.zig"]
    current_closure = [p.relative_to(ROOT).as_posix() for p in (ROOT / "src/bzip2").rglob("*.zig")]
    source_paths = sorted(set(closure + current_closure + tool_paths + ["src/bzip2/bwt.zig", "src/bzip2/bwt_tests.zig",
                                                    "src/bzip2.zig", "tools/bzip2/bwt_campaign.py", "build.zig"]))
    current_build = [args.zig, "build", "-j2", "build-bzip2-bwt-bench", "-Doptimize=ReleaseFast", "--summary", "all"]
    build_result = run(current_build, cwd=ROOT, text=True)
    libbz2_line = next(line for line in run(["ldd", _bz2.__file__], text=True).stdout.splitlines() if "libbz2" in line)
    libbz2_path = Path(libbz2_line.split("=>", 1)[1].split()[0]).resolve()
    libbz2 = ctypes.CDLL(str(libbz2_path))
    libbz2.BZ2_bzlibVersion.restype = ctypes.c_char_p
    report = {
        "schema": "vort.bzip2_bwt_campaign.v1",
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "baseline_commit": commit,
        "current_head": git("rev-parse", "HEAD").decode().strip(),
        "current_sources": {p: sha((ROOT / p).read_bytes()) for p in source_paths},
        "baseline_sources": {p: sha(git("show", f"{commit}:{p}")) for p in closure},
        "python": platform.python_version(),
        "zig_version": run([args.zig, "version"], text=True).stdout.strip(),
        "reference": {"oracle": "Python bz2 / its dynamically linked libbz2", "bz2_extension": _bz2.__file__,
                      "bz2_extension_sha256": sha(Path(_bz2.__file__).read_bytes()), "libbz2": str(libbz2_path),
                      "libbz2_sha256": sha(libbz2_path.read_bytes()), "libbz2_version": libbz2.BZ2_bzlibVersion().decode()},
        "current_build": {"command": current_build, "cwd": str(ROOT), "exit_code": build_result.returncode,
                          "stdout": build_result.stdout, "stderr": build_result.stderr},
        "timing_scope": "native awake clock; allocation, transform/encode and free; excludes file I/O, hashes, exact preflight and process startup; preflight warms state",
        "policy": "single codec thread pinned to one CPU; alternating variant order across repeats; every sample retained; no competitor throughput claim",
        "raw_bwt_original_pointer": "BWT directly over input bytes, before encoder RLE1; not the pointer in the emitted Bzip2 block",
        "cpu": args.cpu,
        "iterations": args.iterations, "samples": args.samples, "repeats": args.repeats,
        "load_before": os.getloadavg(), "runs": [], "summary": [], "status": "running",
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    def save() -> None:
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    save()
    with record_failures(report, args.report), tempfile.TemporaryDirectory(prefix="vort-bzip2-bwt-") as tmp:
        temp = Path(tmp)
        baseline_root = temp / "baseline"
        for name in closure:
            path = baseline_root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(git("show", f"{commit}:{name}"))
        for name in tool_paths:
            path = baseline_root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((ROOT / name).read_bytes())
        baseline = temp / "baseline-bench"
        build = [args.zig, "build-exe", "-OReleaseFast", "-lc", "--dep", "bzip2_bench", "--dep", "benchmark_provenance",
                 f"-Mroot={baseline_root / 'tools/bzip2/bwt_bench.zig'}", "-OReleaseFast", f"-Mbzip2_bench={baseline_root / 'src/bzip2_bench.zig'}",
                 "-OReleaseFast", f"-Mbenchmark_provenance={baseline_root / 'tools/benchmark_provenance.zig'}", f"-femit-bin={baseline}"]
        run(build)
        report["baseline_build_command"] = build
        report["binaries"] = {"baseline": sha(baseline.read_bytes()), "current": sha(current.read_bytes())}
        save()
        target_metadata = None
        for case, payload in inputs.items():
            source = temp / f"{case}.input"
            source.write_bytes(payload)
            for scope in ("bwt", "encode"):
                groups = {"baseline": [], "current": []}
                outputs = {}
                for repeat in range(args.repeats):
                    variants = ("baseline", "current") if repeat % 2 == 0 else ("current", "baseline")
                    for variant in variants:
                        # Same binary for both BWT kernels; old/new encoder trees for end-to-end.
                        binary = baseline if scope == "encode" and variant == "baseline" else current
                        algorithm = "full" if scope == "bwt" and variant == "baseline" else "current"
                        output = temp / f"{case}-{scope}-{variant}.output"
                        command = ["taskset", "-c", str(args.cpu), str(binary), "--input", str(source),
                                   "--scope", scope, "--algorithm", algorithm, "--iterations", str(args.iterations),
                                   "--samples", str(args.samples), "--output", str(output)]
                        raw = run(command, text=True).stdout
                        rows = list(csv.DictReader(io.StringIO(raw), strict=True))
                        if len(rows) != args.samples:
                            raise AssertionError("wrong sample count")
                        for n, row in enumerate(rows):
                            if (row["scope"] != scope or row["algorithm"] != algorithm or row["iterations"] != str(args.iterations)
                                    or row["input_bytes"] != str(len(payload)) or row["output_bytes"] != str(output.stat().st_size)
                                    or row["cpu_affinity"] != str(args.cpu) or row["benchmark_threads"] != "1"
                                    or row["codec_thread_policy"] != "single"):
                                raise AssertionError("scope, algorithm, iteration, dimension or thread mismatch")
                            if not 0 <= int(row["raw_bwt_original_pointer"]) < len(payload):
                                raise AssertionError("invalid raw BWT pointer")
                            if scope == "bwt" and row["output_bytes"] != str(len(payload)):
                                raise AssertionError("wrong BWT output length")
                            metadata = tuple(row[k] for k in ("zig_version", "target_arch", "target_os", "target_abi", "target_cpu", "cpu_model"))
                            if target_metadata is None:
                                target_metadata = metadata
                            if metadata != target_metadata:
                                raise AssertionError("compiler or target mismatch")
                            if row["input_sha256"] != sha(payload) or row["executable_sha256"] != sha(binary.read_bytes()):
                                raise AssertionError("input or executable identity mismatch")
                            if row["optimize"] != "ReleaseFast" or row["affinity_cpu_count"] != "1" or row["sample"] != str(n):
                                raise AssertionError("build, affinity or sample mismatch")
                            if row["output_sha256"] != sha(output.read_bytes()) or int(row["elapsed_ns"]) <= 0:
                                raise AssertionError("output identity or timer mismatch")
                        if scope == "encode" and bz2.decompress(output.read_bytes()) != payload:
                            raise AssertionError("independent bz2 decode mismatch")
                        signature = (rows[0]["output_sha256"], rows[0]["output_bytes"], rows[0]["raw_bwt_original_pointer"])
                        if any((row["output_sha256"], row["output_bytes"], row["raw_bwt_original_pointer"]) != signature for row in rows):
                            raise AssertionError("within-call output metadata mismatch")
                        if variant in outputs and outputs[variant] != signature:
                            raise AssertionError("nondeterministic output")
                        outputs[variant] = signature
                        groups[variant].extend(int(row["elapsed_ns"]) / args.iterations for row in rows)
                        report["runs"].append({"case": case, "scope": scope, "variant": variant,
                                               "repeat": repeat, "command": command, "csv": raw})
                        save()
                if outputs["baseline"] != outputs["current"]:
                    raise AssertionError(f"exact output mismatch: {case}/{scope}")
                old, new = (statistics.median(groups[v]) for v in ("baseline", "current"))
                report["summary"].append({"case": case, "scope": scope, "input_bytes": len(payload),
                                          "baseline_median_ns": old, "current_median_ns": new,
                                          "speedup": old / new, "output_sha256": outputs["current"][0],
                                          "output_bytes": int(outputs["current"][1]), "raw_bwt_original_pointer": int(outputs["current"][2])})
                print(f"{case}/{scope}: exact=ok median_speedup={old / new:.3f}", flush=True)
                save()
        expected_runs = len(inputs) * 2 * 2 * args.repeats
        if (len(report["runs"]) != expected_runs or len(report["summary"]) != len(inputs) * 2
                or sum(len(list(csv.DictReader(io.StringIO(r["csv"])))) for r in report["runs"]) != expected_runs * args.samples):
            raise AssertionError("incomplete campaign")
        if report["current_sources"] != {p: sha((ROOT / p).read_bytes()) for p in source_paths}:
            raise AssertionError("source files changed during the campaign")
        if report["binaries"]["current"] != sha(current.read_bytes()):
            raise AssertionError("current binary changed during the campaign")
    report["load_after"] = os.getloadavg()
    report["finished_utc"] = datetime.now(timezone.utc).isoformat()
    report["status"] = "ok"
    save()


if __name__ == "__main__":
    main()
