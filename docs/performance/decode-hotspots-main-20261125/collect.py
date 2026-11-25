"""Collect scoped cold decode diagnostics on six frozen weak/control rows."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

from evidence import reference_files, require, validate_manifest, validate_report
from fixtures import sha256
from matrix import ROOT, arguments, environment, source_state, write_json


ROWS = {
    "deflate-mr64-l9": ("deflate/mr/65536/9", 10000),
    "deflate-mr64-l6": ("deflate/mr/65536/6", 10000),
    "deflate-mr1m-l9": ("deflate/mr/1048576/9", 800),
    "brotli-mozilla-full-q11": ("brotli/mozilla/full/11", 4),
    "brotli-mozilla-1m-q11": ("brotli/mozilla/1048576/11", 128),
    "brotli-mozilla-full-q6": ("brotli/mozilla/full/6", 4),
}


def launch(command, env, stdout, stderr):
    with stdout.open("xb") as output, stderr.open("xb") as errors:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=output, stderr=errors, timeout=180)
    require(result.returncode == 0, f"Failed ({result.returncode}): {command}: {stderr.read_text()[-4000:]}")


def probe_command(probe, task, manifest):
    argv = arguments(probe, task, manifest["references"], manifest["config"])
    return ["taskset", "-c", str(manifest["config"]["cpu"])] + argv


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frozen-manifest", type=Path, required=True)
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--payload-probe", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    opts = parser.parse_args()
    out = opts.out_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    probe, payload_probe = opts.probe.resolve(), opts.payload_probe.resolve()
    frozen = validate_manifest(json.loads(opts.frozen_manifest.read_text()))
    by_key = {f["key"]: f for f in frozen["fixtures"]}
    cpu = frozen["config"]["cpu"]
    require(cpu in os.sched_getaffinity(0), "Cannot pin benchmark children")
    require(not subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT), "Profile a clean checkout")
    manifest = {"schema": "vort.decode-hotspots.v1", "frozen_manifest_sha256": sha256(opts.frozen_manifest),
                "source": source_state(), "probe": str(probe), "probe_sha256": sha256(probe),
                "payload_probe": str(payload_probe), "payload_probe_sha256": sha256(payload_probe),
                "references": frozen["references"], "config": frozen["config"], "environment": environment(cpu),
                "rows": {}, "commands": {}}
    for codec, ref in manifest["references"].items():
        for path in reference_files(ref, codec):
            require(sha256(path) == ref["file_sha256"][path], "Frozen reference changed")
    env = dict(os.environ)
    env.pop("LD_LIBRARY_PATH", None)
    launch(["ps", "-eo", "pid,psr,pcpu,comm", "--sort=-pcpu"], env, out / "host-before.txt", out / "host-before.stderr")

    for name, (key, profile_iterations) in ROWS.items():
        fixture = by_key[key]
        for prefix in ("input", "encoded"):
            path_field = "input_path" if prefix == "input" else "encoded_input_path"
            path = Path(fixture[path_field])
            require(path.stat().st_size == fixture[prefix + "_bytes"] and sha256(path) == fixture[prefix + "_sha256"], f"Wrong fixture: {path}")
        require(source_state() == manifest["source"] and environment(cpu) == manifest["environment"], "Source or host changed")
        codec = fixture["codec"]
        base = {"fixture": fixture, "lifecycle": "cold", "iterations": manifest["config"]["iterations"][fixture["size"]]}
        manifest["rows"][name] = {"task": base, "profile_iterations": profile_iterations}
        child_env = dict(env)
        if codec == "brotli":
            child_env["LD_LIBRARY_PATH"] = str(Path(manifest["references"]["brotli"]["common"]).parent)
        print(f"{name}: ordinary, Vort-only PMU groups, physical self samples", flush=True)
        for mode, group in (("wall", None), ("branches", "branches"), ("branch-misses", "branch-misses")):
            config = {**manifest["config"], "perf_group": group}
            context = {**manifest, "config": config}
            cmd = probe_command(probe, base, context)
            tag = f"{name}.{mode}"
            manifest["commands"][tag] = cmd
            path = out / (tag + ".json")
            launch(cmd, child_env, path, out / (tag + ".stderr"))
            validate_report(json.loads(path.read_text()), base, context)

        context = {**manifest, "config": {**manifest["config"], "warmup": 0, "rounds": 2}}
        task = {**base, "iterations": profile_iterations}
        data = out / (name + ".perf.data")
        cmd = ["perf", "record", "-o", str(data), "-e", "cycles:u", "-F", "997", "--"] + probe_command(probe, task, context)
        manifest["commands"][name + ".profile"] = cmd
        sample_report = out / (name + ".profile.json")
        launch(cmd, child_env, sample_report, out / (name + ".profile.stderr"))
        validate_report(json.loads(sample_report.read_text()), task, context)
        script_cmd = ["perf", "script", "--no-demangle", "-i", str(data), "-F", "period,ip,sym,dso"]
        manifest["commands"][name + ".samples"] = script_cmd
        samples = out / (name + ".samples.txt")
        launch(script_cmd, env, samples, out / (name + ".samples.stderr"))
        require(sum(bool(re.match(r"\s*\d+\s+[0-9a-f]+\s", line)) for line in samples.read_text().splitlines()) >= 500, f"Too few symbolized samples: {name}")
        periods_cmd = ["perf", "script", "--no-demangle", "-i", str(data), "-F", "period"]
        manifest["commands"][name + ".periods"] = periods_cmd
        launch(periods_cmd, env, out / (name + ".periods.txt"), out / (name + ".periods.stderr"))

        if codec == "brotli":
            payload = out / (name + ".payload.json")
            cmd = ["taskset", "-c", str(cpu), str(payload_probe), "--input", fixture["encoded_input_path"],
                   "--plain", fixture["input_path"], "--output", str(payload)]
            manifest["commands"][name + ".payload"] = cmd
            launch(cmd, env, out / (name + ".payload.stdout"), out / (name + ".payload.stderr"))
            require(bool(json.loads(payload.read_text())), f"Missing payload report: {name}")
        write_json(out / "manifest.json", manifest)
    require(source_state() == manifest["source"] and environment(cpu) == manifest["environment"], "Source or host changed")
    require(sha256(probe) == manifest["probe_sha256"] and sha256(payload_probe) == manifest["payload_probe_sha256"], "Probe changed")
    launch(["ps", "-eo", "pid,psr,pcpu,comm", "--sort=-pcpu"], env, out / "host-after.txt", out / "host-after.stderr")
    print("Validated six ordinary/PMU/sample rows and three logical payload reports", flush=True)


if __name__ == "__main__":
    main()
