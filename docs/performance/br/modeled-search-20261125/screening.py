#!/usr/bin/env python3
"""Verify preserved screening calls and replay pure paired statistics."""
import contextlib
import gzip
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import tempfile

WEAK = {"nci", "mozilla", "dickens"}
BASELINE_CID = "c2c8f250302ca2f223740076482dd95b1788eeb1"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def verify_stage(payloads, label, binding):
    load = lambda name: json.loads(payloads[label + "/" + name])
    settings, builds = load("settings.json"), load("build-results.json")
    manifest, initial, summary = load("run-manifest.json"), load("preflight-summary.json"), load("summary.json")
    fixtures = {row["case"]: row for row in load("fixtures.json")}
    sources = load("candidate-source-sha256.json")
    baseline = gzip.decompress(payloads["common/baseline.elf.gz"])
    candidate = gzip.decompress(payloads[label + "/candidate.elf.gz"])
    require(builds["old_exact"]["success"] and builds["current"]["success"], "Screen build receipt incomplete")
    require(builds["old_exact"]["revision"] == settings["variants"]["old_exact"] == BASELINE_CID, "Reused baseline CID misclassified")
    require(sha(baseline) == builds["old_exact"]["executable_sha256"] == binding["baseline_elf_sha256"], "Baseline ELF differs")
    require(sha(candidate) == builds["current"]["executable_sha256"] == binding["candidate_elf_sha256"], "Candidate ELF differs")
    require(settings["variants"]["current"] == builds["current"]["revision"], "Candidate source label differs")
    for name, expected in sources.items():
        require(sha(payloads[label + "/source/" + name]) == expected, "Frozen screen source differs")
    if label in ("s3-first-bound", "s4-compact"):
        source = payloads[label + "/source/src/lz77.zig"].decode()
        bounded = source.split("pub fn optimalPlanAllocWithCostModelBounded(", 1)[1].split("\n}", 1)[0]
        require(re.search(r"true\s*,\s*false\s*,\s*true", bounded) is not None,
                "Bounded modeled dispatch no longer excludes fixed-only collect_profile")
    decoder = load("decoder-binding.json")
    require(decoder["version"] == "1.2.0" and decoder["version_number"] == 0x1002000, "Decoder receipt differs")
    for record in decoder["files"]:
        require(sha(payloads["common/references/" + Path(record["path"]).name]) == record["sha256"], "Pinned closure differs")
    require(len(payloads["common/references/BROTLI-LICENSE"]) > 0, "Brotli license missing")
    require(len(fixtures) == 12 and len(initial["rows"]) == 24 and initial["lanes"] == ["explicit16"], "Screen preflight matrix differs")
    for fixture in fixtures.values():
        data = payloads["common/fixtures/" + Path(fixture["path"]).name]
        require(len(data) == fixture["bytes"] == 65536 and sha(data) == fixture["sha256"], "Frozen screen input differs")
    for row in initial["rows"]:
        name = f'preflight/explicit16-{row["case"]}-{row["variant"]}.br'
        wire = payloads[label + "/" + name]
        require(len(wire) == row["wire_bytes"] and sha(wire) == row["wire_sha256"] and row["pinned_decode_verified"], "Initial wire/decode receipt differs")
        require(row["actual_window_bits"] == 16 and row["input_sha256"] == fixtures[row["case"]]["sha256"], "Initial options/input differs")
        peer = payloads[label + f'/preflight/explicit16-{row["case"]}-old_exact.br']
        require(wire == peer, "Screen wire regression")
    expected_pairs = {(case, index) for case in fixtures for index in range(12 if case in WEAK else 6)}
    pairs, calls = set(), 0
    for pair in manifest["pairs"]:
        key = pair["case"], pair["round"]
        require(key not in pairs and pair["lane"] == "explicit16", "Duplicate/unexpected screen pair")
        pairs.add(key)
        require(pair["order"] == (["old_exact", "current"] if pair["round"] % 2 == 0 else ["current", "old_exact"]), "Screen AB/BA order differs")
        require(set(pair["processes"]) == {"old_exact", "current"}, "Screen source pair incomplete")
        for variant, record in pair["processes"].items():
            filename = "runs/" + Path(record["path"]).name
            process = load(filename)
            command = load(filename.removesuffix(".json") + ".command.json")
            frozen = next(row for row in initial["rows"] if row["case"] == pair["case"] and row["variant"] == variant)
            info = process["provenance"]
            require(command["exit_code"] == 0 and command["command"][:3] == ["taskset", "-c", "2"], "Screen command/exit differs")
            require(info["executable_sha256"] == builds[variant]["executable_sha256"] and process["source_revision"] == settings["variants"][variant], "Screen source/ELF differs")
            require(info["cpu_affinity"] == "2" and info["affinity_cpu_count"] == 1 and info["target_cpu"] == "skylake+pku+sgx" and info["target_abi"] == "gnu" and info["optimize"] == "ReleaseFast", "Screen target/lifecycle differs")
            require(process["quality"] == 8 and process["mode"] == "generic" and process["requested_window_bits"] == 16, "Screen options differ")
            require(process["input_sha256"] == frozen["input_sha256"] and process["warm_wire_sha256"] == frozen["wire_sha256"], "Screen initial identity differs")
            require(process["warmup_owned_encode_free_calls"] == process["iterations"] == 1 and len(process["samples"]) == 1, "Screen per-process iteration count differs")
            sample = process["samples"][0]
            require(sample["wire_bytes"] == sample["mix"] == frozen["wire_bytes"] and [sample["owned_encode_free_ns"]] == record["raw_ns"], "Screen raw ns/length mix differs")
            calls += 1
    require(pairs == expected_pairs and calls == 180 and len(pairs) == 90 and "completed" in manifest, "Screen matrix incomplete")
    # The archived reducer performs only JSON/math/CSV work. No ELF or codec.
    with tempfile.TemporaryDirectory(prefix="vort-screen-statistics-") as directory:
        temporary = Path(directory)
        for name in ("run-manifest.json", "preflight-summary.json", "analyze.py"):
            (temporary / name).write_bytes(payloads[label + "/" + name])
        spec = importlib.util.spec_from_file_location("archived_screen_analysis", temporary / "analyze.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with contextlib.redirect_stdout(io.StringIO()):
            module.main()
        actual = json.loads((temporary / "summary.json").read_text())
        require(actual == summary, "Recomputed screen medians/ratios/CI differ")
        require((temporary / "raw-pairs.csv").read_bytes() == payloads[label + "/raw-pairs.csv"], "Recomputed LF screen ledger differs")
    worst = max(summary["rows"], key=lambda row: row["paired_geomean_ns_current_over_old"])
    return {
        "label": label, "full_summary": summary,
        "baseline_original_source_cid": BASELINE_CID,
        "candidate_source_label": builds["current"]["revision"],
        "verified_pairs": 90, "verified_timed_calls": 180, "verified_initial_wires": 24,
        "worst_row": {"case": worst["case"], "candidate_over_baseline_elapsed": worst["paired_geomean_ns_current_over_old"],
                      "baseline_over_candidate_speed": 1 / worst["paired_geomean_ns_current_over_old"]},
        "weak_rows": {row["case"]: {"pairs": row["pairs"], "elapsed_ratio": row["paired_geomean_ns_current_over_old"],
                                     "elapsed_ratio_ci": row["paired_ratio_bootstrap_95pct_ci"]}
                      for row in summary["rows"] if row["case"] in WEAK},
        "scope": "Development-host frozen-source observational screen; initial complete wires only SHA/cross-decode, timed outputs length/mix. Legacy slot names do not denote historical source. Acceptance pending; no quiet result included.",
    }
