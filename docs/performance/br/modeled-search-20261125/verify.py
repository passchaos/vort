#!/usr/bin/env python3
"""Portable screen/resource/code evidence replay; no codec, ELF, Git or build."""
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tarfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / (name + ".py"))
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


def members(filename):
    result = {}
    with tarfile.open(ROOT / filename, "r:gz") as archive:
        for entry in archive:
            require(entry.isfile() and not Path(entry.name).is_absolute() and ".." not in Path(entry.name).parts, "Invalid tar member")
            require(entry.name not in result, "Duplicate tar member")
            result[entry.name] = archive.extractfile(entry).read()
    return result


def original_bytes(payloads, bindings):
    require(payloads.keys() == bindings.keys(), "Original member coverage differs")
    for name, expected in bindings.items():
        data = payloads[name]
        require(len(data) == expected["bytes"] and sha(data) == expected["sha256"], "Original member bytes differ: " + name)
        if expected.get("transform") == "gzip":
            decoded = gzip.decompress(data)
            require(len(decoded) == expected["original_bytes"] and sha(decoded) == expected["original_sha256"], "Original ELF bytes differ")


def check_archive(filename, expected):
    data = (ROOT / filename).read_bytes()
    require(len(data) == expected["bytes"] and sha(data) == expected["sha256"], "Archive identity differs: " + filename)


def replay():
    bindings = json.loads((ROOT / "archive-bindings.json").read_text())
    screens = members("screens.tar.gz")
    v3, v4 = members("resource-v3.tar.gz"), members("resource-v4.tar.gz")
    code = members("code-tests.tar.gz")
    quiet_payloads = members("quiet.tar.gz")
    check_archive("screens.tar.gz", bindings["screens_archive"])
    for filename, expected in bindings["resources"].items():
        check_archive(filename, expected)
    check_archive("code-tests.tar.gz", bindings["code_tests_archive"])
    original_bytes(screens, bindings["screen_members"])
    original_bytes(code, bindings["code_test_members"])
    check_archive("quiet.tar.gz", bindings["quiet_archive"])
    original_bytes(quiet_payloads, bindings["quiet_members"])
    shared = bindings["quiet_shared_s4_identity"]
    require(sha(screens["common/probe.zig"]) == shared["probe_sha256"]
            and sha(screens["common/provenance.zig"]) == shared["provenance_sha256"],
            "Recorded quiet shared probe identity differs")
    require(sha(gzip.decompress(screens["common/baseline.elf.gz"])) == shared["baseline_elf_sha256"]
            and sha(gzip.decompress(screens["s4-compact/candidate.elf.gz"])) == shared["candidate_elf_sha256"],
            "Recorded quiet shared ELF identity differs")
    for payload, manifest_name in ((v3, "artifact-bindings.json"), (v4, "compact-artifact-bindings.json")):
        recorded = json.loads(payload[manifest_name])["files"]
        require(payload.keys() == recorded.keys() | {manifest_name}, "Resource archive member coverage differs")
        for name, expected in recorded.items():
            data = payload[name]
            require(len(data) == expected["bytes"] and sha(data) == expected["sha256"], "Original resource member differs")
    screening = module("screening")
    stages = {label: screening.verify_stage(screens, label, entry) for label, entry in bindings["stages"].items()}
    quiet_result = module("quiet").verify(quiet_payloads, screens, bindings["stages"]["s4-compact"], screening.verify_stage)
    for stage in stages.values():
        matrix = stage["full_summary"]["matrix"][0]
        stage["observed_geomean_throughput_ratio"] = 1 / matrix["paired_geomean_ns_current_over_old"]
        stage["observed_nci_throughput_ratio"] = 1 / stage["weak_rows"]["nci"]["elapsed_ratio"]
    resource_results = module("resources").verify(v3, v4, screens)
    code_results = module("code_checks").verify(code)
    baseline_lines = len(screens["common/source/baseline-lz77.zig"].decode().splitlines())
    frozen_lines = len(screens["s4-compact/source/src/lz77.zig"].decode().splitlines())
    mother_lines = len(code["source/src/lz77.zig"].decode().splitlines())
    review = {"frozen_lz77_lines": frozen_lines, "baseline_lz77_lines": baseline_lines,
              "frozen_lz77_net_added_lines": frozen_lines - baseline_lines, "test_mother_lz77_lines": mother_lines,
              "test_mother_lz77_net_added_lines": mother_lines - baseline_lines,
              "sentinel_comment": "modeled_pair header says -1; actual Api.index_empty supports u32max; frozen source retained unchanged",
              "modeled_histogram_guard": "bounded dispatch collect_profile=false; distance_cost-5 histogram remains fixed-only",
              "split_plan": "Move modeled adapters/bridge glue and root test bodies into cohesive lz77/modeled submodules; paired/index/feedback engines already extracted; no split performed by archive task"}
    return {"schema": "vort.modeled-search.publication-summary.v1", "acceptance": quiet_result["acceptance"],
            "merge_allowed": quiet_result["merge_allowed"], "quiet_gate": quiet_result,
            "quiet_gate_results_included": True, "stages": stages, "resources": resource_results, "code_tests": code_results,
            "gate_targets": {"overall_geomean_throughput_min": 1.03, "control_throughput_min": 0.98,
                             "declared_weak_nci_throughput_min": 1.20,
                             "acceptance": "completed reserved developer-host gate rejected because weak NCI throughput <1.20; thresholds unchanged"},
            "source_review": review}


def verify():
    names = set()
    for line in (ROOT / "SHA256SUMS").read_text().splitlines():
        expected, name = line.split("  ", 1)
        require(name not in names and not Path(name).is_absolute() and ".." not in Path(name).parts, "Invalid inventory name")
        require(sha((ROOT / name).read_bytes()) == expected, "Published file hash differs")
        names.add(name)
    actual = {str(path.relative_to(ROOT)) for path in ROOT.rglob("*") if path.is_file() and path.name != "SHA256SUMS"}
    require(actual == names, "Published inventory incomplete")
    result = replay()
    require(result == json.loads((ROOT / "summary.json").read_text()), "Replayed complete publication summary differs")
    native = result["code_tests"]["native"]
    return {"schema": "vort.modeled-search.publication-verification.v1", "inventory_verified": True,
            "acceptance": result["acceptance"], "merge_allowed": result["merge_allowed"], "quiet_gate_results_included": True,
            "stage_pairs": {key: stage["verified_pairs"] for key, stage in result["stages"].items()},
            "stage_timed_calls": {key: stage["verified_timed_calls"] for key, stage in result["stages"].items()},
            "recomputed_matrices": {key: stage["full_summary"]["matrix"] for key, stage in result["stages"].items()},
            "quiet_recomputed_matrix": result["quiet_gate"]["full_summary"]["matrix"],
            "quiet_gate_checks": result["quiet_gate"]["gate_checks"],
            "quiet_all180_process_intervals_inside_reservation": True,
            "collector_restored_at_or_after_quiet_end": True,
            "resource_v3_operations": result["resources"]["v3_verified_operations"],
            "resource_v4_new_operations": result["resources"]["v4_new_verified_operations"],
            "resource_v3_peak_ratio": result["resources"]["v3_geomean_peak_over_baseline"],
            "resource_v4_peak_ratio": result["resources"]["v4_geomean_peak_over_baseline"],
            "native_tests": native["passed_tests"] if native is not None else None,
            "x86_tests": 14, "wasi_tests": 14, "full_br_pass": 1710, "full_br_skip": 1,
            "scope": "Offline compressed original bytes, frozen source/ELF/reference/input/wire/lifecycle and resource/cap arithmetic plus paired bootstrap replay including completed temporary developer-host reservation. Original code builds/tests are retained receipts. No ELF/codec/WASM/test/Git/build execution; completed quiet fails unchanged NCI20% gate, not an industry ranking."}


if __name__ == "__main__":
    print(json.dumps(verify(), indent=2, sort_keys=True))
