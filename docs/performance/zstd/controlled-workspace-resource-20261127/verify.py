#!/usr/bin/env python3
"""Verify only archived data; never execute a codec, compiler or test artifact."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def file_sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load(path):
    return json.loads(path.read_bytes())


def check_archive(root, spec, retain):
    path = root / spec["path"]
    require(path.stat().st_size == spec["bytes"], f"Archive size: {path}")
    require(file_sha(path) == spec["sha256"], f"Archive SHA256: {path}")
    actual, payload = {}, {}
    with tarfile.open(path, "r:xz") as archive:
        for member in archive:
            name = member.name
            safe = PurePosixPath(name)
            require(not safe.is_absolute() and ".." not in safe.parts,
                    f"Unsafe member: {name}")
            require(member.isfile() and name not in actual,
                    f"Non-file or duplicate member: {name}")
            stream = archive.extractfile(member)
            require(stream is not None, f"Unreadable member: {name}")
            digest, size, chunks = hashlib.sha256(), 0, []
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
                size += len(block)
                if name in retain:
                    chunks.append(block)
            actual[name] = {"bytes": size, "sha256": digest.hexdigest()}
            if name in retain:
                payload[name] = b"".join(chunks)
    require(actual == spec["members"], f"Archive member inventory: {path}")
    return actual, payload


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path,
                        default=Path(__file__).resolve().parent)
    root = parser.parse_args().root.resolve()
    inventory = load(root / "inventory.json")
    require(inventory["schema"] == "vort-workspace-resource-inventory-v1",
            "Inventory schema")
    for name, entry in inventory["files"].items():
        path = root / name
        require(path.stat().st_size == entry["bytes"] and
                file_sha(path) == entry["sha256"], f"Top-level file: {name}")
    protocol = load(root / "protocol.json")
    five = protocol["candidate_five_paths"]
    require(len(five) == 5, "Five-file candidate protocol")
    evidence_names = {
        "baseline-source-before.json", "baseline-source-after.json",
        "candidate-source-before.json", "candidate-source-after.json",
        "summary.json", "screen.json", "screen.command.json", "fixtures.json",
        "source-verification.json", "artifact-hashes.json",
        "public_l3_probe.zig", "requested_allocator.zig",
        "runs/nci-64k-baseline.json", "runs/nci-64k-candidate.json",
        "runs/nci-64k-baseline.command.json",
        "runs/nci-64k-candidate.command.json",
        "runs/nci-64k-baseline.wire", "runs/nci-64k-candidate.wire",
        "build/baseline.command.json", "build/candidate.command.json",
    }
    gate_names = {
        "artifact-manifest.json", "source-files.json", "source-final-files.json",
        "native.exit.json", "native.stderr", "native-final.exit.json",
        "native-final.stderr", "wasi-build.exit.json", "wasi-run.exit.json",
        "wasi-run.stdout", "wasi-run.stderr",
    }
    maps, data = {}, {}
    for label, spec in inventory["archives"].items():
        retain = set(five) if label in ("baseline-source", "candidate-source") else (
            evidence_names if label == "resource-evidence" else gate_names)
        maps[label], data[label] = check_archive(root, spec, retain)
    baseline, candidate = maps["baseline-source"], maps["candidate-source"]
    evidence, gate = data["resource-evidence"], data["copernicus-gate"]
    require(len(baseline) == 2217 and len(candidate) == 2219,
            "Complete source file counts")
    for label, source_map in (("baseline", baseline), ("candidate", candidate)):
        before = json.loads(evidence[label + "-source-before.json"])
        after = json.loads(evidence[label + "-source-after.json"])
        require(before == after == {n: v["sha256"] for n, v in source_map.items()},
                f"Frozen {label} source identities")
    differences = sorted(name for name in baseline.keys() | candidate.keys()
                         if baseline.get(name) != candidate.get(name))
    require(differences == sorted(five), "Exact five-file source differences")
    patch = []
    for name in five:
        old = data["baseline-source"].get(name, b"").decode().splitlines(keepends=True)
        new = data["candidate-source"][name].decode().splitlines(keepends=True)
        patch.append("diff --git a/" + name + " b/" + name + "\n")
        patch.extend(difflib.unified_diff(
            old, new, fromfile="a/" + name if name in baseline else "/dev/null",
            tofile="b/" + name))
    require("".join(patch).encode() == (root / "prototype-five-files.patch").read_bytes(),
            "Frozen source patch identity")
    for name, expected in json.loads(evidence["artifact-hashes.json"]).items():
        require(maps["resource-evidence"][name]["sha256"] == expected,
                f"Original resource artifact hash: {name}")
    for name in ("summary.json", "screen.json", "source-verification.json"):
        require(evidence[name] == (root / name).read_bytes(),
                f"Exact original top-level copy: {name}")
    summary = json.loads(evidence["summary.json"])
    screen = json.loads(evidence["screen.json"])
    require(summary["status"] == screen["status"] == "rejected" and
            len(summary["rows"]) == len(screen["rows"]) == 1 and
            summary["completed_processes"] == 2,
            "Single-row rejection and observed process count")
    require(summary["unrun_cases"] == protocol["observed"]["unrun_cases"] and
            len(summary["unrun_cases"]) == 5,
            "First-failure stop preserved remaining five inputs")
    require(protocol["rule"]["max_peak_ratio"] == 1.05 and
            protocol["rule"]["stop_immediately_on_first_failed_row"] and
            protocol["timing_allowed"] is False,
            "Original fixed screen protocol")
    require(json.loads(evidence["screen.command.json"])["exit_code"] == 0,
            "Observed screen driver exit")
    reports = {}
    for variant in ("baseline", "candidate"):
        report = reports[variant] = json.loads(evidence[f"runs/nci-64k-{variant}.json"])
        command = json.loads(evidence[f"runs/nci-64k-{variant}.command.json"])
        build = json.loads(evidence[f"build/{variant}.command.json"])
        require(command["exit_code"] == build["exit_code"] == 0,
                f"Actual {variant} build and codec exit")
        require(command["argv"][-4:-1] == ["unlimited", "plain", "none"],
                f"Exact {variant} plain unlimited command")
        require(report["api"] == "encodeFrameWithLevelAlloc" and
                report["level"] == 3 and report["mode"] == "plain" and
                report["cap"] is None and not report["memory_profile"]["available"] and
                report["error_name"] is None and report["strategy_override"] == "auto" and
                not report["control_profile_enabled"] and
                report["resolved_strategy"] == "greedy" and
                report["resolved_match_search_budget"] == 24 and
                not report["resolved_rep_beam_search"], f"Default public {variant} policy")
        heap = report["requested_heap"]
        require(heap["live_after_caller_free"] == heap["active_allocations_after_caller_free"] ==
                heap["ownership_errors"] == heap["physical_backing_oom"] ==
                heap["injected_backing_oom"] == 0 and
                heap["allocated_bytes"] == heap["freed_bytes"], f"{variant} cleanup")
        require(sha(evidence[f"runs/nci-64k-{variant}.wire"]) == report["wire_sha256"],
                f"Full {variant} wire identity")
        elf = maps["resource-evidence"][f"bin/{variant}"]
        require(elf["sha256"] == summary["executables"][variant]["sha256"],
                f"{variant} executable identity")
    require(evidence["runs/nci-64k-baseline.wire"] ==
            evidence["runs/nci-64k-candidate.wire"], "Exact full wire equality")
    b, c = (reports[x]["requested_heap"] for x in ("baseline", "candidate"))
    require(b["peak_bytes"] == 1468774 and c["peak_bytes"] == 1912513 and
            c["peak_bytes"] * 100 > b["peak_bytes"] * 105 and
            c["peak_bytes"] - b["peak_bytes"] == 443739, "30.2115 percent peak refusal")
    require(b["allocated_bytes"] == c["allocated_bytes"] == 1964957 and
            b["alloc_attempts"] == c["alloc_attempts"] == 45, "Actual allocation metrics")
    fixtures = json.loads(evidence["fixtures.json"])
    require(fixtures == protocol["planned_order"] and len(fixtures) == 6,
            "Original six-item protocol and order")
    for item in fixtures:
        key = "fixtures/" + Path(item["path"]).name
        require(maps["resource-evidence"][key]["sha256"] == item["sha256"],
                f"Retained input: {item['case']}")
        if item["dictionary_path"]:
            key = "fixtures/" + Path(item["dictionary_path"]).name
            require(maps["resource-evidence"][key]["sha256"] == item["dictionary_sha256"],
                    "Original raw dictionary identity")
    for entry in json.loads(gate["artifact-manifest.json"]):
        require(maps["copernicus-gate"][entry["path"]] ==
                {k: entry[k] for k in ("bytes", "sha256")}, "Original gate artifact manifest")
    for name, source_dir in (("source-files.json", "SOURCE"),
                             ("source-final-files.json", "SOURCE-final")):
        for entry in json.loads(gate[name]):
            actual = maps["copernicus-gate"][source_dir + "/" + entry["path"]]
            require(actual == {k: entry[k] for k in ("bytes", "sha256")}, "Gate source identities")
            if source_dir == "SOURCE-final":
                require(candidate["src/zstd/match/" + entry["path"]] == actual,
                        "Final narrow gate sources match resource candidate")
    require(json.loads(gate["native.exit.json"])["exit_code"] == 1 and
            b"6 passed; 0 skipped; 1 failed." in gate["native.stderr"],
            "Preserved original native 6of7 failure")
    require(json.loads(gate["native-final.exit.json"])["exit_code"] == 0 and
            b"All 7 tests passed." in gate["native-final.stderr"],
            "Preserved final native 7of7 success")
    wasi = json.loads(gate["wasi-run.stdout"])
    require(json.loads(gate["wasi-build.exit.json"])["exit_code"] ==
            json.loads(gate["wasi-run.exit.json"])["exit_code"] == 0 and
            b"All 7 tests passed." in gate["wasi-run.stderr"] and
            wasi["status"] == "ok" and wasi["pointer_bits"] == 32 and
            wasi["results"][0]["exit_code"] == 0 and
            wasi["results"][0]["wasm_sha256"] == maps["copernicus-gate"]["workspace-tests.wasm"]["sha256"],
            "Preserved actual WASI 7of7 success")
    overlap = load(root / "retained-overlap-evidence.json")
    require(overlap["retained_block_head_extra_overlap_bytes"] == 131072 and
            overlap["first_nci64k_workspace_requested_bytes"] == 524288,
            "Source-derived retained overlap")
    sealed = root / "sealed.json"
    if sealed.exists():
        seal = load(sealed)
        require(seal["status"] == "sealed" and
                seal["inventory_sha256"] == file_sha(root / "inventory.json"), "Seal inventory")
        for name, expected in seal["receipt_sha256"].items():
            require(file_sha(root / name) == expected, "Independent copy receipt identity")
        require(load(root / "verification-copy.exit.json")["exit_code"] == 0,
                "Independent copy actual verification exit")
    print(json.dumps({"status": "ok", "sealed": sealed.exists(),
                      "verification": "data only; no codec/test/build/timing execution",
                      "archives": len(maps), "source_files": [len(baseline), len(candidate)],
                      "archive_members": sum(len(m) for m in maps.values()),
                      "codec_processes_preserved": 2, "resource_rows_preserved": 1,
                      "resource_verdict": "rejected", "unrun_cases": 5,
                      "gate_original_native": "6/7 exit1", "gate_final_native": "7/7 exit0",
                      "gate_actual_wasi": "7/7 exit0"}, sort_keys=True))


if __name__ == "__main__":
    main()
