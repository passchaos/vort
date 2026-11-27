#!/usr/bin/env python3
"""Root BUILD_SOURCE_READY builds only; source checks and actual exit receipts."""
import hashlib
import json
import os
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = Path("/home/passchaos/project-z/vort")
TARGET = ["-O", "ReleaseFast", "-target", "x86_64-linux-gnu", "-mcpu", "skylake+pku+sgx"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(name):
    return json.loads((ROOT / name).read_text())


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def sources(folder):
    return {str(p.relative_to(folder)): sha(p) for p in sorted((folder / "src").rglob("*")) if p.is_file()}


def source_state(ready):
    expected = read("candidate-source-files.json")
    if sources(REPO) != expected or sources(Path(ready["candidate_src_tree"])) != expected:
        raise RuntimeError("Candidate live/frozen source changed since Root freeze")
    if sources(Path(ready["baseline_actual_git_export_tree"])) != read("baseline46d-source-files.json"):
        raise RuntimeError("Actual Git46d baseline source changed")
    return {"candidate_source_manifest_sha256": sha(ROOT / "candidate-source-files.json"), "baseline_actual_Git46d_manifest_sha256": sha(ROOT / "baseline46d-source-files.json"), "candidate_live_frozen_equal": True, "actual_baseline_source_equal": True}


def main():
    ready = read("BUILD_SOURCE_READY.json")
    if ready["issued_by"] != "/root" or not ready["BUILD_SOURCE_READY"] or not ready["build_and_untimed_preflight_only"]:
        raise RuntimeError("Root build/preflight authorization required")
    if (ROOT / "build-results.json").exists():
        raise RuntimeError("Build attempt already exists; preserve its result")
    candidate = Path(ready["candidate_src_tree"])
    baseline = Path(ready["baseline_actual_git_export_tree"])
    old_object = Path(read("assets/actual-old-object-build.json")["output"])
    if sha(old_object) != read("assets/actual-old-object-build.json")["output_sha256"]:
        raise RuntimeError("Reused old record object identity changed")
    obj = ROOT / "build/candidate-record.o"
    env = dict(os.environ)
    env.update({"ZIG_GLOBAL_CACHE_DIR": str(ROOT / "build/global-cache"), "ZIG_LOCAL_CACHE_DIR": str(ROOT / "build/local-cache")})
    stages = [("candidate-record", ["taskset", "-c", "1", "zig", "build-obj"] + TARGET + [str(candidate / "src/br/encoder/record_optimal_object.zig"), "-femit-bin=" + str(obj)], obj)]
    for name, tree, object_path, probe in (("baseline-controls", baseline, old_object, ROOT / "harness/public-options-probe.zig"), ("candidate", candidate, obj, ROOT / "harness/probe.zig"), ("candidate-controls", candidate, obj, ROOT / "harness/public-options-probe.zig")):
        exe = ROOT / "bin" / name
        command = ["taskset", "-c", "1", "zig", "build-exe", str(object_path), "-lc"] + TARGET + ["--dep", "vort_br", "--dep", "provenance", "-Mroot=" + str(probe)] + TARGET + ["-Mvort_br=" + str(tree / "src/br.zig")] + TARGET + ["-Mprovenance=" + str(ROOT / "harness/provenance.zig"), "-femit-bin=" + str(exe)]
        stages.append((name, command, exe))
    records = []
    status = {"HEAVY": 1, "terminal": False, "build_stages_completed": 0, "owning_warmup_calls": 0, "external_decode_calls": 0, "timed_samples": 0, "sampling_released": False}
    write(ROOT / "execution-status.json", status)
    try:
        for name, command, output in stages:
            before = source_state(ready)
            if output.exists():
                raise RuntimeError("Build output already exists: " + name)
            stdout, stderr = (ROOT / "build" / (name + suffix) for suffix in (".stdout", ".stderr"))
            status["stage"] = name
            write(ROOT / "execution-status.json", status)
            print("build start", name, flush=True)
            started = datetime.now(timezone.utc).isoformat()
            begin = time.monotonic()
            with stdout.open("wb") as out, stderr.open("wb") as err:
                result = subprocess.run(command, cwd=ROOT, env=env, stdout=out, stderr=err)
            receipt = {"stage": name, "argv": command, "cache_environment": {k: env[k] for k in ("ZIG_GLOBAL_CACHE_DIR", "ZIG_LOCAL_CACHE_DIR")}, "actual_exit_code": result.returncode, "started_utc": started, "completed_utc": datetime.now(timezone.utc).isoformat(), "elapsed_seconds": time.monotonic() - begin, "source_before": before, "stdout": str(stdout), "stdout_sha256": sha(stdout), "stderr": str(stderr), "stderr_sha256": sha(stderr), "output": str(output), "output_sha256": sha(output) if output.is_file() else None}
            records.append(receipt)
            write(ROOT / "build" / (name + ".receipt.json"), receipt)
            write(ROOT / "build-results.json", {"completed": False, "success": False, "stages": records})
            receipt["source_after"] = source_state(ready)
            write(ROOT / "build" / (name + ".receipt.json"), receipt)
            write(ROOT / "build-results.json", {"completed": False, "success": False, "stages": records})
            status["build_stages_completed"] += 1
            write(ROOT / "execution-status.json", status)
            print("build exit", name, result.returncode, flush=True)
            if result.returncode:
                print(stderr.read_text(), flush=True)
                raise RuntimeError("Build failed; stop before codec preflight")
        write(ROOT / "build-results.json", {"completed": True, "success": True, "stages": records, "baseline_control_uses_actual_Git46d_SRC": True, "generic_probe_sha256": sha(ROOT / "harness/public-options-probe.zig"), "generic_small_uses_same_ELFs": True, "baseline_primary_and_reference_reused_not_rebuilt": True})
    finally:
        status.update({"HEAVY": 0, "terminal": True})
        write(ROOT / "execution-status.json", status)


if __name__ == "__main__":
    main()
