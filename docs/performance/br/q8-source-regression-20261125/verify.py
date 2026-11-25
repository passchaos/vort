#!/usr/bin/env python3
"""Offline byte/identity audit and paired-statistics replay; no codec or Git."""
import contextlib
import csv
import gzip
import hashlib
import importlib.util
import io
import json
import math
from pathlib import Path
import sys
import tarfile
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
VARIANTS = {
    "old_exact": "0a673757ea6a1e88b90794ad44dce1a8a824f371",
    "current": "c2c8f250302ca2f223740076482dd95b1788eeb1",
}
WEAK = {"dickens", "mozilla", "nci"}
GOLDEN = {
    "dickens": (24723, "2d5a260a0e470c49372ad983dc6ef7ffb5a50658a16a2839e1dddc83381d9342"),
    "nci": (4390, "fc61d8a4ab072fddd1c345f5ceaa2f66c2416b7d39f6e3351d85d52b01f38a87"),
    "mozilla": (14216, "0edaa9cf782d41223ce9cca5f4811d94e2bcfe58185ab88a513d297b210f6209"),
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def equivalent(actual, expected):
    if isinstance(actual, float) and isinstance(expected, (float, int)):
        return math.isclose(actual, expected, rel_tol=1e-12, abs_tol=1e-12)
    if isinstance(actual, dict) and isinstance(expected, dict):
        return actual.keys() == expected.keys() and all(equivalent(actual[k], expected[k]) for k in actual)
    if isinstance(actual, list) and isinstance(expected, list):
        return len(actual) == len(expected) and all(equivalent(a, b) for a, b in zip(actual, expected))
    return actual == expected


def verify_inventory():
    listed = set()
    for line in (ROOT / "SHA256SUMS").read_text().splitlines():
        expected, name = line.split("  ", 1)
        require(name not in listed and not Path(name).is_absolute() and ".." not in Path(name).parts, "Invalid inventory path")
        require(sha((ROOT / name).read_bytes()) == expected, "Inventory hash differs: " + name)
        listed.add(name)
    present = {str(p.relative_to(ROOT)) for p in ROOT.rglob("*") if p.is_file() and p.name != "SHA256SUMS"}
    require(present == listed, "Inventory does not cover exact package contents")


def archive_members(bindings):
    archive_bytes = (ROOT / "raw.tar.gz").read_bytes()
    require(len(archive_bytes) == bindings["raw_archive"]["bytes"] and sha(archive_bytes) == bindings["raw_archive"]["sha256"], "Raw archive hash differs")
    payloads = {}
    with tarfile.open(fileobj=io.BytesIO(archive_bytes), mode="r:gz") as archive:
        for entry in archive:
            require(entry.isfile() and not Path(entry.name).is_absolute() and ".." not in Path(entry.name).parts, "Invalid tar member")
            require(entry.name not in payloads, "Duplicate tar member")
            payloads[entry.name] = archive.extractfile(entry).read()
    require(payloads.keys() == bindings["members"].keys(), "Tar membership differs")
    for name, binding in bindings["members"].items():
        data = payloads[name]
        require(len(data) == binding["bytes"] and sha(data) == binding["sha256"], "Original tar member bytes differ: " + name)
        if binding["transform"] == "gzip mtime=0":
            original = gzip.decompress(data)
            require(len(original) == binding["original_bytes"] and sha(original) == binding["original_sha256"], "Original ELF bytes differ")
        else:
            require(binding["transform"] == "none", "Unknown member transform")
    return payloads


def window(wire):
    first = wire[0]
    if first & 1 == 0:
        return 16
    upper = first >> 1 & 7
    if upper:
        return 17 + upper
    lower = first >> 4 & 7
    require(lower != 1, "Unexpected extended-window header")
    return 17 if lower == 0 else 8 + lower


def replay_statistics(payloads, expected):
    with tempfile.TemporaryDirectory(prefix="vort-q8-statistics-") as directory:
        temporary = Path(directory)
        for name in ("run-manifest.json", "preflight-summary.json"):
            (temporary / name).write_bytes(payloads[name])
        script = temporary / "analyze.py"
        script.write_bytes(payloads["scripts/analyze.py"])
        spec = importlib.util.spec_from_file_location("q8_archived_statistics", script)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with contextlib.redirect_stdout(io.StringIO()):
            module.main()
        actual = json.loads((temporary / "summary.json").read_bytes())
        require(equivalent(actual, expected), "Recomputed paired ratios/CI differ")
        # The original reducer explicitly emits LF for its derivative CSV.
        generated_csv = (temporary / "raw-pairs.csv").read_bytes()
        require(b"\r" not in generated_csv, "Regenerated CSV contains CR")
        actual_rows = list(csv.reader(io.StringIO(generated_csv.decode())))
        published_rows = list(csv.reader(io.StringIO((ROOT / "raw-pairs.csv").read_text())))
        require(actual_rows == published_rows, "Recomputed raw-pair CSV differs")
        return actual


def verify():
    verify_inventory()
    bindings = json.loads((ROOT / "archive-bindings.json").read_bytes())
    payloads = archive_members(bindings)
    load = lambda name: json.loads(payloads[name])
    settings = load("settings.json")
    sources = load("source-identity.json")
    builds = load("build-results.json")
    manifest = load("run-manifest.json")
    initial = load("preflight-summary.json")
    fixtures = {f["case"]: f for f in load("fixtures.json")}
    require(settings["variants"] == VARIANTS, "Source revisions differ")
    require(initial["lanes"] == ["explicit16"] and len(fixtures) == 12, "Primary matrix differs")
    require(sources == json.loads((ROOT / "source-identity.json").read_bytes()), "Published source receipt differs")
    require(sha(payloads["scripts/probe.zig"]) == sources["common_probe_sha256"], "Common probe identity differs")
    require(sha(payloads["scripts/provenance.zig"]) == sources["common_provenance_sha256"], "Common provenance identity differs")
    for name, revision in VARIANTS.items():
        require(sources[name]["revision"] == revision and sources[name]["clean"] and builds[name]["success"], "Recorded original source/build receipt incomplete")
        elf = gzip.decompress(payloads["bin/" + name + ".elf.gz"])
        require(sha(elf) == sources[name]["executable_sha256"] == builds[name]["executable_sha256"], "Final ELF identity differs")
        require(sha(payloads["build/" + name + "-record.o"]) == sources[name]["record_object_sha256"], "Record object identity differs")
    decoder = load("decoder-binding.json")
    require(decoder["version"] == "1.2.0" and decoder["version_number"] == 0x1002000, "Pinned decoder receipt differs")
    for record in decoder["files"]:
        require(sha(payloads["references/" + Path(record["path"]).name]) == record["sha256"], "Pinned decoder/common bytes differ")
    require(len(payloads["references/BROTLI-LICENSE"]) > 0, "Brotli license missing")

    for fixture in fixtures.values():
        data = payloads["fixtures/" + Path(fixture["path"]).name]
        require(len(data) == fixture["bytes"] == 65536 and sha(data) == fixture["sha256"], "Input fixture bytes differ")
    require(len(initial["rows"]) == 24, "Initial-wire matrix incomplete")
    for row in initial["rows"]:
        wire = payloads[f'preflight/{row["lane"]}-{row["case"]}-{row["variant"]}.br']
        require(len(wire) == row["wire_bytes"] and sha(wire) == row["wire_sha256"], "Initial complete wire differs")
        require(window(wire) == row["actual_window_bits"] == 16 and row["pinned_decode_verified"], "Recorded original decode/window check incomplete")
        require(row["input_sha256"] == fixtures[row["case"]]["sha256"], "Initial-wire input binding differs")
        if row["variant"] == "old_exact" and row["case"] in WEAK:
            require((len(wire), sha(wire)) == GOLDEN[row["case"]] and row["historical_golden_match"], "Historical golden differs")

    expected_pairs = {(case, index) for case in fixtures for index in range(12 if case in WEAK else 6)}
    actual_pairs = set()
    timed_calls = 0
    for pair in manifest["pairs"]:
        key = pair["case"], pair["round"]
        require(key not in actual_pairs and pair["lane"] == "explicit16", "Duplicate or unexpected pair")
        actual_pairs.add(key)
        require(pair["order"] == (["old_exact", "current"] if pair["round"] % 2 == 0 else ["current", "old_exact"]), "AB/BA order differs")
        require(pair["processes"].keys() == VARIANTS.keys(), "Source pair incomplete")
        for name, record in pair["processes"].items():
            member = "runs/" + Path(record["path"]).name
            process = load(member)
            command = load(member.removesuffix(".json") + ".command.json")
            frozen = next(r for r in initial["rows"] if r["case"] == pair["case"] and r["variant"] == name)
            info = process["provenance"]
            require(command["exit_code"] == 0 and command["command"][:3] == ["taskset", "-c", "2"], "Recorded process command/exit differs")
            require(process["source_revision"] == VARIANTS[name] and info["executable_sha256"] == sources[name]["executable_sha256"], "Process source/ELF binding differs")
            require(info["cpu_affinity"] == "2" and info["affinity_cpu_count"] == 1 and info["codec_thread_policy"] == "single", "Process CPU/thread policy differs")
            require(info["target_cpu"] == "skylake+pku+sgx" and info["target_abi"] == "gnu" and info["optimize"] == "ReleaseFast" and info["zig_version"] == "0.16.0", "Process target differs")
            require(process["quality"] == 8 and process["mode"] == "generic" and process["requested_window_bits"] == 16, "Process options differ")
            require(process["input_sha256"] == frozen["input_sha256"], "Process input binding differs")
            require(process["warm_wire_sha256"] == frozen["wire_sha256"] and process["warm_wire_bytes"] == frozen["wire_bytes"], "Process initial wire differs")
            require(process["warmup_owned_encode_free_calls"] == process["iterations"] == 1, "Process lifecycle differs")
            require(process["allocator"] == "std.process.Init.gpa", "Process allocator differs")
            require(process["wire_identity_scope"].startswith("initial_wire_only"), "Timed-wire identity scope differs")
            samples = process["samples"]
            require(len(samples) == 1 and samples[0]["index"] == 0, "Timed call count differs")
            require([s["owned_encode_free_ns"] for s in samples] == record["raw_ns"], "Manifest/process raw ns differ")
            require(samples[0]["wire_bytes"] == samples[0]["mix"] == frozen["wire_bytes"] and samples[0]["owned_encode_free_ns"] > 0, "Timed length/mix/duration differs")
            timed_calls += 1
    require(actual_pairs == expected_pairs and len(actual_pairs) == 90 and timed_calls == 180 and "completed" in manifest, "Round/sample coverage incomplete")
    expected_summary = json.loads((ROOT / "summary.json").read_bytes())
    result = replay_statistics(payloads, expected_summary)
    require(result["matrix"][0]["rows"] == 12 and result["matrix"][0]["primary_rounds"] == 6, "Primary matrix weighting differs")
    return {
        "schema": "vort.q8-source-regression.offline-verification.v1",
        "inventory_verified": True, "original_tar_members_verified": len(payloads),
        "original_source_build_receipts_verified": True,
        "source_rebuild_performed": False, "codec_or_elf_executed": False,
        "verified_initial_wire_hashes": 24, "verified_processes": 180,
        "primary_matrix": {"rows": 12, "pairs_per_row": 6, "pairs": 72},
        "weak_rows": {"rows": sorted(WEAK), "pairs_per_row": 12, "additional_pairs": 18},
        "old_weak_golden_matches": {case: True for case in sorted(WEAK)},
        "source_revisions": VARIANTS,
        "recomputed_matrix": result["matrix"],
        "summary_sha256": sha((ROOT / "summary.json").read_bytes()),
        "wire_identity_scope": "initial_wire_only; timed outputs validated by length/mix",
        "scope": "Offline archive bytes, recorded source/build/decoder assertions, identity/order/count/mix and paired-statistics replay. No build, Git, codec or original ELF execution. Fixed-row development-host observational CI; no acceptance/ranking claim.",
    }


if __name__ == "__main__":
    print(json.dumps(verify(), indent=2, sort_keys=True))
