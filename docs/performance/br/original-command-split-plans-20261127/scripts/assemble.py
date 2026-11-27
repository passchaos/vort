"""Deferred portable collection/compression, gated by Root's final release."""
import argparse
import hashlib
import json
import os
import shutil
import tarfile
from pathlib import Path
from common import PACKAGE, read_json, require_release, require_terminal_final_gates, write_json
from audit_scopes import audit


def file_sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def collect_tree(origin, destination, prefix, scope, plan, artifacts, recovered=False):
    origin = Path(origin)
    if not origin.exists() and not origin.is_symlink():
        raise ValueError(f"Missing declared artifact root: {origin}")
    skipped_dirs = set(plan["exclusions"]["directory_names"])
    skipped_suffixes = tuple(plan["exclusions"]["generated_suffixes"])
    protected_sources = [Path(path) for path in plan.get("protected_source_roots", [])]

    def collect(path, relative):
        logical = str(Path(prefix) / relative)
        target = destination / logical
        target.parent.mkdir(parents=True, exist_ok=True)
        entry = {"logical_path": logical, "origin_path": str(path), "scope": scope,
                 "recovered": recovered}
        if path.is_symlink():
            # Preserve metadata without following a live source or external lib.
            logical += ".symlink.json"
            target = destination / logical
            entry.update(logical_path=logical, kind="symlink-metadata", link_target=os.readlink(path))
            write_json(target, {"origin_path": str(path), "link_target": entry["link_target"],
                                "target_followed": False})
        else:
            shutil.copyfile(path, target)
            entry["kind"] = "file"
        entry.update(sha256=file_sha(target), bytes=target.stat().st_size)
        artifacts.append(entry)

    if origin.is_file() or origin.is_symlink():
        collect(origin, origin.name)
        return
    for current, dirs, files in os.walk(origin, followlinks=False):
        current = Path(current)
        source_scope = any(current.is_relative_to(root) for root in protected_sources)
        dirs[:] = sorted((name for name in dirs if name != ".zig-cache") if source_scope else
                         (name for name in dirs if name not in skipped_dirs and not name.endswith("-cache")))
        for name in list(dirs):
            path = current / name
            if path.is_symlink():
                collect(path, path.relative_to(origin))
                dirs.remove(name)
        for name in sorted(files):
            if not source_scope and name.endswith(skipped_suffixes):
                continue
            path = current / name
            collect(path, path.relative_to(origin))


def normalized_source_manifest(payload):
    if isinstance(payload, dict) and "files" in payload:
        payload = payload["files"]
    if isinstance(payload, list):
        return {row["path"]: row["sha256"] for row in payload}
    return {path: value if isinstance(value, str) else value["sha256"]
            for path, value in payload.items()}


def verify_frozen_source_copies(epochs, artifacts):
    copied = {row["origin_path"]: row["sha256"] for row in artifacts if row["kind"] == "file"}
    verified = []
    for epoch in epochs["epochs"]:
        if not epoch.get("root") or not isinstance(epoch.get("manifest"), str):
            continue
        if epoch["id"] == "historical-comparators":
            continue  # Build/source equality receipts retain their own scope.
        root = Path(epoch["root"])
        expected = normalized_source_manifest(read_json(epoch["manifest"]))
        for relative, digest in expected.items():
            origin = str(root / relative)
            if copied.get(origin) != digest:
                raise ValueError(f"Frozen source copy mismatch or missing: {epoch['id']} {relative}")
        verified.append({"epoch": epoch["id"], "files": len(expected),
                         "scope": "copied bytes match that epoch's own recorded source manifest"})
    return verified


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", required=True)
    parser.add_argument("--data-dir", default="data")
    parser.add_argument("--archive-name", default="evidence.tar.xz")
    args = parser.parse_args()
    release = require_release(args.release)
    plan = read_json(PACKAGE / "package-plan.json")
    epochs = read_json(PACKAGE / "source-epochs.json")
    plan["protected_source_roots"] = [entry["root"] for entry in epochs["epochs"]
                                      if entry.get("root") and (isinstance(entry.get("manifest"), str)
                                                               or entry["id"].endswith("-compiled-snapshot"))
                                      and entry["id"] != "historical-comparators"]
    actual_exits = require_terminal_final_gates(plan)
    if release["final_verdict"]["status"] == "accepted" and any(row["actual_exit"] != 0 for row in actual_exits):
        raise ValueError("Accepted verdict conflicts with required final gate exit; prior failures remain separate")
    proof, diff = audit()
    if not proof["non_test_tokens_equal"]:
        write_json(PACKAGE / "proofs/source-scope-audit-failed.json", proof)
        raise ValueError("Production source scope differs; retain failed proof and reconcile epochs")
    destination = (PACKAGE / args.data_dir).resolve()
    archive = (PACKAGE / args.archive_name).resolve()
    if not destination.is_relative_to(PACKAGE) or not archive.is_relative_to(PACKAGE):
        raise ValueError("Output must remain in the owned evidence package")
    if archive.is_relative_to(destination):
        raise ValueError("Archive cannot be placed inside its own payload tree")
    if destination.exists() or archive.exists():
        raise ValueError("Refuse to overwrite an existing evidence payload")
    write_json(PACKAGE / "proofs/source-scope-audit.json", proof)
    (PACKAGE / "proofs/public-vs-final-full.diff").write_text(diff)
    destination.mkdir(parents=True)
    artifacts = []
    for group in plan["groups"]:
        collect_tree(group["root"], destination, "raw/" + group["id"], group["retain"], plan, artifacts)
    for extra in plan.get("additional_paths", []) + release.get("extra_artifacts", []):
        first = len(artifacts)
        collect_tree(extra["path"], destination, "extra/" + extra["id"], extra["scope"], plan, artifacts, extra.get("recovered", False))
        if extra.get("expected_sha256"):
            new = artifacts[first:]
            if len(new) != 1 or new[0]["kind"] != "file" or new[0]["sha256"] != extra["expected_sha256"]:
                raise ValueError(f"Explicit bound artifact mismatch: {extra['id']}")
    collect_tree(release["final_verdict"]["record"], destination, "verdict", "Root final verdict, including rejection", plan, artifacts)
    for path in sorted(PACKAGE.glob("*.json")):
        collect_tree(path, destination, "metadata", "Static package plan/schema/source mappings", plan, artifacts)
    collect_tree(PACKAGE / "README.md", destination, "metadata", "Final Root accepted verdict and metric scope", plan, artifacts)
    collect_tree(PACKAGE / "scripts", destination, "scripts", "Portable collection and verification tools", plan, artifacts)
    collect_tree(PACKAGE / "proofs", destination, "proofs", "Recorded source epoch differences", plan, artifacts)
    source_copy_verification = verify_frozen_source_copies(epochs, artifacts)
    portable = {group["root"]: "raw/" + group["id"] for group in plan["groups"]}
    for extra in plan.get("additional_paths", []) + release.get("extra_artifacts", []):
        original = Path(extra["path"])
        portable[str(original)] = str(Path("extra") / extra["id"] / original.name) if original.is_file() else "extra/" + extra["id"]
    manifest = {
        "schema": "vort.original-command-split-plans.portable-manifest.v1",
        "phase": "assembled-after-root-release", "release": release,
        "actual_final_exits": actual_exits, "artifacts": artifacts,
        "source_scope_proof": proof, "source_epochs": epochs,
        "source_copy_verification": source_copy_verification,
        "portable_root_mapping": portable,
        "limitations": [
            "No original command/exit/raw verdict was rewritten; original absolute paths remain provenance.",
            "Public and final source epochs differ in test declarations/imports and are not identical trees.",
            "Original standalone Owner Native ELF was not explicitly retained; any later recovery is labeled recovered.",
            "Current whole-test ELF coverage does not invent an old standalone binary identity.",
            "Per-file old Choice captures are not automatically complete old source trees.",
            "Symlinks preserve metadata only; missing external targets require explicit Root extra artifacts.",
            "A gate pass or untimed preflight is not a throughput or competitor claim.",
        ],
    }
    write_json(destination / "manifest.json", manifest)
    with tarfile.open(archive, "w:xz", preset=1) as output:
        output.add(destination, arcname=destination.name)
    write_json(PACKAGE / "archive-envelope.json", {
        "schema": "vort.original-command-split-plans.archive-envelope.v1",
        "archive": archive.name, "bytes": archive.stat().st_size,
        "sha256": file_sha(archive), "manifest": str(Path(args.data_dir) / "manifest.json"),
        "HEAVY": 0, "root_release": str(Path(args.release).resolve()),
    })
    print(archive)


if __name__ == "__main__":
    main()
