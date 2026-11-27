#!/usr/bin/env python3
"""Capture this rejected pilot as data; never modify the original epoch."""
import sys
sys.dont_write_bytecode = True
import hashlib
import json
import os
from pathlib import Path
import tarfile

ORIGINAL = Path("/tmp/vort-zstd-fallback-after-clone-types.wrbqrdqz")
OUTPUT = Path(__file__).resolve().parent


def identity(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(data)
    return {"bytes": path.stat().st_size, "sha256": digest.hexdigest()}


def main():
    archive_path = OUTPUT / "epoch-data.tar.xz"
    if archive_path.exists(): raise ValueError("Preserve first archive; no overwrite")
    raw = json.loads((ORIGINAL / "pilot/run-manifest.json").read_bytes())
    summary = json.loads((ORIGINAL / "pilot/summary.json").read_bytes())
    if not raw["completed"] or not raw["terminal"] or summary["target_gate_pass"] is not False:
        raise ValueError("Only the complete first rejected pilot may be captured")
    if len(raw["pairs"]) != 24 or len(raw["attempts"]) != 48: raise ValueError("Original24/48 matrix required")
    ready = json.loads((ORIGINAL / "SOURCE_READY.json").read_bytes())
    whole = ready["original_whole_library"]
    copies = {}
    for key, record in whole.items():
        original = Path(record["path"]);actual = identity(original)
        if actual["sha256"] != record["sha256"]:raise ValueError("Original whole evidence changed")
        target = OUTPUT / ("whole-original-" + key + original.suffix)
        if target.exists():raise ValueError("Keep first whole artifact")
        target.write_bytes(original.read_bytes())
        copies[target.name] = {**actual, "origin": str(original)}
    gate_receipt = json.loads(Path(whole["receipt"]["path"]).read_bytes())
    if gate_receipt["actual_exit_code"] != 0 or gate_receipt["source_unchanged"] is not True:
        raise ValueError("Original actual whole gate did not pass")
    adapter = {"schema": "vort.codec.whole-gate-data-adapter.v1", "issued_by": "/root", "state": "passed", "actual_exit_code": 0,
        "test_check_check_wasm_all_accepted": ready["all_test_check_check_wasm_accepted"],
        "source_manifest_sha256": ready["candidate_source_manifest_sha256"], "source_current_at_original_gate": ready["source_current"],
        "original_whole_library": whole, "derived_data_only": True, "not_new_gate_or_timing_release": True}
    (OUTPUT / "whole-gate-receipt.json").write_text(json.dumps(adapter, indent=2, sort_keys=True) + "\n")
    entries = {}
    sources = []
    excluded = {"cache", "global-cache", "local-cache", ".zig-cache", "__pycache__"}
    for folder, directories, names in os.walk(ORIGINAL):
        relative = Path(folder).relative_to(ORIGINAL)
        # Frozen source registries own any recorded src bytecode. Other runner
        # caches are omitted. No report/failed sample/producer filtering occurs.
        if not relative.parts or relative.parts[0] != "sources":
            directories[:] = sorted(name for name in directories if name not in excluded)
        for name in sorted(names):
            path = Path(folder) / name
            if path.is_file(): sources.append(path)
    with tarfile.open(archive_path, "w:xz", preset=1) as archive:
        for source in sorted(sources):
            relative = str(source.relative_to(ORIGINAL));actual = identity(source)
            target = source.resolve()
            if source.is_symlink() and not target.is_relative_to(ORIGINAL): raise ValueError("External link not authorized")
            member = tarfile.TarInfo(relative)
            member.size, member.mode, member.mtime = actual["bytes"], 0o644, 0
            with target.open("rb") as stream: archive.addfile(member, stream)
            entries[relative] = {**actual, "origin": str(source), "symlink_origin_target": str(target) if source.is_symlink() else None}
    verifier = ORIGINAL / "verify-evidence.py"
    (OUTPUT / verifier.name).write_bytes(verifier.read_bytes())
    manifest = {"schema": "vort.codec.final-evidence.v1", "codec": "zstd", "original_epoch_root": str(ORIGINAL),
        "selected_phases": ["pilot"], "phase_states": {"pilot": "completed", "formal": "not_run", "controls": "not_run", "reference": "not_run"},
        "whole_gate_state": "passed", "full_gate_passed": True, "archive": {"path": archive_path.name, **identity(archive_path)},
        "entries": entries, "gate_artifacts": copies, "whole_gate_receipt_sha256": identity(OUTPUT / "whole-gate-receipt.json")["sha256"],
        "verifier_sha256": identity(OUTPUT / verifier.name)["sha256"], "original_raw_unmodified": True,
        "codec_build_or_replay_executed": False, "Root_archive_authorization": "Explicit parent task: preserve failed pilot unchanged; no formal release",
        "sample_selection_filter_applied": False, "cache_omission_policy": "Omit only non-source compilation/runner caches; complete source directories and registry members retained"}
    (OUTPUT / "evidence-manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"members": len(entries), "archive": manifest["archive"], "pilot_pairs": 24, "pilot_children": 48,
        "original_epoch_modified": False, "performance_decision": "reject", "formal_authorized": False}, indent=2))


if __name__ == "__main__":
    main()
