#!/usr/bin/env python3
"""Replay V9 archived identities and pilot arithmetic, never codecs or argv."""
import gzip
import hashlib
import json
import math
from pathlib import Path
import re
import statistics
import tarfile


ROOT = Path(__file__).resolve().parent


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    binding = json.loads((ROOT / "archive-bindings.json").read_text())
    raw_path = ROOT / "raw.tar.gz"
    require(raw_path.stat().st_size == binding["archive"]["bytes"], "archive length changed")
    require(digest(raw_path.read_bytes()) == binding["archive"]["sha256"], "archive SHA changed")
    blobs = {}
    with tarfile.open(raw_path) as archive:
        for member in archive.getmembers():
            require(member.isfile() and member.name not in blobs, "unexpected tar member")
            data = archive.extractfile(member).read()
            require(binding["members"].get(member.name) == {"bytes": len(data), "sha256": digest(data)}, "member changed")
            blobs[member.name] = data
    require(set(blobs) == set(binding["members"]), "full membership differs")
    require(len(blobs) == binding["archive"]["member_count"], "member count differs")
    logical = {}
    for name, item in binding["files"].items():
        stored = blobs[item["member"]]
        require(len(stored) == item["stored_bytes"] and digest(stored) == item["stored_sha256"], "stored blob mismatch")
        require(item["encoding"] in ("raw", "gzip"), "unknown encoding")
        data = gzip.decompress(stored) if item["encoding"] == "gzip" else stored
        require(len(data) == item["bytes"] and digest(data) == item["sha256"], "logical file mismatch")
        if item["encoding"] == "gzip":
            require(data.startswith(b"\x7fELF"), "compressed artifact is not an ELF")
        logical[name] = data

    def data(name):
        require(name in logical, "missing logical artifact: " + name)
        return logical[name]

    def read(name):
        return json.loads(data(name))

    snapshots = binding["source_snapshots"]
    for name, snapshot in snapshots.items():
        manifest = read(snapshot["manifest"])
        require(digest(data(snapshot["manifest"])) == snapshot.get("manifest_sha256", digest(data(snapshot["manifest"]))), "source manifest hash differs")
        omitted = snapshot.get("excluded_generated_entries", {})
        for path, expected in manifest.items():
            if path in omitted:
                require(omitted[path] == expected and "__pycache__" in path, "unexplained source omission")
            else:
                require(digest(data(snapshot["source_prefix"] + path)) == expected, "source SHA differs")
        if name == "v9":
            require(len(manifest) == snapshot["entries"] == 2200, "V9 source count differs")
            require(not any("__pycache__" in path or path.endswith(".pyc") for path in manifest), "V9 generated source included")
    require(data("v9/probe.zig") == data("baseline-v7/probe.zig"), "common probe differs")
    require(data("v9/provenance.zig") == data("baseline-v7/provenance.zig"), "common provenance differs")
    builds = read("v9/build-results.json")
    settings = read("v9/settings.json")
    require(builds["old_exact"]["executable_sha256"] == "437dc07dbc242dbdfc8d4d1399ef83e0790a6471a1ea5724fcc4aecc859a49ec", "baseline is not exact accepted V7")
    for variant in ("old_exact", "current"):
        build = builds[variant]
        require(build["success"] and len(build["stages"]) == 2 and all(stage["exit_code"] == 0 for stage in build["stages"]), "build not complete")
        require(build["revision"] == settings["variants"][variant], "build stamp rewritten")
        require(digest(data("v9/bin/" + variant)) == build["executable_sha256"], "ELF hash differs")
    require(builds["current"]["source_manifest_sha256"] == digest(data("v9/all-src-sha256.json")), "candidate build source differs")
    require(builds["old_exact"]["source_manifest_sha256"] == digest(data("baseline-v7/all-src-sha256.json")), "baseline build source differs")
    fixtures = read("v9/fixtures.json")
    require(len(fixtures) == 12 and len({f["case"] for f in fixtures}) == 12, "corpus count differs")
    cases = [fixture["case"] for fixture in fixtures]
    preflight = read("v9/preflight-summary.json")
    require(len(preflight["rows"]) == 24 and preflight["lanes"] == ["explicit16"], "initial-wire scope differs")
    initial = {}
    for fixture in fixtures:
        plain = data("v9/fixtures/" + Path(fixture["path"]).name)
        require(len(plain) == fixture["bytes"] == 65536 and digest(plain) == fixture["sha256"], "input normalized or changed")
        wires = []
        for variant in ("old_exact", "current"):
            stem = "v9/preflight/explicit16-" + fixture["case"] + "-" + variant
            report = read(stem + ".json")
            require(report["source_revision"] == settings["variants"][variant], "preflight variant stamp differs")
            require(read(stem + ".command.json")["exit_code"] == 0, "preflight process failed")
            require(data(stem + ".stderr") == b"", "preflight stderr")
            wire = data(stem + ".br")
            validate_process(report, fixture, settings, builds, 0)
            require(report["warm_wire_sha256"] == digest(wire) and report["warm_wire_bytes"] == len(wire), "initial wire differs")
            entry = next(row for row in preflight["rows"] if row["case"] == fixture["case"] and row["variant"] == variant)
            require(entry["pinned_decode_verified"] is True and entry["actual_window_bits"] == 16, "original decode/window check failed")
            require(entry["wire_bytes"] == len(wire) and entry["wire_sha256"] == digest(wire), "initial summary differs")
            initial[(fixture["case"], variant)] = (len(wire), digest(wire))
            wires.append(wire)
        require(wires[0] == wires[1], "complete baseline/candidate initial bytes differ")
    decoder = read("v9/decoder-binding.json")
    require(decoder["version"] == "1.2.0" and decoder["version_number"] == 0x1002000, "wrong pinned decoder")
    for file in decoder["files"]:
        actual = data("v9/references/" + Path(file["path"]).name)
        require(len(actual) == file["bytes"] and digest(actual) == file["sha256"], "reference file differs")
    manifest = read("v9/pilot-manifest.json")
    require(read("v9/pilot.command.json")["exit_code"] == 0, "pilot driver exit differs")
    require(read("v9/preflight.command.json")["exit_code"] == 0, "preflight driver exit differs")
    require(manifest["rounds"] == 2 and len(manifest["pairs"]) == 24 and "ended_unix" in manifest, "pilot incomplete")
    timed_calls = 0
    ratios = {case: [] for case in cases}
    for index, pair in enumerate(manifest["pairs"]):
        round_index = index // 12
        require(pair["round"] == round_index and pair["case"] == cases[index % 12], "round/corpus order differs")
        order = ["old_exact", "current"] if round_index == 0 else ["current", "old_exact"]
        require(pair["order"] == order and list(pair["processes"]) == order, "AB/BA order differs")
        fixture = fixtures[index % 12]
        for variant in order:
            saved = pair["processes"][variant]
            stem = "v9/pilot-runs/" + Path(saved["path"]).stem
            report = read(stem + ".json")
            require(report["source_revision"] == settings["variants"][variant], "pilot variant stamp differs")
            command = read(stem + ".command.json")
            require(command["exit_code"] == 0 and command["command"][0:3] == ["taskset", "-c", "2"], "pilot exit/affinity differs")
            require(data(stem + ".stderr") == b"", "pilot stderr")
            validate_process(report, fixture, settings, builds, 1)
            sample = report["samples"][0]
            require(sample["owned_encode_free_ns"] == saved["ns"] > 0, "raw timing differs")
            require((report["warm_wire_bytes"], report["warm_wire_sha256"]) == initial[(fixture["case"], variant)], "warm/initial wire differs")
            require(sample["wire_bytes"] == sample["mix"] == report["warm_wire_bytes"], "timed length mix differs")
            timed_calls += 1
        ratios[pair["case"]].append(math.log(pair["processes"]["current"]["ns"] / pair["processes"]["old_exact"]["ns"]))
    rows = []
    for case in cases:
        require(len(ratios[case]) == 2, "pilot row dropped")
        elapsed_ratio = math.exp(statistics.mean(ratios[case]))
        rows.append({"case": case, "elapsed_candidate_over_baseline": elapsed_ratio, "throughput_candidate_over_baseline": 1 / elapsed_ratio})
    rederived = {"scope": manifest["scope"], "pairs": 24, "rows": rows, "geomean_throughput": math.exp(statistics.mean(math.log(row["throughput_candidate_over_baseline"]) for row in rows))}
    require(rederived == read("v9/pilot-summary.json"), "all pilot means/GM do not reproduce")
    require(timed_calls == 48, "timed call count differs")
    require(read("v9/validation/frontier-fixtures-native.command.json")["exit_code"] == 0 and read("v9/validation/frontier-fixtures-native.exit.json")["exit_code"] == 0, "frontier fixture gate failed")
    require(b"All 2 tests passed." in data("v9/validation/frontier-fixtures-native.stderr"), "frontier2 gate incomplete")
    require(read("v9/validation/parser-native.command.json")["exit_code"] == 0 and b"All 12 tests passed." in data("v9/validation/parser-native.stderr"), "earlier scalar12 gate failed")
    require(read("v9/validation/parser-final-native.command.json")["exit_code"] == 0 and b"All 14 tests passed." in data("v9/validation/parser-final-native.stderr"), "final actual scalar14 gate failed")
    receipt = {"verified": True, "pilot_pairs": 24, "timed_calls": 48, "complete_initial_wires": 24, "all_initial_bytes_equal": True,
               "frontier_fixture_gate_recorded_passes": 2, "actual_scalar_gate_recorded_passes": 14, "source_files": 2200,
               "logical_files": len(logical), "blob_members": len(blobs), "geomean_throughput": rederived["geomean_throughput"],
               "rows": rows, "accepted": False, "confidence_interval_claim": False, "codec_or_argv_execution": False}
    print(json.dumps(receipt, indent=2, sort_keys=True))


def validate_process(report, fixture, settings, builds, iterations):
    variant = next(name for name, stamp in settings["variants"].items() if stamp == report["source_revision"])
    require(report["schema"] == "vort.q8-source-history-ab.process.v1", "wrong report schema")
    require(report["input_bytes"] == fixture["bytes"] == 65536 and report["input_sha256"] == fixture["sha256"], "report input differs")
    require(report["quality"] == 8 and report["mode"] == "generic" and report["requested_window_bits"] == 16, "wrong preset/window")
    require(report["warmup_owned_encode_free_calls"] == 1 and report["iterations"] == iterations and len(report["samples"]) == iterations, "lifecycle/count differs")
    p = report["provenance"]
    require(p["executable_sha256"] == builds[variant]["executable_sha256"], "wrong actual ELF")
    require(p["optimize"] == "ReleaseFast" and p["zig_version"] == "0.16.0" and p["target_cpu"] == "skylake+pku+sgx", "wrong compiler/CPU")
    require((p["target_arch"], p["target_os"], p["target_abi"]) == ("x86_64", "linux", "gnu"), "wrong target")
    require(p["cpu_affinity"] == "2" and p["benchmark_threads"] == 1, "wrong execution policy")
    for index, sample in enumerate(report["samples"]):
        require(sample["index"] == index and type(sample["owned_encode_free_ns"]) is int and sample["owned_encode_free_ns"] > 0, "invalid sample")


if __name__ == "__main__":
    main()
