"""Collect resumable current-source allocating encoder presets on frozen Silesia."""
import argparse
import csv
import hashlib
import json
import math
import os
import platform
from pathlib import Path
import random
import statistics
import subprocess
import sys


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def write(path, value):
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, indent=2) + "\n")
    temp.replace(path)


def validate(report, task, manifest):
    codec = task["codec"]
    require(report["codec"] == codec and len(report["rows"]) == 1, "Wrong row scope")
    row = report["rows"][0]
    f = task["fixture"]
    require((row["input_bytes"], row["input_sha256"], row["iterations"]) ==
            (f["input_bytes"], f["input_sha256"], task["iterations"]), "Frozen input or iterations differ")
    p = report["provenance"]
    require(p["executable_sha256"] == manifest["probes"][codec]["sha256"], "Probe changed")
    require(p["optimize"] == "ReleaseFast" and p["cpu_affinity"] == "15" and p["affinity_cpu_count"] == 1, "Wrong build or affinity")
    require(p["target_cpu"] == "skylake+pku+sgx" and p["zig_version"] == "0.16.0", "Wrong compiler features")
    rounds = row["rounds"]
    if codec == "deflate":
        require(report["lifecycle"]["state"] == "cold_per_call" and report["csv_aggregation"] == "median", "Wrong lifecycle")
        require(len(rounds) == 6 and len(row["warmup_rounds"]) == 6, "Missing rounds")
        require(row["settings"]["vort_level"] == task["level"] and row["settings"]["libdeflate_level"] == task["reference_level"], "Wrong Deflate presets")
        orders = [["vort", "zlib", "libdeflate"], ["zlib", "libdeflate", "vort"], ["libdeflate", "vort", "zlib"],
                  ["vort", "libdeflate", "zlib"], ["libdeflate", "zlib", "vort"], ["zlib", "vort", "libdeflate"]]
        for observations in (rounds, row["warmup_rounds"]):
            for index, sample in enumerate(observations):
                require(sample["index"] == index and sample["order"] == orders[index], "Changed permutation order")
                for side in ("vort", "zlib", "libdeflate"):
                    require(type(sample[side + "_ns"]) is int and sample[side + "_ns"] > 0, "Invalid duration")
                    require(sample[side + "_mix"] == row["wires"][side + "_bytes"] * task["iterations"] % (1 << 64), "Wire length drift")
        for side in ("vort", "zlib", "libdeflate"):
            require(row["summary"][side + "_median_ns"] == int(statistics.median(x[side + "_ns"] for x in rounds)), "Median dropped samples")
        return row
    import sample_gate
    frozen = {"input_sets": [{"frozen_path": f["input_path"], "input_bytes": f["input_bytes"], "input_sha256": f["input_sha256"]}]}
    sample_gate.validate(report, frozen, executable=Path(manifest["probes"][codec]["path"]), require_explicit_references=True)
    require(len(rounds) == (5 if codec == "brotli" else 6), "Missing rounds")
    if codec == "brotli":
        require(row["settings"]["planned_quality"] == task["level"] and row["settings"]["parameters_match"] is True, "Brotli parameter mismatch")
        require(row["settings"]["vort_command_state_max_input_kib"] == (8 if task["level"] == 11 else 255), "Wrong command-state policy")
    else:
        require(row["settings"]["level"] == task["level"] and row["settings"]["api"] == "level_policy", "Wrong Zstd policy")
    return row


def command(task, manifest, out):
    codec = task["codec"]
    probe = manifest["probes"][codec]["path"]
    f = task["fixture"]
    stem = task["id"]
    common = ["--iterations", str(task["iterations"]), "--csv", str(out / (stem + ".csv")), "--samples-json", str(out / (stem + ".json")), "--limit", str(f["input_bytes"])]
    if codec == "deflate":
        args = ["--input", f["input_path"], "--name", stem, "--level", str(task["level"]), "--libdeflate-level", str(task["reference_level"]), "--rounds", "6", "--warmup", "6"]
    elif codec == "zstd":
        args = ["--path", f["input_path"], "--level", str(task["level"]), "--rounds", "6", "--libzstd", manifest["references"]["zstd"]["path"]]
    else:
        args = ["--path", f["input_path"], "--quality", str(task["level"]), "--planned-quality=" + str(task["level"]), "--planned-mode=generic", "--window-bits=16", "--reference-lgwin=16", "--reference-mode=generic"]
        if task["level"] == 11:
            args += ["--command-state-max-input-kib=8"]
        args += [arg for role in ("encoder", "decoder", "common") for arg in ("--libbrotli-" + role, manifest["references"]["brotli"][role])]
    return ["taskset", "-c", "15", probe] + args + common


def summary(out, manifest):
    rows = []
    groups = {}
    for task in manifest["tasks"]:
        if task["id"] not in manifest["completed"]:
            continue
        row = json.loads((out / (task["id"] + ".json")).read_text())["rows"][0]
        side = "libdeflate" if task["codec"] == "deflate" else "reference"
        raw = row["rounds"]
        ratios = [math.log(r[side + "_ns"] / r["vort_ns"]) for r in raw]
        size = row["wires"]["vort_bytes"] / row["wires"][side + "_bytes"]
        entry = {"id": task["id"], "throughput_vort_over_reference": math.exp(statistics.mean(ratios)), "encoded_size_vort_over_reference": size,
                 "vort_bytes": row["wires"]["vort_bytes"], "reference_bytes": row["wires"][side + "_bytes"]}
        rows.append(entry)
        key = f'{task["codec"]}/{task["size"]}/L{task["level"]}'
        groups.setdefault(key, []).append(entry)
    aggregates = {key: {"rows": len(values), "throughput_vort_over_reference": math.exp(statistics.mean(math.log(r["throughput_vort_over_reference"]) for r in values)),
                        "encoded_size_vort_over_reference": math.exp(statistics.mean(math.log(r["encoded_size_vort_over_reference"]) for r in values)),
                        "weakest_row": min(values, key=lambda r:r["throughput_vort_over_reference"])["id"]} for key, values in groups.items()}
    return {"completed_rows": len(rows), "planned_rows": len(manifest["tasks"]), "complete": manifest["complete"], "aggregates": aggregates, "rows": rows,
            "scope": "allocating per-call presets; all raw rounds retained; no matched-quality frontier, prepared/streaming or isolated-memory claim"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkout", type=Path, required=True)
    parser.add_argument("--frozen-manifest", type=Path, required=True)
    parser.add_argument("--bin-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root, out = args.checkout.resolve(), args.output.resolve()
    out.mkdir(exist_ok=False)
    sys.path.insert(0, str(root / "tools/codec_bench"))
    frozen = json.loads(args.frozen_manifest.read_text())
    by_key = {f["key"]: f for f in frozen["fixtures"]}
    require(not subprocess.check_output(["git", "status", "--porcelain"], cwd=root), "Need a clean source checkout")
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    names = subprocess.check_output(["git", "ls-files", "src", "tools", "build", "build.zig", "build.zig.zon"], cwd=root, text=True).splitlines()
    hashes = {name: sha(root / name) for name in names}
    probes = {codec: {"path": str(args.bin_dir.resolve() / name)} for codec, name in (("deflate", "vort-deflate-encode-bench"), ("zstd", "vort-zstd-encode-bench"), ("brotli", "vort-br-planned-encode-bench"))}
    for probe in probes.values():
        probe["sha256"] = sha(probe["path"])
    tasks = []
    rng = random.Random(0x20261125)
    for size in ("65536", "1048576", "full"):
        cohort = []
        for codec, levels in (("deflate", (6, 9)), ("zstd", (3, 19)), ("brotli", (8, 11))):
            fixtures = sorted((f for f in by_key.values() if f["codec"] == codec and f["size"] == size), key=lambda f:f["name"])
            names_seen = set()
            for f in fixtures:
                if f["name"] in names_seen:
                    continue
                names_seen.add(f["name"])
                for level in levels:
                    cohort.append({"id": f'{codec}-{f["name"]}-{size}-L{level}', "codec": codec, "level": level,
                                   "reference_level": 12 if codec == "deflate" and level == 9 else level, "size": size,
                                   "iterations": 3 if size == "65536" else 1, "fixture": {k:f[k] for k in ("input_path", "input_bytes", "input_sha256")}})
            require(len(names_seen) == 12, "Incomplete Silesia corpus")
        rng.shuffle(cohort)
        tasks += cohort
    identities = {(t["fixture"]["input_path"], t["fixture"]["input_sha256"]) for t in tasks}
    for path, expected in identities:
        require(sha(path) == expected, "Frozen input changed")
    for ref in frozen["references"].values():
        for path, expected in ref["file_sha256"].items():
            require(sha(path) == expected, "Frozen reference changed")
    def read(path):
        return Path(path).read_text().strip()
    environment = {"platform": platform.platform(), "cpu": 15,
                   "cpu_model": next(line.split(":", 1)[1].strip() for line in Path("/proc/cpuinfo").read_text().splitlines() if line.startswith("model name")),
                   "governor": read("/sys/devices/system/cpu/cpu15/cpufreq/scaling_governor"),
                   "driver": read("/sys/devices/system/cpu/cpu15/cpufreq/scaling_driver"),
                   "turbo_disabled": read("/sys/devices/system/cpu/intel_pstate/no_turbo"),
                   "zig_version": subprocess.check_output(["zig", "version"], text=True).strip()}
    manifest = {"schema": "vort.current-encode-presets.v1", "environment": environment, "source": {"revision": revision, "sha256": hashes}, "probes": probes,
                "references": frozen["references"], "tasks": tasks, "completed": [], "complete": False,
                "policy": {"host": "development host; fixed one-core affinity; no acceptance claim", "cpu": 15, "sizes": ["65536", "1048576", "full"], "initial_wire_only_decode_validation": True}, "commands": {}}
    write(out / "manifest.json", manifest)
    env = dict(os.environ)
    env.pop("LD_PRELOAD", None)
    env.pop("LD_AUDIT", None)
    env["LD_LIBRARY_PATH"] = ":".join([str(Path(frozen["references"]["deflate"]["path"]).parent), str(Path(frozen["references"]["zstd"]["path"]).parent), str(Path(frozen["references"]["brotli"]["common"]).parent)])
    (out / "host-before.txt").write_bytes(subprocess.check_output(["ps", "-eo", "pid,psr,pcpu,comm", "--sort=-pcpu"]))
    for index, task in enumerate(tasks):
        require(subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip() == revision, "Source revision changed")
        require(not subprocess.check_output(["git", "status", "--porcelain"], cwd=root), "Source checkout changed")
        cmd = command(task, manifest, out)
        print(f'{index + 1}/{len(tasks)} {task["id"]}', flush=True)
        with (out / (task["id"] + ".stdout")).open("xb") as stdout, (out / (task["id"] + ".stderr")).open("xb") as stderr:
            result = subprocess.run(cmd, cwd=root, env=env, stdout=stdout, stderr=stderr, timeout=3600)
        require(result.returncode == 0, f'Failed {task["id"]}: {(out / (task["id"] + ".stderr")).read_text()[-2000:]}')
        validate(json.loads((out / (task["id"] + ".json")).read_text()), task, manifest)
        manifest["commands"][task["id"]] = cmd
        manifest["completed"].append(task["id"])
        write(out / "manifest.json", manifest)
        write(out / "summary.json", summary(out, manifest))
    manifest["complete"] = True
    write(out / "manifest.json", manifest)
    write(out / "summary.json", summary(out, manifest))
    (out / "host-after.txt").write_bytes(subprocess.check_output(["ps", "-eo", "pid,psr,pcpu,comm", "--sort=-pcpu"]))
    print("All 216 allocating-preset conditions completed and validated", flush=True)


if __name__ == "__main__":
    main()
