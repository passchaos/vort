#!/usr/bin/env python3
"""Check archived bytes and observed gate receipts without rerunning codec tests."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(value, message):
    if not value:
        raise ValueError(message)


def verify(root, live_root=None):
    binding = json.loads((root / "bindings.json").read_text())
    archives = {}
    for name, expected in binding["archives"].items():
        require(sha((root / name).read_bytes()) == expected["sha256"], "Archive differs")
        members = {}
        with tarfile.open(root / name, "r:gz") as archive:
            for entry in archive.getmembers():
                require(entry.isfile() and entry.name not in members, "Invalid member")
                members[entry.name] = archive.extractfile(entry).read()
        require(set(members) == set(expected["members"]), "Inventory differs")
        for path, data in members.items():
            require(expected["members"][path] == {"bytes": len(data), "sha256": sha(data)}, "Member differs: " + path)
        archives[name] = members
    source, evidence = archives["source-overlay.tar.gz"], archives["evidence.tar.gz"]
    require(len(source) == 6 and {path: sha(data) for path, data in source.items()} == binding["source_sha256"], "Source differs")
    require(evidence["before.log"].count(b"aliased count=6 output=abcabc") == 2, "Before corruption proof missing")
    require(evidence["after.log"].count(b"InvalidBlockPlan, backing unchanged") == 2, "After refusal proof missing")
    require(evidence["after.log"].count(b"independent=abcdef") == 2, "Independent retry differs")
    for name in ("all-safe.log", "debug-final.log", "x86-final.log"):
        require(b"All 10 tests passed." in evidence[name], "Focused gate missing: " + name)
    require(b"All 700 tests passed." in evidence["full-final.log"], "Full gate missing")
    require(b"94/94 tests passed" in evidence["root.log"], "Public root gate missing")
    wasi = json.loads(evidence["wasm-receipt.json"])
    artifact = wasi["artifacts"][0]
    require(wasi["ok"] and artifact["execution_started"] and artifact["actual_exit_code"] == 0, "Actual WASI execution missing")
    require(artifact["wasm_sha256"] == sha(evidence["final.wasm"]), "WASI binary differs")
    require(set(binding["test_contract_corrections"]) == {"contracts-safe-first.log", "contracts-safe-contract-refinement.log"}, "Correction provenance missing")
    count = 0
    if live_root:
        for path, digest in binding["source_sha256"].items():
            require(sha((live_root / path).read_bytes()) == digest, "Live source differs: " + path)
            count += 1
    return {"valid": True, "scope": "archived byte and gate verification; no performance claim", "source_files": 6, "live_source_files_verified": count, "evidence_members": len(evidence), "before_wrong_successes": 2, "after_unchanged_refusals": 2, "full_tests": 700, "focused_tests": 10, "root_tests": 94, "actual_wasi_exit_code": 0, "test_contract_corrections_separate": True}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live-root", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(Path(__file__).resolve().parent, args.live_root), indent=2))
