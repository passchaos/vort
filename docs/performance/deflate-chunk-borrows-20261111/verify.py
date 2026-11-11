#!/usr/bin/env python3
"""Independently verify preserved bytes and functional contracts, without rerunning Vort."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import tarfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(root, live_root=None):
    binding = json.loads((root / "bindings.json").read_text())
    archives = {}
    member_count = 0
    for name, expected in binding["archives"].items():
        require(sha((root / name).read_bytes()) == expected["sha256"], "Archive changed: " + name)
        members = {}
        with tarfile.open(root / name, "r:gz") as archive:
            for member in archive.getmembers():
                require(member.isfile() and member.name not in members, "Unexpected tar member")
                data = archive.extractfile(member).read()
                members[member.name] = data
        require(set(members) == set(expected["members"]), "Member inventory differs")
        for path, data in members.items():
            require(expected["members"][path] == {"bytes": len(data), "sha256": sha(data)}, "Member changed: " + path)
        archives[name] = members
        member_count += len(members)
    campaign, gates, source = (archives[name] for name in ("campaign.tar.gz", "gates.tar.gz", "source-overlay.tar.gz"))
    packet = json.loads(campaign["packet.json"])
    require(sha(campaign["packet.json"]) == "6bad3b9cfdb8476363d89b015955ae5026cfdf439457282e3324dcc9c517ee49", "Original packet changed")
    for name, expected in packet["artifacts"].items():
        require(expected == {"bytes": len(campaign[name]), "sha256": sha(campaign[name])}, "Original packet member differs")
    summary = json.loads(campaign["final-summary.json"])
    build = json.loads(campaign["build.json"])
    committed = json.loads(campaign["source-commit-binding.json"])
    registry = committed["compiled_source_sha256"]
    require(len(registry) == 1858 and registry == committed["git_blob_source_sha256"], "Committed source registry differs")
    require(registry == build["source_before"] == build["source_after"] == summary["source_before"] == summary["source_after"], "Source drift")
    digest = sha(json.dumps(registry, sort_keys=True, separators=(",", ":")).encode())
    require(digest == committed["source_digest"] == packet["source_digest"], "Source digest differs")
    require(committed["commit"] == binding["fix_commit"] == packet["commit"], "Fix identity differs")
    require(len(source) == 12 and all(sha(data) == registry[path] for path, data in source.items()), "Source overlay differs")
    probe_hash = sha(campaign["probe"])
    require(probe_hash == summary["probe_sha256"] == build["probe_sha256"] == packet["final"]["probe_sha256"], "Probe differs")
    require(build["exit_code"] == 0 and build["normal_executable"] and build["source_stable_during_build"], "Build incomplete")
    require(sha(campaign["probe.zig"]) == build["probe_source_sha256"] and sha(campaign["campaign.py"]) == build["runner_sha256"], "Tool source differs")
    fixtures = json.loads(campaign["fixtures.json"])
    require(sha(campaign["fixtures.json"]) == summary["fixtures_manifest_sha256"], "Fixtures differ")
    indexed = {item["key"]: item for item in fixtures["fixtures"]}
    require(len(indexed) == len(fixtures["fixtures"]) == 216, "Duplicate/missing fixtures")
    names = {item["name"] for item in indexed.values()}
    require(len(names) == 12, "Wrong corpus size")
    expected_keys = {f"{codec}/{name}/{size}/{level}" for codec in ("raw", "zlib", "gzip") for name in names for size in ("65536", "1048576", "full") for level in (6, 9)}
    require(set(indexed) == expected_keys, "Fixture dimensions differ")
    require(all(item["independent_inflate_verified"] for item in indexed.values()), "Missing independent fixture validation")
    common = {"single", "single_among_empty", "spans4093_empty", "packed_identity", "first_forward", "first_backward"}
    expected_rows = {(key, schedule) for key, item in indexed.items() for schedule in common | ({"spans1_empty"} if item["input_bytes"] <= 65536 else set())}
    rows_bytes = campaign["final-rows.jsonl"]
    require(sha(rows_bytes) == summary["rows_sha256"] == committed["final_rows_sha256"], "Raw rows differ")
    rows = [json.loads(line) for line in rows_bytes.splitlines()]
    actual = {(row["fixture_key"], row["schedule"]) for row in rows}
    require(len(rows) == len(actual) == 1368 and actual == expected_rows, "Incomplete/duplicate schedule matrix")
    require(summary["completed_rows"] == summary["expected_rows"] == 1368 and summary["failure"] is None and summary["all_fixture_files_unchanged"], "Campaign incomplete")
    for row in rows:
        item = indexed[row["fixture_key"]]
        require(row["schema"] == "vort.deflate-chunk-compat-row.v1" and row["probe_sha256"] == probe_hash and row["decode_calls"] == 1, "Row identity differs")
        for field in ("success", "full_output_verified", "original_bytes_unchanged", "original_guards_verified", "output_guards_verified", "scratch_guards_verified"):
            require(row[field] is True, "Functional check failed: " + field)
        require(row["input_sha256"] == row["output_sha256"] == item["input_sha256"] and row["wire_sha256"] == item["wire_sha256"], "Content hash differs")
        require(row["output_written"] == row["input_bytes"] == item["input_bytes"] and row["wire_bytes"] == item["wire_bytes"], "Byte count differs")
        require(row["input_read"] == (item["wire_bytes"] if row["codec"] == "raw" else None), "Consumption differs")
        require(row["optimize"] == "ReleaseFast" and row["target_cpu"] == "skylake+pku+sgx" and row["target_arch"] == "x86_64", "Target differs")
        require(row["command"][:3] == ["taskset", "-c", "15"], "CPU policy differs")
        single = row["schedule"] in ("single", "single_among_empty")
        require(row["scratch_bytes"] == (0 if single else item["wire_bytes"]) and row["joined_wire_verified"] is (not single), "Join coverage differs")
        if row["schedule"] in ("first_forward", "first_backward"):
            require(row["scratch_padding_verified"] and row["scratch_offset"] == 2 and row["first_source_offset"] == (4 if row["schedule"] == "first_forward" else 0), "Move coverage differs")
    require(b"All 698 tests passed." in gates["deflate-full.log"], "Full gate missing")
    for name in ("contracts-all-safe.log", "contracts-debug.log", "contracts-x86.log"):
        require(b"All 11 tests passed." in gates[name], "Focused gate missing: " + name)
    require(b"94/94 tests passed" in gates["root.log"], "Public-root gate missing")
    wasm = json.loads(gates["wasm-receipt.json"])
    artifact = wasm["artifacts"][0]
    require(wasm["ok"] and artifact["execution_started"] and artifact["actual_exit_code"] == 0 and artifact["wasm_sha256"] == sha(gates["contracts.wasm"]), "Actual WASI gate differs")
    require(b"output_hex=010400fb" in gates["before/unread-chunk-safe.log"] and b"after=8b4844130000" in gates["before/dictionary-safe.log"], "Before corruption proof missing")
    verified = 0
    if live_root:
        for path, expected in registry.items():
            require(sha((live_root / path).read_bytes()) == expected, "Live source changed: " + path)
            verified += 1
    return {"valid": True, "claim": "functional compatibility only; no performance claim", "archive_members": member_count, "source_files": len(registry), "live_source_files_verified": verified, "source_overlay_files": len(source), "fixtures": len(indexed), "rows": len(rows), "rows_by_codec": dict(Counter(row["codec"] for row in rows)), "rows_by_schedule": dict(Counter(row["schedule"] for row in rows)), "full_tests": 698, "root_tests": 94, "focused_tests": 11, "actual_wasi_exit_code": 0, "pilot_is_nonfinal": packet["pilot"]["nonfinal"]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live-root", type=Path)
    arguments = parser.parse_args()
    print(json.dumps(verify(Path(__file__).resolve().parent, arguments.live_root), indent=2))
