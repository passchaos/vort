#!/usr/bin/env python3
"""Registered warm1/timed1 primary pilot; diagnostic only, full merge gate false."""
import argparse
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent / "harness"))
import stats

ROOT = Path(__file__).resolve().parent
BASELINE = Path("/tmp/vort-br-original-command-split-reuse-ab.egqd38jr/bin/candidate")


def read(name):
    return json.loads((ROOT / name).read_text())


def small_sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def now():
    return datetime.now(timezone.utc).isoformat()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", type=Path, required=True)
    args = parser.parse_args()
    release = json.loads(args.release.read_text())
    ready = read("BUILD_SOURCE_READY.json")
    seal = read("pilot-readiness-seal.json")
    preflight = read("preflight-results.json")
    required = {"schema": "vort.brotli.round4ctx.pilot-release.v1", "issued_by": "/root", "epoch_root": str(ROOT), "phase": "pilot", "purpose": "diagnostic-only", "released": True, "global_heavy_terminal": True, "narrow_gates_accepted": True, "full_gate_passed": False, "candidate_source_manifest_sha256": ready["candidate_source_manifest_sha256"], "protocol_sha256": small_sha(ROOT / "protocols/main-pilot.json"), "sampler_sha256": small_sha(Path(__file__)), "readiness_seal_sha256": small_sha(ROOT / "pilot-readiness-seal.json")}
    if any(release.get(k) != v for k, v in required.items()) or not release.get("release_id"):
        raise RuntimeError("Fresh Root diagnostic pilot release with exact bindings required")
    if datetime.fromisoformat(release["issued_utc"]) <= datetime.fromisoformat(seal["sealed_utc"]):
        raise RuntimeError("Old release cannot enable this new epoch")
    if not preflight["completed"] or not preflight["success"] or preflight["processes"] != 84:
        raise RuntimeError("Completed84 warm-only external decode/memcmp preflight required")
    narrow = read("NARROW_GATES_READY.json")
    if not narrow["accepted_for_pilot_diagnostic_prerequisites"] or narrow["candidate_source_manifest_sha256"] != ready["candidate_source_manifest_sha256"]:
        raise RuntimeError("Matching Root narrow Native/WASI/resource gates required")
    protocol = read("protocols/main-pilot.json")
    if protocol["pairs"] != 24 or protocol["processes"] != 48 or protocol["CI"] is not None or protocol["GM_min"] != 1.03 or protocol["every_row_point_floor"] != .98 or protocol["full_gate_passed"] is not False:
        raise RuntimeError("Registered two-pair diagnostic policy changed")
    path = ROOT / "pilot/run-manifest.json"
    if path.exists():
        raise RuntimeError("Pilot attempt exists; no retry/overwrite/append")
    candidate = ROOT / "bin/candidate"
    candidate_build = next(b for b in read("build-results.json")["stages"] if b["stage"] == "candidate")
    executables = {"baseline": (BASELINE, ready["baseline_actual_git_revision"], protocol["baseline_actual_ELF_sha256"]), "candidate": (candidate, ready["candidate_revision"], candidate_build["output_sha256"])}
    # Sources and ELF identities were sealed before Root HEAVY0. No source-tree
    # or archive rehash runs here; each original child records its own ELF SHA.
    fixtures = read("fixtures-method.json")
    manifest = {"phase": "pilot", "purpose": "diagnostic-only", "release": release, "release_sha256": small_sha(args.release), "protocol": protocol, "source_manifest_sha256": ready["candidate_source_manifest_sha256"], "started_utc": now(), "pairs": [], "attempts": [], "completed": False, "terminal": False, "full_gate_passed": False, "merge_eligible": False}
    status = {"HEAVY": 1, "terminal": False, "timed_processes_completed": 0, "completed_pairs": 0, "full_gate_passed": False}
    write(path, manifest)
    write(ROOT / "pilot-execution-status.json", status)
    try:
        for round_index in range(2):
            order = ["baseline", "candidate"] if round_index == 0 else ["candidate", "baseline"]
            for fixture in fixtures:
                pair = {"case": fixture["case"], "round": round_index, "order": order, "processes": {}, "loadavg": Path("/proc/loadavg").read_text().strip()}
                manifest["pairs"].append(pair)
                write(path, manifest)
                for variant in order:
                    exe, revision, elfsha = executables[variant]
                    stem = ROOT / "pilot/runs" / (f"{round_index:02d}-{fixture['case']}-{variant}")
                    output, stdout, stderr = (stem.with_suffix(s) for s in (".json", ".stdout", ".stderr"))
                    stem.parent.mkdir(parents=True, exist_ok=True)
                    if any(p.exists() for p in (output, stdout, stderr)):
                        raise RuntimeError("Raw attempt paths already exist")
                    command = ["taskset", "-c", "2", str(exe), "--input", fixture["path"], "--output", str(output), "--source-revision", revision, "--iterations", "1", "--window", "16"]
                    with stdout.open("wb") as out, stderr.open("wb") as err:
                        result = subprocess.run(command, cwd=ROOT, stdout=out, stderr=err)
                    attempt = {"case": fixture["case"], "round": round_index, "variant": variant, "argv": command, "actual_exit_code": result.returncode, "output": str(output), "stdout": str(stdout), "stderr": str(stderr)}
                    manifest["attempts"].append(attempt)
                    write(path, manifest)
                    if result.returncode:
                        raise RuntimeError("Process failed; preserve first raw attempt and stop")
                    value = json.loads(output.read_text())
                    frozen = next(r for r in preflight["rows"] if r["family"] == "main" and r["case"] == fixture["case"] and r["variant"] == variant)
                    if value["iterations"] != 1 or len(value["samples"]) != 1 or value["warmup_owned_encode_free_calls"] != 1:
                        raise RuntimeError("Original warm1/timed1 lifecycle changed")
                    info = value["provenance"]
                    expected = {"optimize": "ReleaseFast", "target_cpu": "skylake+pku+sgx", "target_arch": "x86_64", "target_os": "linux", "target_abi": "gnu", "cpu_affinity": "2", "affinity_cpu_count": 1, "benchmark_threads": 1, "codec_thread_policy": "single", "executable_sha256": elfsha}
                    if any(info[k] != v for k, v in expected.items()) or value["source_revision"] != revision or value["input_sha256"] != fixture["sha256"] or value["quality"] != 8 or value["mode"] != "generic" or value["requested_window_bits"] != 16:
                        raise RuntimeError("Frozen input/options/source/target/ELF changed")
                    sample = value["samples"][0]
                    if value["warm_wire_sha256"] != frozen["wire_sha256"] or value["warm_wire_bytes"] != frozen["wire_bytes"] or sample["wire_bytes"] != frozen["wire_bytes"] or sample["mix"] != frozen["wire_bytes"] or sample["owned_encode_free_ns"] <= 0:
                        raise RuntimeError("Initial wire or timed lengths/mix changed")
                    pair["processes"][variant] = {"path": str(output), "raw_ns": [sample["owned_encode_free_ns"]]}
                    status["timed_processes_completed"] += 1
                    write(path, manifest)
                    write(ROOT / "pilot-execution-status.json", status)
                status["completed_pairs"] += 1
                write(path, manifest)
                print("pilot pair", round_index, fixture["case"], flush=True)
        summary = stats.pilot_summary(manifest["pairs"], protocol["case_order"])
        summary.update({"completed": True, "pairs": 24, "processes": 48, "purpose": "diagnostic-only", "full_gate_passed": False, "merge_eligible": False})
        write(ROOT / "pilot-summary.json", summary)
        manifest.update({"completed": True, "terminal": True, "completed_utc": now()})
        write(path, manifest)
    except BaseException as error:
        manifest.update({"completed": False, "terminal": True, "failure": str(error)})
        write(path, manifest)
        raise
    finally:
        status.update({"HEAVY": 0, "terminal": True})
        write(ROOT / "pilot-execution-status.json", status)


if __name__ == "__main__":
    main()
