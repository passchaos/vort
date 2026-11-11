"""Run a resumable frozen-source paired decoder matrix on one pinned CPU."""
import argparse
import csv
import gzip
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time

from evidence import reference_files, require, summarize, validate_manifest, validate_report
from fixtures import freeze, sha256

ROOT = Path(__file__).resolve().parents[2]


def write_json(path, value):
    path = Path(path)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def source_state():
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    files = subprocess.check_output(["git", "ls-files", "src", "tools/benchmark_provenance.zig", "tools/br/libbrotli_runtime.zig", "tools/zstd/libzstd_runtime.zig", "tools/zstd/reference_parameters.zig"], cwd=ROOT, text=True).splitlines()
    files += [str(path.relative_to(ROOT)) for path in (ROOT / "tools/decode").glob("*.zig")]
    files += [str(path.relative_to(ROOT)) for path in (ROOT / "tools/decode").glob("*.py")]
    files += ["build.zig", "build/decode_compare.zig"]
    hashes = {name: sha256(ROOT / name) for name in sorted(set(files))}
    digest = hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()
    return {"revision": revision, "sha256": hashes, "digest": digest}


def environment(cpu):
    def read(path):
        try:
            return Path(path).read_text().strip()
        except OSError:
            return "unavailable"
    return {"platform": platform.platform(), "machine_id_sha256": hashlib.sha256(read("/etc/machine-id").encode()).hexdigest(), "zig_version": subprocess.check_output(["zig", "version"], text=True).strip(), "cpu_model": next((line.split(":", 1)[1].strip() for line in Path("/proc/cpuinfo").read_text().splitlines() if line.startswith("model name")), "unknown"), "logical_cpu": cpu, "governor": read(f"/sys/devices/system/cpu/cpu{cpu}/cpufreq/scaling_governor"), "driver": read(f"/sys/devices/system/cpu/cpu{cpu}/cpufreq/scaling_driver"), "turbo_disabled": read("/sys/devices/system/cpu/intel_pstate/no_turbo"), "host_policy": "development-host observational baseline; no dedicated-host acceptance claim"}


def verify_references(config):
    for codec, reference in config.items():
        files = reference_files(reference, codec)
        for path in files:
            require(Path(path).is_file() and Path(path).is_absolute(), "Reference must be an explicit existing absolute file")
        reference["file_sha256"] = {path: sha256(path) for path in files}
        require(bool(reference["version"]), "Missing pinned reference version")
    require(config["deflate"].get("source_revision") and config["deflate"].get("version_header_sha256"), "Deflate requires pinned source/header provenance; version cannot be queried")
    return config


def task_id(task):
    return task["fixture"]["key"].replace("/", "_") + "_" + task["lifecycle"]


def arguments(probe, task, references, config):
    fixture = task["fixture"]
    args = [str(probe), "--codec", fixture["codec"], "--input", fixture["input_path"], "--encoded-input", fixture["encoded_input_path"], "--iterations", str(task["iterations"]), "--rounds", str(config["rounds"]), "--warmup", str(config["warmup"]), "--lifecycle", task["lifecycle"]]
    reference = references[fixture["codec"]]
    if fixture["codec"] == "brotli":
        for role in ("encoder", "decoder", "common"):
            args += ["--brotli-" + role, reference[role]]
    else:
        args += ["--reference", reference["path"]]
        if fixture["codec"] == "deflate":
            args += ["--reference-version", reference["version"]]
    return args


def run(args):
    out = Path(args.out_dir).resolve()
    out.mkdir(parents=True, exist_ok=True)
    probe = Path(args.probe).resolve()
    require(probe.is_file(), "Build the probe before starting the campaign")
    config = {"cpu": args.cpu, "target_cpu": args.target_cpu, "rounds": args.rounds, "warmup": args.warmup, "sizes": args.sizes.split(","), "lifecycles": args.lifecycles.split(","), "iterations": {"65536": args.iterations_64k, "1048576": args.iterations_1m, "full": args.iterations_full}}
    require(config["rounds"] >= 2 and config["rounds"] % 2 == 0 and config["warmup"] >= 0 and config["warmup"] % 2 == 0, "Sampling counts must balance order")
    require(set(config["sizes"]) <= {"65536", "1048576", "full"}, "Unexpected matrix size")
    require(set(config["lifecycles"]) <= {"cold", "prepared"}, "Unexpected lifecycle")
    require(all(value > 0 for value in config["iterations"].values()), "Zero iterations")
    require(args.limit >= 0 and args.timeout > 0, "Invalid task limit or timeout")
    require(args.cpu in os.sched_getaffinity(0), "Benchmark CPU is outside available affinity")
    require(all(len(config[key]) == len(set(config[key])) for key in ("sizes", "lifecycles")), "Duplicate matrix dimensions")
    references = verify_references(json.loads(Path(args.references).read_text()))
    state = source_state()
    host = environment(args.cpu)
    probe_hash = sha256(probe)
    manifest_path = out / "manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        require(manifest["config"] == config and manifest["references"] == references, "Existing campaign configuration differs")
        require(manifest["source"]["digest"] == state["digest"] and manifest["source"]["revision"] == state["revision"], "Source changed since campaign freeze")
        require(manifest["probe_sha256"] == probe_hash, "Probe changed since campaign freeze")
        require(manifest["environment"] == host, "Host environment or power policy changed; start a separate epoch")
    else:
        # Reference frame generation and disk I/O are entirely outside timing.
        fixtures = freeze(out, Path(args.corpus).resolve(), references, config["sizes"])
        tasks = [{"fixture": fixture, "lifecycle": lifecycle, "iterations": config["iterations"][fixture["size"]]} for fixture in fixtures for lifecycle in config["lifecycles"] if not (fixture["codec"] == "brotli" and lifecycle == "prepared")]
        manifest = {"schema": "vort.decode-matrix.v1", "source": state, "probe": str(probe), "probe_sha256": probe_hash, "references": references, "config": config, "environment": host, "fixtures": fixtures, "tasks": tasks}
        write_json(manifest_path, manifest)
    validate_manifest(manifest)
    if args.prepare_only:
        print(f"Prepared {len(manifest['fixtures'])} wires / {len(manifest['tasks'])} tasks", flush=True)
        return
    reports = out / "rows"
    reports.mkdir(exist_ok=True)
    completed = []
    selected = manifest["tasks"] if args.limit == 0 else manifest["tasks"][:args.limit]
    started = time.time()
    for index, task in enumerate(selected):
        require(source_state()["digest"] == state["digest"], "Source changed during campaign")
        require(sha256(probe) == probe_hash, "Probe changed during campaign")
        require(environment(args.cpu) == host, "Host environment changed during campaign")
        key = task_id(task)
        path = reports / (key + ".json")
        if path.exists():
            report = json.loads(path.read_text())
            validate_report(report["probe"], task, manifest)
            require(report["task"] == task, "Resume row belongs to a different task")
            completed.append(report)
            print(f"resume {index + 1}/{len(selected)} {key}", flush=True)
            continue
        argv = arguments(probe, task, references, config)
        pinned = ["taskset", "-c", str(args.cpu)] + argv
        env = os.environ.copy()
        if task["fixture"]["codec"] == "brotli":
            # Keep the exact selected common library in the transitive loader
            # path. The probe's maps still prove the actually loaded closure.
            env["LD_LIBRARY_PATH"] = str(Path(references["brotli"]["common"]).parent)
        rss_path = reports / (key + ".rss.txt")
        command = ["/usr/bin/time", "-f", "%M", "-o", str(rss_path)] + pinned
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=args.timeout)
        (reports / (key + ".stderr.txt")).write_text(result.stderr)
        require(result.returncode == 0, f"Probe failed for {key}: {result.stderr[-1000:]}")
        probe_report = json.loads(result.stdout)
        validate_report(probe_report, task, manifest)
        report = {"task": task, "probe": probe_report, "argv": pinned, "rss_kib": int(rss_path.read_text().strip()), "rss_scope": "whole isolated child including loaded libraries, input/output buffers, validation and contexts; not codec-only heap", "completed_unix": time.time()}
        write_json(path, report)
        completed.append(report)
        print(f"row {index + 1}/{len(selected)} {key}: median-time-ratio={probe_report['summary']['vort_median_ns'] / probe_report['summary']['reference_median_ns']:.4f}", flush=True)
    require(source_state()["digest"] == state["digest"] and sha256(probe) == probe_hash, "Source or probe changed at campaign completion")
    require(environment(args.cpu) == host, "Host environment changed before summary publication")
    summary = {"schema": "vort.decode-matrix-summary.v1", "complete": len(completed) == len(manifest["tasks"]), "completed_rows": len(completed), "expected_rows": len(manifest["tasks"]), "elapsed_seconds": time.time() - started, "groups": summarize(completed, resamples=args.bootstrap), "interpretation": "time ratios above one mean Vort slower; Deflate prepared rows retain only reference context and are separately labeled; developer-host observations do not prove industry leadership"}
    write_json(out / "summary.json", summary)
    with (out / "matrix.csv").open("w", newline="") as target:
        writer = csv.writer(target)
        writer.writerow(("codec", "name", "size", "level", "lifecycle", "input_bytes", "encoded_bytes", "vort_median_ns", "reference_median_ns", "time_ratio", "rss_kib"))
        for row in completed:
            fixture, probe_report = row["task"]["fixture"], row["probe"]
            writer.writerow((fixture["codec"], fixture["name"], fixture["size"], fixture["level"], row["task"]["lifecycle"], fixture["input_bytes"], fixture["encoded_bytes"], probe_report["summary"]["vort_median_ns"], probe_report["summary"]["reference_median_ns"], probe_report["summary"]["vort_median_ns"] / probe_report["summary"]["reference_median_ns"], row["rss_kib"]))
    print(json.dumps(summary), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", required=True)
    parser.add_argument("--references", required=True)
    parser.add_argument("--corpus", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--cpu", type=int, default=15)
    parser.add_argument("--target-cpu", default="skylake+pku+sgx")
    parser.add_argument("--sizes", default="65536,1048576,full")
    parser.add_argument("--lifecycles", default="cold,prepared")
    parser.add_argument("--iterations-64k", type=int, default=100)
    parser.add_argument("--iterations-1m", type=int, default=20)
    parser.add_argument("--iterations-full", type=int, default=1)
    parser.add_argument("--rounds", type=int, default=6)
    parser.add_argument("--warmup", type=int, default=2)
    parser.add_argument("--bootstrap", type=int, default=2000)
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    try:
        run(args)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))


if __name__ == "__main__":
    main()
