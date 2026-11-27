#!/usr/bin/env python3
"""Archive first rejected pilot; never launches a codec, compiler or sample."""
import hashlib
import json
import shutil
import subprocess
import tarfile
from datetime import datetime, timezone
from pathlib import Path

REPO = Path("/home/passchaos/project-z/vort")
EPOCH = Path(__file__).resolve().parent
LEGACY = Path("/tmp/vort-br-original-command-split-reuse-ab.egqd38jr")
PUBLIC = Path("/tmp/vort-br-assignment-phase-public-gate-fe5axeqn")
REJECTION = Path("/tmp/vort-br-assignment-rejection-root.2c8a4fm2")
AUDIT = Path("/tmp/vort-round4ctx-pilot-audit.QzJXn8")
PACKAGE = REPO / "docs/performance/br/assignment-round-20261127"
OLD_PACKAGE = REPO / "docs/performance/br/original-command-split-plans-20261127"


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    assert sha(source) == sha(target)


def normalize(info):
    info.uid = info.gid = 0
    info.uname = info.gname = ""
    info.mtime = 0
    return info


def main():
    PACKAGE.mkdir(parents=True, exist_ok=True)
    if (PACKAGE / "payload/candidate-src.tar.xz").exists():
        raise RuntimeError("Archive payload already exists; never overwrite a sealed package")
    raw = PACKAGE / "raw/epoch"
    for p in sorted(EPOCH.rglob("*")):
        if not p.is_file():
            continue
        rel = p.relative_to(EPOCH)
        if rel.parts[0] in ("sources", "bin") or "cache" in str(rel) or "__pycache__" in rel.parts or p.suffix == ".o" or p.name == "archive-negative.py":
            continue
        copy(p, raw / rel)
    fixtures = read(EPOCH / "fixtures-method.json") + read(EPOCH / "small-fixtures-method.json")
    for f in fixtures:
        copy(Path(f["path"]), PACKAGE / "raw/legacy" / Path(f["path"]).relative_to(LEGACY))
    for f in read(EPOCH / "fixtures-method.json"):
        copy(Path(f["golden_path"]), PACKAGE / "raw/legacy" / Path(f["golden_path"]).relative_to(LEGACY))
    for name in ("build/candidate.receipt.json", "harness/probe.zig", "harness/provenance.zig"):
        copy(LEGACY / name, PACKAGE / "raw/legacy" / name)
    for p in REJECTION.rglob("*"):
        if p.is_file():
            copy(p, PACKAGE / "raw/root-rejection" / p.relative_to(REJECTION))
    for name in ("verify.py", "receipt.json"):
        copy(AUDIT / name, PACKAGE / "raw/independent" / name)
    # Save public first compile failure and final Native/WASI observations,
    # without copying either complete public source tree or build caches.
    for p in PUBLIC.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(PUBLIC)
        if rel.parts[0] in ("SOURCE", "SOURCE-attempt-1", "bin", "objects", "cache", "global-cache"):
            continue
        copy(p, PACKAGE / "raw/public-narrow" / rel)
    copy(PUBLIC / "SOURCE/src/br/encoder/assignment/phase_public_tests.zig", PACKAGE / "raw/public-narrow/first-quota-source.zig")
    manifest = read(EPOCH / "candidate-source-files.json")
    source_root = EPOCH / "sources/candidate"
    for rel, checksum in manifest.items():
        assert sha(source_root / rel) == checksum
    payload = PACKAGE / "payload"
    payload.mkdir(exist_ok=True)
    print("archive complete candidate source", len(manifest), flush=True)
    with tarfile.open(payload / "candidate-src.tar.xz", "w:xz", preset=1) as archive:
        for rel in sorted(manifest):
            archive.add(source_root / rel, arcname=rel, recursive=False, filter=normalize)
    # Four small baseline overrides reconstruct all2222 Git46d src files
    # from the candidate closure without duplicating the old source tree.
    base_manifest = read(EPOCH / "baseline46d-source-files.json")
    overrides = [rel for rel, checksum in base_manifest.items() if manifest.get(rel) != checksum]
    assert len(overrides) == 4
    for rel in overrides:
        copy(EPOCH / "sources/baseline46d" / rel, PACKAGE / "raw/baseline-overrides" / rel)
    runtime = ["bin/candidate", "bin/candidate-controls", "bin/baseline-controls", "build/candidate-record.o"]
    print("archive only four new runtime artifacts", flush=True)
    with tarfile.open(payload / "new-runtime.tar.xz", "w:xz", preset=1) as archive:
        for rel in runtime:
            archive.add(EPOCH / rel, arcname=rel, recursive=False, filter=normalize)
    old_manifest = read(OLD_PACKAGE / "portable-manifest.json")
    envelope = read(OLD_PACKAGE / "archive-envelope.json")
    anchors = {str(LEGACY / "bin/candidate"), str(LEGACY / "bin/reference"), str(LEGACY / "build/candidate-record.o"), *(item["path"] for item in read(LEGACY / "libbrotli-direct/library-paths.json")["libraries"].values())}
    entries = [a for a in old_manifest["artifacts"] if a["origin_path"] in anchors]
    assert len(entries) == 6
    tree = subprocess.run(["git", "ls-tree", "-r", "46d340ac03ab211aa3f745b650e76f0bf530744d", "--", str(OLD_PACKAGE.relative_to(REPO))], cwd=REPO, capture_output=True, text=True, check=True).stdout
    blobs = {line.split("\t", 1)[1]: line.split("\t", 1)[0].split()[2] for line in tree.splitlines()}
    part_checks = []
    joined = hashlib.sha256()
    for part in envelope["parts"]:
        file = OLD_PACKAGE / part["path"]
        assert file.stat().st_size == part["bytes"] and sha(file) == part["sha256"]
        with file.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                joined.update(chunk)
        part_checks.append({**part, "git_blob_46d": blobs[str(file.relative_to(REPO))]})
    assert joined.hexdigest() == envelope["sha256"]
    write(PACKAGE / "old-package-link.json", {"committed_revision": "46d340ac03ab211aa3f745b650e76f0bf530744d", "repository_relative_package": str(OLD_PACKAGE.relative_to(REPO)), "archive_bytes": envelope["bytes"], "joined_archive_sha256": envelope["sha256"], "parts": part_checks, "portable_manifest_sha256": sha(OLD_PACKAGE / "portable-manifest.json"), "portable_manifest_git_blob": blobs[str((OLD_PACKAGE / "portable-manifest.json").relative_to(REPO))], "exact_members": entries, "old185MB_payload_not_copied": True})
    write(PACKAGE / "source-layout.json", {"candidate_archive": "payload/candidate-src.tar.xz", "runtime_archive": "payload/new-runtime.tar.xz", "candidate_registry": "raw/epoch/candidate-source-files.json", "baseline_registry": "raw/epoch/baseline46d-source-files.json", "baseline_overrides": overrides, "candidate_files": len(manifest), "baseline_files": len(base_manifest), "source_restoration": "Candidate is complete. Baseline takes only its registered paths from candidate, replaces these four files with raw/baseline-overrides, and omits candidate-only files.", "recorded_epoch_root": str(EPOCH), "recorded_legacy_root": str(LEGACY), "raw_receipts_unmodified": True})
    write(PACKAGE / "root-pilot-terminal.json", {"kind": "Root supplied actual terminal attestation; original tool session stdout is not synthesized", "session": 95717, "actual_exit_code": 0, "pairs": 24, "processes": 48, "HEAVY": 0, "decision": "rejected, no further phase released", "full_gate_passed": False})
    write(PACKAGE / "remaining-phases.json", {"formal": "not released, not run", "public_controls_timed": "not released, not run", "small_controls_timed": "not released, not run", "historical_direct": "not released, not run", "reference_direct": "not released, not run", "full_gate_passed": False, "candidate_not_merged": True, "no_retry": True})
    copy(Path(__file__), PACKAGE / "archive-builder.py")
    print(json.dumps({"package": str(PACKAGE), "candidate_source_archive_bytes": (payload / "candidate-src.tar.xz").stat().st_size, "new_runtime_archive_bytes": (payload / "new-runtime.tar.xz").stat().st_size, "candidate_files": len(manifest), "old_package_linked_bytes_not_copied": envelope["bytes"]}, indent=2), flush=True)


if __name__ == "__main__":
    main()
