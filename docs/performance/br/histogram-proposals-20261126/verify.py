#!/usr/bin/env python3
"""Check frozen codec evidence and gates without running a codec."""
import gzip
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tarfile
import tempfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unpack(archive, bindings, destination):
    archive_sha = bindings.get("archive_sha256") or bindings["archive"]["sha256"]
    expected_members = bindings["members"]
    if isinstance(expected_members, list):
        expected_members = {item["path"]: item for item in expected_members}
        assert len(expected_members) == len(bindings["members"])
    assert sha(archive.read_bytes()) == archive_sha
    with tarfile.open(archive, "r:gz") as stream:
        members = stream.getmembers()
        assert len(members) == len(expected_members)
        assert {member.name for member in members} == set(expected_members)
        for member in members:
            name = PurePosixPath(member.name)
            assert member.isfile() and not name.is_absolute() and ".." not in name.parts
            data = stream.extractfile(member).read()
            expected = expected_members[member.name]
            assert len(data) == expected["bytes"] and sha(data) == expected["sha256"], member.name
            target = destination / member.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            if "uncompressed_sha256" in expected:
                decoded = gzip.decompress(data)
                assert sha(decoded) == expected["uncompressed_sha256"]
                assert len(decoded) == expected["uncompressed_bytes"]
                target.with_suffix("").write_bytes(decoded)
    for name, expected in bindings.get("logical_members", {}).items():
        logical = PurePosixPath(name)
        assert not logical.is_absolute() and ".." not in logical.parts
        data = (destination / expected["object"]).read_bytes()
        assert len(data) == expected["bytes"] and sha(data) == expected["sha256"]
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        if "uncompressed_sha256" in expected:
            decoded = gzip.decompress(data)
            assert len(decoded) == expected["uncompressed_bytes"] and sha(decoded) == expected["uncompressed_sha256"]
            target.with_suffix("").write_bytes(decoded)
    for reference in bindings.get("references", []):
        if reference.get("encoding") != "gzip":
            continue
        data = gzip.decompress((destination / reference["member"]).read_bytes())
        assert len(data) == reference["uncompressed_bytes"] and sha(data) == reference["uncompressed_sha256"]


def check_resources(candidate):
    summary = json.loads((candidate / "summary.json").read_text())
    rows = summary["rows"]
    assert len(rows) == 14 and len({r["case"] for r in rows}) == 14
    ratios = []
    for row in rows:
        case = row["case"]
        report = json.loads((candidate / "runs-v7" / (case + ".json")).read_text())
        baseline = json.loads((candidate / "reused/baseline" / (case + ".json")).read_text())
        command = json.loads((candidate / "runs-v7" / (case + ".command.json")).read_text())
        assert command["exit_code"] == 0 and command["timed"] is False
        assert report["quality"] == 8 and report["mode"] == "generic" and report["window_bits"] == 16
        assert report["force_moving_growth"] is True
        assert report["input_sha256"] == baseline["input_sha256"] == row["input_sha256"]
        wire = (candidate / "runs-v7" / (case + ".br")).read_bytes()
        assert wire == (candidate / "reused/baseline" / (case + ".br")).read_bytes()
        assert sha(wire) == report["oracle_wire_sha256"] == row["wire_sha256"]
        unlimited = report["unlimited"]
        peak = unlimited["tracked_peak"]
        for name in ("unlimited", "exact_peak", "one_below_peak"):
            operation = report[name]
            profile = operation["profile"]
            assert profile["available"] and profile["peak_requested_bytes"] == operation["tracked_peak"]
            assert operation["tracked_owned_peak"] == operation["tracked_peak"]
            assert operation["tracked_allocated"] == operation["tracked_freed_after_caller_free"]
            assert operation["tracked_live_after_caller_free"] == profile["live_requested_bytes"] == 0
            assert profile["limit"] == operation["limit"]
            if name == "one_below_peak":
                assert operation["limit"] == peak - 1
                assert operation["error_name"] == "WorkingMemoryLimitExceeded"
                assert operation["wire_bytes"] is None and operation["wire_sha256"] is None
                assert operation["tracked_live_after_encode"] == 0
                assert operation["tracked_freed_after_encode"] == operation["tracked_allocated"]
                assert operation["tracked_peak"] <= peak - 1
            else:
                assert operation["limit"] == (None if name == "unlimited" else peak)
                assert operation["error_name"] == "" and operation["wire_equal"] is True
                assert operation["wire_bytes"] == len(wire) and operation["wire_sha256"] == sha(wire)
                assert operation["tracked_live_after_encode"] == len(wire)
                assert operation["tracked_freed_after_encode"] + len(wire) == operation["tracked_allocated"]
                assert operation["tracked_peak"] == peak
        old = baseline["unlimited"]
        values = {"requested_peak": peak / old["tracked_peak"],
                  "allocated": unlimited["tracked_allocated"] / old["tracked_allocated"],
                  "acquisition_requests": (unlimited["alloc_requests"] + unlimited["resize_requests"] + unlimited["remap_requests"]) /
                                          (old["alloc_requests"] + old["resize_requests"] + old["remap_requests"])}
        for key, value in values.items():
            assert math.isclose(row["v7_over_baseline_" + key], value, rel_tol=1e-12)
        ratios.append((case, values))
    for group, selected in (("all14", ratios), ("silesia12", [r for r in ratios if r[0] not in ("rle", "opaque")])):
        for key in ("requested_peak", "allocated", "acquisition_requests"):
            gm = math.exp(sum(math.log(value[key]) for _, value in selected) / len(selected))
            assert math.isclose(summary["groups"][group]["v7_over_baseline_" + key], gm, rel_tol=1e-12)
    assert "All 6 tests passed" in (candidate / "build/classification.stderr").read_text()
    return len(rows) * 3


def verify():
    package = Path(__file__).resolve().parent
    inventory = {}
    for line in (package / "SHA256SUMS").read_text().splitlines():
        digest, name = line.split("  ", 1)
        assert name not in inventory and Path(name).name == name
        assert sha((package / name).read_bytes()) == digest, name
        inventory[name] = digest
    assert set(inventory) == {p.name for p in package.iterdir() if p.is_file() and p.name != "SHA256SUMS"}
    with tempfile.TemporaryDirectory(prefix="vort-v7-evidence-") as directory:
        root = Path(directory)
        unpack(package / "raw.tar.gz", json.loads((package / "archive-bindings.json").read_text()), root)
        resources = root / "resources"
        unpack(package / "resources.tar.gz", json.loads((package / "resource-bindings.json").read_text()), resources)
        result = subprocess.run([sys.executable, str(package / "verify_performance.py"),
                                 "--root", str(root), "--expected-summary", str(package / "independent-performance-summary.json")],
                                check=True, capture_output=True, text=True)
        performance = json.loads(result.stdout)
        assert performance["data_valid"] and performance["all_gates_passed"]
        for name in ("resource-original", "resource-final"):
            candidate = resources / name
            complete = json.loads((candidate / "task-complete.json").read_text())
            assert complete and check_resources(candidate) == 42
        source = json.loads((root / "source-git-bindings.json").read_text())
        assert source["code_test_changes"] == 17
        assert len(source["generated_artifacts"]) == 1
        for item in source["records"]:
            data = (root / "source" / item["path"]).read_bytes()
            blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
            assert blob == item["frozen_git_blob"] and sha(data) == item["sha256"]
            if item["classification"] == "matching":
                assert blob == item["base_git_blob"]
        final_br = (root / "validation/full-br-final.stderr").read_text()
        assert "1721/1722 tests passed (1 skipped)" in final_br and "test-br success" in final_br
        assert json.loads((root / "validation/full-br-final.exit.json").read_text())["exit_code"] == 0
        for name in ("deflate-control", "zstd-control", "main-check-wasm", "main-cli-help"):
            assert json.loads((root / "validation" / (name + ".exit.json")).read_text())["exit_code"] == 0
        actual = json.loads((root / "validation/actual-wasm-final.stdout").read_text())
        assert actual["status"] == "ok" and all(item["exit_code"] == 0 for item in actual["results"])
        profile = json.loads((root / "profile-final-summary.json").read_text())
        assert sum(row["context_events"] for row in profile["rows"]) == 103
        assert sum(row["recorded_reuses"] for row in profile["rows"]) == 29
        return {"verified": True, "performance_gates_passed": True,
                "code_test_changes": source["code_test_changes"], "full_br_passed": 1721,
                "full_br_skipped": 1, "primary_pairs": 90, "public_control_pairs": 18,
                "resource_cap_operations_per_variant": 42, "diagnostic_reuses": 29,
                "scope": "Frozen source, raw execution receipts, allocation policy and internal Vort A/B; no codec execution or industry ranking"}


if __name__ == "__main__":
    print(json.dumps(verify(), indent=2, sort_keys=True))
