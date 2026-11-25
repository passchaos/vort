"""Run or verify paired process screens of the Brotli packed-distance prototype."""
import argparse
import json
import os
from pathlib import Path
import random
import subprocess

from evidence import bootstrap_log_mean, reference_files, require, validate_manifest, validate_report
from fixtures import sha256
from matrix import ROOT, arguments, environment, write_json

TARGET = "brotli/mozilla/full/11"
ROWS = (
    TARGET, "brotli/mozilla/full/6", "brotli/mozilla/1048576/11", "brotli/mozilla/65536/11",
    "brotli/nci/full/11", "brotli/samba/full/6", "brotli/samba/full/11", "brotli/ooffice/full/11",
    "brotli/mr/full/6", "brotli/xml/65536/6", "brotli/x-ray/65536/11", "brotli/reymont/1048576/6",
)
SIDES = ("baseline", "candidate")
OUTER_PAIRS = 6
SEED = 0x20261125


def order(sequence, row_index):
    return SIDES if (sequence + row_index) % 2 == 0 else SIDES[::-1]


def command(manifest, side, task):
    return ["taskset", "-c", str(manifest["config"]["cpu"])] + arguments(
        manifest["probes"][side]["path"], task, manifest["references"], manifest["config"],
    )


def run(opts):
    root = opts.output.resolve()
    root.mkdir(parents=True, exist_ok=False)
    frozen = validate_manifest(json.loads(opts.frozen_manifest.read_text()))
    fixtures = {f["key"]: f for f in frozen["fixtures"]}
    config = {**frozen["config"], "rounds": 2, "warmup": 2, "perf_group": None}
    require(config["cpu"] in os.sched_getaffinity(0), "Benchmark CPU is unavailable")
    tasks = [{"fixture": fixtures[row], "lifecycle": "cold", "iterations": config["iterations"][fixtures[row]["size"]]} for row in ROWS]
    ref = frozen["references"]["brotli"]
    for path in reference_files(ref, "brotli"):
        require(sha256(path) == ref["file_sha256"][path], f"Reference changed: {path}")
    for task in tasks:
        f = task["fixture"]
        for path, field in ((f["input_path"], "input"), (f["encoded_input_path"], "encoded")):
            require(Path(path).stat().st_size == f[field + "_bytes"] and sha256(path) == f[field + "_sha256"], f"Frozen fixture changed: {path}")
    probes = {side: {"path": str(getattr(opts, side).resolve()), "sha256": sha256(getattr(opts, side))} for side in SIDES}
    manifest = {"schema": "vort.br-packed-distance-screen.v1", "base_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "frozen_manifest_sha256": sha256(opts.frozen_manifest), "candidate_patch_sha256": sha256(opts.patch),
                "tasks": tasks, "config": config, "environment": environment(config["cpu"]),
                "references": {"brotli": ref}, "probes": probes, "outer_pairs": OUTER_PAIRS, "schedule": []}
    require(probes["baseline"]["sha256"] == frozen["probe_sha256"], "Wrong pinned baseline executable")
    require(probes["baseline"]["sha256"] != probes["candidate"]["sha256"], "Candidate executable identical to baseline")
    env = {**os.environ, "LD_LIBRARY_PATH": str(Path(ref["common"]).parent)}
    snapshots = ["ps", "-eo", "pid,psr,pcpu,comm", "--sort=-pcpu"]
    (root / "host-before.txt").write_bytes(subprocess.check_output(snapshots))
    rng = random.Random(SEED)
    for sequence in range(OUTER_PAIRS):
        row_order = list(range(len(tasks)))
        rng.shuffle(row_order)
        for index in row_order:
            task = tasks[index]
            first, second = order(sequence, index)
            print(sequence, task["fixture"]["key"], first, flush=True)
            for side in (first, second):
                tag = f"{sequence:02d}.{index:02d}.{side}"
                argv = command(manifest, side, task)
                with (root / (tag + ".json")).open("xb") as stdout, (root / (tag + ".stderr")).open("xb") as stderr:
                    subprocess.run(argv, cwd=ROOT, env=env, stdout=stdout, stderr=stderr, check=True, timeout=120)
                report = json.loads((root / (tag + ".json")).read_text())
                validate_report(report, task, {**manifest, "probe_sha256": probes[side]["sha256"]}, verify_files=False)
            manifest["schedule"].append([sequence, index, first])
        write_json(root / "manifest.json", manifest)
    (root / "host-after.txt").write_bytes(subprocess.check_output(snapshots))
    require(manifest["environment"] == environment(config["cpu"]), "Environment changed")
    require(all(sha256(desc["path"]) == desc["sha256"] for desc in probes.values()), "Probe mutated during campaign")
    require(sha256(opts.patch) == manifest["candidate_patch_sha256"], "Candidate patch changed")
    write_json(root / "summary.json", summarize(root))


def summarize(root):
    manifest = json.loads((root / "manifest.json").read_text())
    require(manifest["schema"] == "vort.br-packed-distance-screen.v1", "Wrong screen schema")
    tasks = manifest["tasks"]
    require(tuple(t["fixture"]["key"] for t in tasks) == ROWS and manifest["outer_pairs"] == OUTER_PAIRS, "Incomplete campaign design")
    rng = random.Random(SEED)
    scheduled = []
    rows = [{"pairs": []} for _ in tasks]
    expected_json = {"manifest.json"}
    for sequence in range(OUTER_PAIRS):
        indices = list(range(len(tasks)))
        rng.shuffle(indices)
        for index in indices:
            first, _ = order(sequence, index)
            scheduled.append([sequence, index, first])
            samples = {}
            for side in SIDES:
                tag = f"{sequence:02d}.{index:02d}.{side}"
                expected_json.add(tag + ".json")
                require((root / (tag + ".stderr")).read_bytes() == b"", f"Unexpected stderr: {tag}")
                report = json.loads((root / (tag + ".json")).read_text())
                valid = validate_report(report, tasks[index], {**manifest, "probe_sha256": manifest["probes"][side]["sha256"]}, verify_files=False)
                samples[side] = valid["summary"]["vort_median_ns"]
            # Reuse the fixed-row order-stratified bootstrap. Its reference is the
            # baseline Vort executable, NOT the foreign library in either child.
            rows[index]["pairs"].append({"first": "vort" if first == "candidate" else "reference",
                                         "vort_ns": samples["candidate"], "reference_ns": samples["baseline"]})
    require(manifest["schedule"] == scheduled, "Incomplete or changed execution order")
    require({p.name for p in root.glob("*.json")} - {"summary.json"} == expected_json, "Missing or extra report")

    def calc(group, seed):
        stats = bootstrap_log_mean(group, seed, 4000)
        low, high = stats["ci95"]
        return {"candidate_over_baseline": stats["throughput_ratio_geomean"], "ci95": [1 / high, 1 / low]}

    per_row = {name: calc([row], SEED + i + 1) for i, (name, row) in enumerate(zip(ROWS, rows))}
    return {"result": calc(rows, SEED), "rows": per_row,
            "weakest_control": min((name for name in ROWS if name != TARGET), key=lambda name: per_row[name]["candidate_over_baseline"]),
            "outer_pairs": len(scheduled), "children": 2 * len(scheduled)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest="mode", required=True)
    record = modes.add_parser("run")
    for name in ("output", "frozen-manifest", "baseline", "candidate", "patch"):
        record.add_argument("--" + name, type=Path, required=True)
    verify = modes.add_parser("verify")
    verify.add_argument("capture", type=Path)
    opts = parser.parse_args()
    if opts.mode == "run":
        run(opts)
    else:
        require(summarize(opts.capture) == json.loads((opts.capture / "summary.json").read_text()), "Screen summary does not reproduce")
        print("Verified all interleaved public Brotli decode results")


if __name__ == "__main__":
    main()
