#!/usr/bin/env python3
"""Offline integrity, frozen-wire and full-event audit; never execute the ELF."""
import copy
import gzip
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


def tar_members(data):
    result = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        for entry in archive:
            require(entry.isfile(), "non-file archive member")
            require(entry.name not in result, "duplicate archive member")
            result[entry.name] = archive.extractfile(entry).read()
    return result


def verify():
    inventory = ROOT / "SHA256SUMS"
    require(inventory.is_file(), "package inventory missing")
    listed = set()
    for line in inventory.read_text().splitlines():
        expected, name = line.split("  ", 1)
        require(name not in listed, "duplicate checksum entry")
        require(not Path(name).is_absolute() and ".." not in Path(name).parts, "invalid checksum path")
        require(sha((ROOT / name).read_bytes()) == expected, "package hash differs: " + name)
        listed.add(name)
    present = {str(p.relative_to(ROOT)) for p in ROOT.rglob("*") if p.is_file() and p != inventory}
    require(present == listed, "inventory does not cover exact package contents")

    bindings = json.loads((ROOT / "archive-bindings.json").read_bytes())
    for name, binding in bindings["artifacts"].items():
        data = (ROOT / name).read_bytes()
        require(len(data) == binding["bytes"] and sha(data) == binding["sha256"], "artifact binding differs: " + name)
        members = binding.get("members")
        if not members:
            continue
        payloads = tar_members(data) if binding["kind"] == "tar.gz" else {members[0]["name"]: gzip.decompress(data)}
        require(set(payloads) == {m["name"] for m in members}, "archive membership differs")
        for member in members:
            content = payloads[member["name"]]
            require(len(content) == member["bytes"] and sha(content) == member["sha256"], "original member bytes differ")

    report = json.loads(gzip.decompress((ROOT / "profile.json.gz").read_bytes()))
    executable = gzip.decompress((ROOT / "diagnostic-executable.gz").read_bytes())
    require(sha(executable) == report["provenance"]["executable_sha256"], "recorded executable identity differs")
    fixtures = tar_members((ROOT / "fixtures.tar.gz").read_bytes())
    matrix = tar_members((ROOT / "frozen-matrix.tar.gz").read_bytes())
    frozen_matches = []
    for row in report["rows"]:
        name = Path(row["path"]).name
        data = fixtures[name]
        require(len(data) == row["input_bytes"] and sha(data) == row["input_sha256"], "input fixture differs")
        case = name.split(".")[0]
        frozen = json.loads(matrix[f"brotli-{case}-65536-L8.json"])["rows"][0]
        require(row["wire_bytes"] == frozen["wires"]["vort_bytes"], "frozen wire size differs")
        require(row["wire_sha256"] == frozen["wires"]["vort_sha256"], "frozen wire hash differs")
        settings = frozen["settings"]
        require(settings["planned_quality"] == 8 and settings["vort_mode"] == "generic"
                and settings["vort_window_bits"] == 16 and not settings["vort_large_window"],
                "frozen matrix policy differs")
        frozen_matches.append({"case": case, "wire_bytes": row["wire_bytes"], "wire_sha256": row["wire_sha256"]})

    gate = module("q8_archived_gate", ROOT / "audit/quality_profile_gate.py")
    relocated = copy.deepcopy(report)
    with tempfile.TemporaryDirectory(prefix="vort-q8-offline-") as directory:
        temporary = Path(directory)
        elf = temporary / "diagnostic.elf"
        elf.write_bytes(executable)
        original_paths = {}
        for row in relocated["rows"]:
            original = row["path"]
            target = temporary / Path(original).name
            target.write_bytes(fixtures[target.name])
            original_paths[str(target)] = original
            row["path"] = str(target)
        result = gate.validate(relocated, elf, allow_truncated_context_details=True)
        for row in result["rows"]:
            row["path"] = original_paths[row["path"]]
    require(result == json.loads((ROOT / "gate-summary.json").read_bytes()), "offline gate result differs")
    require(result == json.loads(gzip.decompress((ROOT / "original-gate.json.gz").read_bytes())), "retained original gate differs")

    analysis = module("q8_archived_analysis", ROOT / "summarize.py").derive(report)
    require(analysis == json.loads((ROOT / "summary.json").read_bytes()), "raw-event analysis differs")
    for case in analysis["cases"]:
        require(case["events_deterministic_except_timing"], "event shape changed across rounds")
        for run in case["runs"]:
            counted = next(r for r in result["rows"] if Path(r["path"]).name.split(".")[0] == case["case"] and r["round"] == run["index"])["physical_wires"]
            require(counted["exact_lost_wire_count_available"], "wire count incomplete")
            require(run["physical_wires"] == counted["successful_wire_materializations"], "physical count differs")
            require(run["lost_wires"] == counted["lost_wire_materializations"], "lost count differs")
            require(run["materialized_wire_bytes"] == counted["completed_wire_bytes_total"], "wire byte sum differs")
    return {
        "schema": "vort.q8-explicit16-profile.offline-verification.v1",
        "inventory_verified": True,
        "archived_original_bytes_verified": True,
        "executable_sha256": sha(executable),
        "validated_runs": result["validated_runs"],
        "frozen_wire_matches": frozen_matches,
        "exact_physical_counts": analysis["totals"],
        "context_detail_coverage": {c["case"]: {"retained": c["runs"][0]["context_details_retained"], "proposal_events": c["runs"][0]["context_proposal_events"], "truncated": c["runs"][0]["context_details_truncated"]} for c in analysis["cases"]},
        "scope": "Offline hashes, frozen-wire comparisons, event/timing topology and physical counts. Recorded producer asserts normal/traced byte equality and roundtrip; no codec/build/ELF or timing campaign executed by this verifier.",
    }


if __name__ == "__main__":
    print(json.dumps(verify(), indent=2, sort_keys=True))
