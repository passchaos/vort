#!/usr/bin/env python3
"""Portable control/statistics and negative-diagnostic audit; no codec/Git."""
import contextlib
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


def members(name):
    result = {}
    with tarfile.open(ROOT / name, "r:gz") as archive:
        for entry in archive:
            require(entry.isfile() and not Path(entry.name).is_absolute() and ".." not in Path(entry.name).parts, "Invalid archive member")
            require(entry.name not in result, "Duplicate archive member")
            result[entry.name] = archive.extractfile(entry).read()
    return result


def check_inventory():
    listed = set()
    for line in (ROOT / "SHA256SUMS").read_text().splitlines():
        expected, name = line.split("  ", 1)
        require(name not in listed and not Path(name).is_absolute() and ".." not in Path(name).parts, "Invalid checksum path")
        require(sha((ROOT / name).read_bytes()) == expected, "Published hash differs: " + name)
        listed.add(name)
    present = {str(path.relative_to(ROOT)) for path in ROOT.rglob("*") if path.is_file() and path.name != "SHA256SUMS"}
    require(present == listed, "Published inventory incomplete")


def check_archives(bindings, control, diagnostic):
    for name, expected in bindings["archives"].items():
        data = (ROOT / name).read_bytes()
        require(len(data) == expected["bytes"] and sha(data) == expected["sha256"], "Archive hash differs")
    ctl_bindings = json.loads(control["artifact-bindings.json"])
    require(control.keys() == ctl_bindings["files"].keys() | {"artifact-bindings.json"}, "Control original membership differs")
    for name, expected in ctl_bindings["files"].items():
        data = control[name]
        require(len(data) == expected["bytes"] and sha(data) == expected["sha256"], "Control original bytes differ")
    require(diagnostic.keys() == bindings["diagnostic_members"].keys(), "Diagnostic original membership differs")
    for name, expected in bindings["diagnostic_members"].items():
        data = diagnostic[name]
        require(len(data) == expected["bytes"] and sha(data) == expected["sha256"], "Diagnostic original bytes differ")
        if expected["transform"] == "gzip mtime=0":
            original = gzip.decompress(data)
            require(len(original) == expected["original_bytes"] and sha(original) == expected["original_sha256"], "Diagnostic original ELF differs")


def replay_control(control):
    with tempfile.TemporaryDirectory(prefix="vort-q8-control-audit-") as directory:
        temporary = Path(directory)
        for name, data in control.items():
            path = temporary / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        verifier = module("archived_q8_control_verifier", temporary / "verify.py")
        with contextlib.redirect_stdout(io.StringIO()):
            receipt = verifier.verify()
        require(receipt == json.loads(control["verification-receipt.json"]), "Replayed control verification receipt differs")
        require(control["raw-pairs.csv"] == (ROOT / "raw-pairs.csv").read_bytes() and b"\r" not in control["raw-pairs.csv"], "LF raw ns ledger differs")
        return receipt


def check_control_extras(control, diagnostic):
    settings = json.loads(control["settings.json"])
    equivalence = json.loads(control["baseline-equivalence.json"])
    rechecked = json.loads(diagnostic["rechecked-identity/codec-equivalence-recheck.json"])
    c2 = diagnostic["rechecked-identity/c2-codec-blobs.txt"]
    e41 = diagnostic["rechecked-identity/e41-codec-blobs.txt"]
    require(c2 == e41 == control["codec-blob-listing.txt"] and len(c2.splitlines()) == 2217, "c2/e41 codec blob entries differ")
    require(rechecked["exact_blob_listing_equal"] and rechecked["entries"] == equivalence["tracked_blob_count"] == 2217, "Codec equality receipts differ")
    require(sha(c2) == rechecked["blob_listing_sha256"] == equivalence["blob_listing_sha256"], "Codec blob-listing hash differs")
    require(rechecked["revisions"] == ["c2c8f250302ca2f223740076482dd95b1788eeb1", "e41aa51cc9e6df8f039187435a65c93371d717d6"], "Logical/reused source CIDs differ")
    baseline = json.loads(control["baseline-wire-bindings.json"])
    initial = json.loads(control["preflight-summary.json"])
    for row in initial["rows"]:
        require(row["actual_window_bits"] == 16 and row["input_bytes"] == 65536, "Initial format/input differs")
        if row["variant"] == "feedback_on":
            require(row["wire_sha256"] == baseline[row["case"]]["wire_sha256"] and row["wire_bytes"] == baseline[row["case"]]["wire_bytes"], "Reused baseline complete wire differs")
    decoder = json.loads(control["decoder-binding.json"])
    require(decoder["version"] == "1.2.0" and decoder["version_number"] == 0x1002000, "Pinned decoder receipt differs")
    for record in decoder["files"]:
        require(sha(control["references/" + Path(record["path"]).name]) == record["sha256"], "Pinned decoder/common bytes differ")
    require(len(control["references/BROTLI-LICENSE"]) > 0, "Brotli license missing")
    manifest = json.loads(control["run-manifest.json"])
    host = json.loads(control["host-observations.json"])
    snapshots = [pair["host_before"] for pair in manifest["pairs"]]
    loads = [float(snapshot["loadavg"].split()[0]) for snapshot in snapshots]
    require(len(snapshots) == host["per_pair_snapshots"] == 90 and min(loads) == host["load1m_min"] and max(loads) == host["load1m_max"], "Load observation summary differs")
    for field, predicate in (
        ("collector_seen_pairs", lambda item: "collect.py" in item["args"]),
        ("zig_compile_seen_pairs", lambda item: item["comm"] == "zig"),
        ("full_file_brotli_seen_pairs", lambda item: "vort-br-planned-encode-bench" in item["args"] and ".full.plain" in item["args"]),
        ("full_file_deflate_seen_pairs", lambda item: "vort-deflate-encode-bench" in item["args"] and ".full.plain" in item["args"]),
    ):
        count = sum(any(predicate(item) for item in snapshot["collector_and_validation_activity"]) for snapshot in snapshots)
        require(count == host[field], "Observed validation/collector summary differs")
    return host


def verify():
    check_inventory()
    bindings = json.loads((ROOT / "archive-bindings.json").read_bytes())
    control, diagnostic = members("control.tar.gz"), members("diagnostics.tar.gz")
    check_archives(bindings, control, diagnostic)
    receipt = replay_control(control)
    host = check_control_extras(control, diagnostic)
    negative = module("q8_negative_audit", ROOT / "negative.py").derive(control, diagnostic)
    expected = json.loads((ROOT / "summary.json").read_bytes())
    require(expected["control"] == json.loads(control["summary.json"]), "Published complete control summary differs")
    require(expected["negative"] == negative and expected["host"] == host, "Published negative/host summary differs")
    return {
        "schema": "vort.q8-feedback-control.publication-verification.v1",
        "inventory_verified": True, "control_original_members": len(control), "diagnostic_original_members": len(diagnostic),
        "control_verified_pairs": receipt["verified_pairs"], "control_verified_timed_calls": receipt["verified_timed_calls"],
        "control_recomputed_matrix": receipt["recomputed_matrix"],
        "sole_q8_flag_overlay_and_q9_true_verified": True, "c2_e41_equal_codec_blob_entries": 2217,
        "baseline_and_initial_wire_bindings_verified": 24,
        "negative_rows_verified": len(negative["rows"]), "negative_exact_price_hits": 0, "negative_exact_command_hits": 0,
        "nci_three_modeled_passes": negative["nci_modeled_three_passes"],
        "helper_test_receipt_passed": 12, "host_load1m_range": [host["load1m_min"], host["load1m_max"]],
        "scope": "Offline original-byte/identity/scope audit and paired statistics replay. Original helper/decode/source-build runs are retained receipts. No codec, original ELF, build, test or Git execution; diagnostics have zero ordinary timed samples and temporary global IO only.",
    }


if __name__ == "__main__":
    print(json.dumps(verify(), indent=2, sort_keys=True))
