#!/usr/bin/env python3
"""Verify both preserved resource versions without rerunning the encoder."""
import hashlib
import json
import math
from pathlib import Path
import statistics


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def check_resource(report, wire):
    require(report["passed"] and report["oracle_roundtrip_verified"] and report["force_moving_growth"], "Resource contract/policy failed")
    require(len(wire) == report["oracle_wire_bytes"] and sha(wire) == report["oracle_wire_sha256"], "Resource wire binding differs")
    peak = report["unlimited"]["tracked_peak"]
    for phase, cap in (("unlimited", None), ("exact_peak", peak), ("one_below_peak", peak - 1)):
        result = report[phase]
        profile = result["profile"]
        require(result["limit"] == profile["limit"] == cap and profile["available"], "Resource cap/profile policy differs")
        require(result["tracked_peak"] == result["tracked_owned_peak"] == profile["peak_requested_bytes"], "Profile/tracker peak differs")
        require(profile["live_requested_bytes"] == result["tracked_live_after_caller_free"] == 0, "Resource not zero live")
        require(result["tracked_allocated"] == result["tracked_freed_after_caller_free"], "Resource allocated/freed ledger differs")
        require(result["tracked_allocated"] - result["tracked_freed_after_encode"] == result["tracked_live_after_encode"], "Resource output handoff differs")
        require(cap is None or result["tracked_peak"] <= cap, "Resource cap exceeded")
        if phase == "one_below_peak":
            require(result["error_name"] == "WorkingMemoryLimitExceeded" and result["wire_bytes"] is None and result["tracked_live_after_encode"] == 0, "Quota refusal swallowed or changed")
        else:
            require(result["error_name"] == "" and result["wire_equal"] and result["tracked_peak"] == peak, "Resource exact/unlimited success differs")
            require(result["wire_sha256"] == report["oracle_wire_sha256"] and result["wire_bytes"] == result["tracked_live_after_encode"] == len(wire), "Resource output differs")
    return peak


def verify(v3, v4, screens):
    source = json.loads(v3["source-identity.json"])
    compact_source = json.loads(v4["compact-source-identity.json"])
    require(source["helper_unmodified"] and len(set(source["memory_helper_sha256"].values())) == 1, "Resource helpers differ")
    for variant in ("baseline", "candidate"):
        require(sha(v3["bin/" + variant]) == source["builds"][variant]["executable_sha256"], "Resource v3 ELF differs")
    require(sha(v4["bin/compact"]) == compact_source["build"]["executable_sha256"], "Resource v4 ELF differs")
    require(v3["probe.zig"] == v4["probe.zig"] and sha(v3["probe.zig"]) == source["common_probe_sha256"], "Resource common probe differs")
    for variant in ("baseline", "candidate"):
        require(sha(v3["sources/" + variant + "/src/tests/br_total_memory_helpers.zig"])
                == source["memory_helper_sha256"][variant], "Actual v3 tracking helper bytes differ")
        require(sha(v3["sources/" + variant + "/resource_codec.zig"])
                == source["common_wrapper_sha256"], "Actual v3 codec wrapper bytes differ")
    require(sha(v4["sources/compact/src/tests/br_total_memory_helpers.zig"])
            == compact_source["memory_helper_sha256"]
            == compact_source["build"]["memory_helper_sha256"], "Actual compact tracking helper bytes differ")
    require(sha(v4["sources/compact/resource_codec.zig"]) == source["common_wrapper_sha256"],
            "Actual compact codec wrapper bytes differ")
    for package, manifest_file, source_prefix, stage in (
        (v3, "candidate-source-sha256.json", "sources/candidate/", "s3-first-bound"),
        (v4, "compact-source-sha256.json", "sources/compact/", "s4-compact"),
    ):
        manifest = json.loads(package[manifest_file])
        require(manifest == json.loads(screens[stage + "/candidate-source-sha256.json"]), "Resource/performance source manifest differs")
        for path, expected in manifest.items():
            require(sha(package[source_prefix + path]) == expected, "Resource source bytes differ")
    fixtures = json.loads(v3["fixtures.json"])
    require(len(fixtures) == 14, "Resource controls/corpus incomplete")
    rows = []
    for fixture in fixtures:
        case = fixture["case"]
        data = v3["fixtures/" + Path(fixture["path"]).name]
        require(len(data) == fixture["bytes"] == 65536 and sha(data) == fixture["sha256"], "Resource input bytes differ")
        baseline_wire = v3["runs/" + case + "-baseline.br"]
        wires = {"baseline": baseline_wire, "v3": v3["runs/" + case + "-candidate.br"], "v4": v4["runs-compact/" + case + "-compact.br"]}
        require(wires["baseline"] == wires["v3"] == wires["v4"], "Resource baseline/v3/v4 wires differ")
        reports = {"baseline": json.loads(v3["runs/" + case + "-baseline.json"]),
                   "v3": json.loads(v3["runs/" + case + "-candidate.json"]),
                   "v4": json.loads(v4["runs-compact/" + case + "-compact.json"])}
        resources = {}
        for name, report in reports.items():
            info = report["provenance"]
            build = compact_source["build"] if name == "v4" else source["builds"]["baseline" if name == "baseline" else "candidate"]
            require(info["executable_sha256"] == build["executable_sha256"], "Per-report resource ELF binding differs")
            require(report["case"] == case and report["input_bytes"] == 65536
                    and report["input_sha256"] == fixture["sha256"], "Per-report resource case/input differs")
            require(info["cpu_affinity"] == "1" and info["affinity_cpu_count"] == 1
                    and info["benchmark_threads"] == 1 and info["zig_version"] == "0.16.0"
                    and info["optimize"] == "ReleaseFast" and info["target_abi"] == "gnu"
                    and info["target_cpu"] == "skylake+pku+sgx", "Per-report resource CPU/target differs")
            expected_identity = (source["baseline_revision"] if name == "baseline" else
                                 "e41aa51c+candidate-manifest:" + source["candidate_manifest_sha256"] if name == "v3" else
                                 "e41aa51c+compact-v4-manifest:" + compact_source["settings"]["source_manifest_sha256"])
            require(report["source_identity"] == expected_identity, "Per-report resource source identity differs")
            require(report["quality"] == 8 and report["mode"] == "generic" and report["window_bits"] == 16, "Resource options differ")
            check_resource(report, wires[name])
            result = report["unlimited"]
            resources[name] = {"peak": result["tracked_peak"], "allocated": result["tracked_allocated"],
                               "freed": result["tracked_freed_after_caller_free"], "alloc_requests": result["alloc_requests"],
                               "resize_requests": result["resize_requests"], "remap_requests": result["remap_requests"],
                               "free_requests": result["free_requests"]}
        rows.append({"case": case, "input_sha256": fixture["sha256"], "resources": resources})
    selected = [row for row in rows if row["case"] not in ("rle", "opaque")]
    peak_v3 = math.exp(statistics.mean(math.log(row["resources"]["v3"]["peak"] / row["resources"]["baseline"]["peak"]) for row in selected))
    peak_v4 = math.exp(statistics.mean(math.log(row["resources"]["v4"]["peak"] / row["resources"]["baseline"]["peak"]) for row in selected))
    require(peak_v3 == json.loads(v3["summary.json"])["silesia_12"]["geomean_candidate_over_baseline_peak"], "Resource v3 aggregate differs")
    require(peak_v4 == json.loads(v4["compact-summary.json"])["silesia12"]["v4_over_baseline_peak"], "Resource v4 aggregate differs")
    return {"rows": rows, "v3_geomean_peak_over_baseline": peak_v3, "v4_geomean_peak_over_baseline": peak_v4,
            "v3_verified_operations": 84, "v4_new_verified_operations": 42, "all_exact_cap_and_one_below_contracts_pass": True,
            "scope": "Whole-operation requested heap via unmodified TrackingAllocator forced-moving growth and public memory_profile, control/output counted; input/oracle/decode/report/stack/bookkeeping/internal remap/native RSS excluded. Original source-build/parent OOM tests are retained receipts, not rerun here."}
