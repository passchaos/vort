#!/usr/bin/env python3
"""Verify copied proof bytes, provenance links, and optional retained artifacts."""
import argparse
import hashlib
import json
import re
from pathlib import Path


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_hash(root):
    entries = sorted(
        (str(path.relative_to(root)), sha256(path))
        for path in root.rglob("*")
        if path.is_file()
    )
    digest = hashlib.sha256()
    for name, value in entries:
        digest.update(name.encode() + b"\0" + value.encode() + b"\n")
    return len(entries), digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--external-root", type=Path)
    parser.add_argument("--source-root", type=Path)
    options = parser.parse_args()
    archive = Path(__file__).resolve().parent
    proof = json.loads((archive / "proof.json").read_text())
    checked = 0

    def require(condition, detail):
        nonlocal checked
        if not condition:
            raise SystemExit("verification failed: " + detail)
        checked += 1

    def load(name):
        return json.loads((archive / name).read_text())

    for name, expected in proof["artifacts"].items():
        path = archive / name
        require(path.is_file(), "missing artifact " + name)
        require(path.stat().st_size == expected["bytes"], "artifact size " + name)
        require(sha256(path) == expected["sha256"], "artifact SHA-256 " + name)

    external = proof["external_artifacts"]["artifacts"]
    before = load("before.manifest.json")
    after = load("after.manifest.json")
    require(before["revision"] == proof["before_git_revision"], "before Git revision")
    require(
        (archive / "before.source-revision.txt").read_text().strip()
        == proof["before_git_revision"],
        "revision receipt",
    )
    for prefix, manifest in [("before", before), ("after", after)]:
        require(sha256(archive / (prefix + ".zig")) == manifest["probe_sha256"], prefix + " probe")
        require(external[prefix]["sha256"] == manifest["exe_sha256"], prefix + " binary binding")
        require(int((archive / (prefix + ".build.exit-code.txt")).read_text()) == 0, prefix + " build")
        expected_exit = -6 if prefix == "before" else 0
        for operation, result in load(prefix + ".run-results.json").items():
            require(result["returncode"] == expected_exit, prefix + " " + operation + " exit")
            require(result["log"] in proof["artifacts"], prefix + " " + operation + " log binding")
    require(
        external["before.source.tar"]["sha256"] == before["source_archive_sha256"],
        "before source tar binding",
    )
    pending = load("pending.manifest.json")
    for prefix in ["before", "after"]:
        require(
            sha256(archive / (prefix + "-pending.zig")) == pending[prefix + "_probe_sha256"],
            prefix + " pending source",
        )
    for stem, expected_exit in [
        ("before-pending-debug", -6),
        ("before-pending-releasefast", 1),
        ("after-pending-debug", 0),
    ]:
        metadata = load(stem + ".manifest.json")
        prefix = stem.split("-")[0]
        require(metadata["build_exit_code"] == 0, stem + " build")
        require(metadata["run_exit_code"] == expected_exit, stem + " run")
        require(metadata["exe_sha256"] == external[stem]["sha256"], stem + " binary")
        require(metadata["source_probe_sha256"] == sha256(archive / (prefix + "-pending.zig")), stem + " source")
        require(metadata["run_log_sha256"] == sha256(archive / (stem + ".run.log")), stem + " run bytes")

    for final, manifest_name in [(False, "focused-tests.manifest.json"), (True, "followup-completion.manifest.json")]:
        metadata = load(manifest_name)
        for mode in ["debug", "releasesafe"]:
            stem = ("followup-tests-" if final else "tests-") + mode
            log = archive / (stem + ".log")
            results = metadata["results"][mode] if final else metadata["modes"][mode]
            binary_key = "exe_sha256" if final else "executable_sha256"
            require(results["exit_code"] == 0, stem + " exit metadata")
            require(int((archive / (stem + ".exit-code.txt")).read_text()) == 0, stem + " exit receipt")
            require(results[binary_key] == external[stem]["sha256"], stem + " binary")
            require(results["log_sha256"] == sha256(log), stem + " log bytes")
            contents = log.read_text()
            expected_named = 14 if final else 12
            expected_total = 104 if final else 102
            require(len(re.findall(r"\.test\.dictionary borrows ", contents)) == expected_named, stem + " named count")
            require("All " + str(expected_total) + " tests passed." in contents, stem + " total count")

    for name, value in proof["after_probe_source"]["core_files_sha256"].items():
        require(after["source_sha256"][name] == value, "after source manifest " + name)
    freeze = load("followup-source-freeze.manifest.json")
    require(freeze["source_sha256"] == proof["final_test_source"]["files_sha256"], "final source freeze binding")
    if options.source_root:
        for name, expected in {
            **proof["after_probe_source"]["core_files_sha256"],
            **proof["final_test_source"]["files_sha256"],
        }.items():
            require(sha256(options.source_root / name) == expected, "current frozen source " + name)
    if options.external_root:
        for name, expected in external.items():
            path = options.external_root / name
            if expected["kind"] == "file":
                require(path.stat().st_size == expected["bytes"], "external size " + name)
                require(sha256(path) == expected["sha256"], "external SHA-256 " + name)
            else:
                count, value = tree_hash(path)
                require(count == expected["file_count"], "external file count " + name)
                require(value == expected["tree_sha256"], "external tree SHA-256 " + name)
        for name, expected in after["source_sha256"].items():
            require(sha256(options.external_root / "after-source" / name) == expected, "after source snapshot " + name)
    print("verified " + str(checked) + " byte/provenance checks; broader gate metadata remains owned by main")


if __name__ == "__main__":
    main()
