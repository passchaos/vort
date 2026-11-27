#!/usr/bin/env python3
"""Bounded diagnostic-v2 saved-data export; no captured program is executed."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile
import sys

sys.dont_write_bytecode = True
from package_io import ArchiveStore, OriginalStore, identity, member_name, require
import importlib.util

HERE = Path(__file__).resolve().parent
ROOT = Path("/tmp/vort-deflate-stream-after-clone-types._u2f_kn5")
WHOLE = Path("/tmp/vort-encoder-contract-integration.44n9_fus/whole-library-after-clone-types")


def json_file(path):
    return json.loads(path.read_text())


def write_json(path, value):
    require(not path.exists(), "Preserve first export output: " + str(path))
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def export():
    require(not (HERE / "epoch-data.tar").exists() and not (HERE / "evidence-manifest.json").exists(), "First export already exists")
    spec = importlib.util.spec_from_file_location("independent_diagnostic_data_verifier", HERE / "verify-evidence.py")
    verifier = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(verifier)
    entries = {}

    def add(path, role, declared=None):
        path = Path(path)
        if path.is_relative_to(ROOT):
            member = "epoch/" + path.relative_to(ROOT).as_posix()
        else:
            require(path.is_relative_to(WHOLE), "Unregistered external artifact")
            member = "whole-gate/" + path.relative_to(WHOLE).as_posix()
        original = str(path)
        if original in entries:
            entries[original]["roles"] = sorted(set(entries[original]["roles"] + [role]))
            if declared is not None:
                require(entries[original].get("declared") in (None, declared), "Conflicting declared identity")
                entries[original]["declared"] = declared
        else:
            entries[original] = {"member": member_name(member), "roles": [role], "declared": declared}

    metadata = (
        "SOURCE_READY.json", "protocol.json", "preflight.json", "preflight-results.json", "execution-bindings.json", "decoder-receipt.json",
        "baseline-source-manifest.json", "candidate-source-manifest.json", "build-lengthcheck-results.json", "fresh-preparation-seal.json",
        "final-untimed-validation.json", "sampler.py", "sampler-v2.py", "release.json", "release.example.json", "release-diagnostic-v2.json",
        "root-diagnostic-terminal.json", "root-diagnostic-output.log", "root-diagnostic-v2-terminal.json", "root-diagnostic-v2-output.log",
        "row-binding-originals-before.json", "row-binding-fix.json", "row-binding-fix-final-receipt.json", "release-v2.example.json",
        "diagnostic-v2-data-checks.py", "diagnostic-v2-data-checks-results.json", "harness/probe-lengthcheck.zig", "harness/provenance.zig",
        "diagnostic-v2/run-manifest.json", "diagnostic-v2/summary.json", "diagnostic-v2/status.json",
    )
    for name in metadata:
        add(ROOT / name, "original-metadata-or-program-data")
    protocol = json_file(ROOT / "protocol.json")
    for row in protocol["rows"]:
        add(row["path"], "input", {key: row[key] for key in ("bytes", "sha256")})
    bindings = json_file(ROOT / "execution-bindings.json")
    for item in bindings.values():
        add(item["ELF"], "actual-ELF", {"bytes": Path(item["ELF"]).stat().st_size, "sha256": item["sha256"]})
    built = json_file(ROOT / "build-lengthcheck-results.json")
    for item in built["stages"]:
        for name in ("stdout", "stderr"):
            add(item[name], "actual-build-log", {"bytes": Path(item[name]).stat().st_size, "sha256": item[name + "_sha256"]})
        add(ROOT / "build/lengthcheck" / (item["stage"] + ".receipt.json"), "actual-build-receipt")
    for variant in ("baseline", "candidate"):
        registry = json_file(ROOT / (variant + "-source-manifest.json"))
        for relative, checksum in registry.items():
            path = ROOT / "sources" / variant / relative
            add(path, "complete-frozen-source", {"bytes": path.stat().st_size, "sha256": checksum})
    initial = json_file(ROOT / "preflight-results.json")
    raw = json_file(ROOT / "diagnostic-v2/run-manifest.json")
    for item in initial["attempts"]:
        for key in ("output", "wire", "stdout", "stderr"):
            add(item[key], "original108-warm-artifact")
    for item in raw["attempts"]:
        for key in ("output", "wire", "stdout", "stderr"):
            add(item[key], "original216-diagnostic-artifact")
    require({str(p) for p in (ROOT / "diagnostic-v2/runs").iterdir() if p.is_file()} ==
            {item[key] for item in raw["attempts"] for key in ("output", "wire", "stdout", "stderr")}, "Exact864 diagnostic raw file inventory differs")
    require({str(p) for p in (ROOT / "preflight/controls").iterdir() if p.is_file()} ==
            {item[key] for item in initial["attempts"] for key in ("output", "wire", "stdout", "stderr")}, "Exact432 original warm file inventory differs")
    ready = json_file(ROOT / "SOURCE_READY.json")
    for item in ready["original_whole_library"].values():
        add(item["path"], "original-five-whole-gate-artifacts", {"bytes": Path(item["path"]).stat().st_size, "sha256": item["sha256"]})
    v1_absent = not (ROOT / "diagnostic/run-manifest.json").exists()
    require(v1_absent, "Original v1 unexpectedly reached a run manifest")
    store = OriginalStore(entries)
    binding = {"schema": "vort.deflate.diagnostic-rejection.portable.v1", "original_epoch_root": str(ROOT),
               "original_v1_run_manifest_absent": v1_absent, "selected_phase": "diagnostic-v2", "entries": entries,
               "originals_modified": False, "new_codec_or_build_or_sampling_or_RSS_executed": False,
               "recorded_Root_tool_terminal": {"session": 25587, "chunk": "897097", "actual_exit_code": 0,
                                                "provenance": "Root task instruction; original terminal JSON retained separately"}}
    result = verifier.audit_data(store, binding)
    records = {original: {"member": value["member"], "roles": value["roles"], **store.identity(original)}
               for original, value in entries.items()}
    archive_path = HERE / "epoch-data.tar"
    with tarfile.open(archive_path, "w:") as archive:
        for original, item in sorted(records.items()):
            with store.open(original) as source:
                require(identity(source) == {key: item[key] for key in ("bytes", "sha256")}, "Original changed before data copy")
            member = tarfile.TarInfo(item["member"])
            member.size, member.mode, member.mtime = item["bytes"], 0o644, 0
            with store.open(original) as source:
                archive.addfile(member, source)
    with archive_path.open("rb") as source:
        binding["archive"] = {"path": archive_path.name, **identity(source)}
    binding["entries"] = records
    binding["original_data_verification"] = result
    binding["verification_tools"] = {}
    for name in ("verify-evidence.py", "package_io.py"):
        with (HERE / name).open("rb") as source:
            binding["verification_tools"][name] = identity(source)
    binding["adapter_provenance"] = {
        "package_io": {"origin": "/tmp/vort-deflate-formal-portable-xbrd9jak/package_io.py",
                       "origin_sha256": hashlib.sha256(Path("/tmp/vort-deflate-formal-portable-xbrd9jak/package_io.py").read_bytes()).hexdigest(),
                       "change": "strict original-to-member archive store reused; read uncompressed tar"},
        "point_replay": {"origin": str(ROOT / "verify-evidence.py"),
                         "origin_sha256": hashlib.sha256((ROOT / "verify-evidence.py").read_bytes()).hexdigest(),
                         "change": "fixed54-row diagnostic-v2 resolver; added exact argv/provenance/warm/source checks; no bootstrap branch"}}
    copied = ArchiveStore(archive_path, records)
    try:
        for original in records:
            copied.identity(original)
        copied_result = verifier.audit_data(copied, binding)
    finally:
        copied.close()
    require(result == copied_result, "Original/copy independent data verification differs")
    write_json(HERE / "evidence-manifest.json", binding)
    return {"members": len(records), "archive": binding["archive"], "result": copied_result,
            "original_files_modified": False, "codec_or_build_or_sampling_or_RSS_executed": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    print(json.dumps(export(), indent=2, sort_keys=True))
