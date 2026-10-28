#!/usr/bin/env python3
"""Audit frozen benchmark evidence with its exact archived validator sources."""

import copy
import csv
import hashlib
import io
import json
import sys
import tarfile
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def archive_files(path):
    with tarfile.open(path) as archive:
        return {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}


def materialize(files, directory):
    for name, data in files.items():
        path = Path(name)
        assert not path.is_absolute() and ".." not in path.parts
        target = directory / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)


def validate_rowset(validate, report, frozen, csv_bytes, original, relocated, library):
    # Rewrite only paths for local identity reads; hashes and all settings stay
    # identical. The archived report itself is verified before this copy.
    manifest = copy.deepcopy(frozen)
    for key in ["input_sets", "dictionary_sets"]:
        for item in manifest.get(key, []):
            relative = Path(item["frozen_path"]).relative_to(original)
            item["frozen_path"] = str(relocated / relative)
    observed = copy.deepcopy(report)
    for reference in observed["references"]:
        assert sha256(library.read_bytes()) == reference["file_sha256"]
        reference["canonical_file_path"] = str(library)
    rows = list(csv.DictReader(io.StringIO(csv_bytes.decode())))
    return validate(observed, manifest, csv_rows=rows, require_explicit_references=True)


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    tool_path = ROOT / "tool-sources.tar.xz"
    assert sha256(tool_path.read_bytes()) == manifest["tool_archive_sha256"]
    tools = archive_files(tool_path)
    assert set(tools) == set(manifest["tool_source_sha256"])
    for name, digest in manifest["tool_source_sha256"].items():
        assert sha256(tools[name]) == digest
    with tempfile.TemporaryDirectory(prefix="vort-common-hq-audit-") as temporary:
        root = Path(temporary)
        materialize(tools, root / "sources")
        sys.dont_write_bytecode = True
        sys.path.insert(0, str(root / "sources/tools/codec_bench"))
        from sample_gate import validate
        archives = {}
        for name, entry in manifest["archives"].items():
            path = ROOT / name
            assert sha256(path.read_bytes()) == entry["sha256"]
            files = archive_files(path)
            assert set(files) == set(entry["member_sha256"])
            for member, digest in entry["member_sha256"].items():
                assert sha256(files[member]) == digest
            directory = root / name.removesuffix(".tar.xz")
            materialize(files, directory)
            archives[name] = (files, directory, Path(entry["original_directory"]))
        valid_rows = 0
        valid_rounds = 0
        for name in ["modern-functional.tar.xz", "system-functional.tar.xz"]:
            files, directory, original = archives[name]
            summary = json.loads(files["summary.json"])
            assert summary["status"] == "ok" and summary["rows"] == 22
            assert summary["cli_rejections"] == 25 and summary["evidence_rejections"] == 37
            assert summary["dictionary_evidence_rejections"] == 8
            library = directory / "alias-reference.so"
            rows = 0
            for path in files:
                if not path.endswith(".manifest.json"):
                    continue
                prefix = path.removesuffix(".manifest.json")
                checked = validate_rowset(validate, json.loads(files[prefix + ".json"]),
                    json.loads(files[path]), files[prefix + ".csv"], original, directory, library)
                rows += checked["rows"]
                valid_rounds += checked["rounds"]
            assert rows == 22
            valid_rows += rows
        files, directory, original = archives["real-corpus.tar.xz"]
        campaign = json.loads(files["campaign.json"])
        assert all(command["exit_code"] == 0 for command in campaign["commands"])
        library = archives["modern-functional.tar.xz"][1] / "alias-reference.so"
        assert sha256(library.read_bytes()) == manifest["reference_library"]["sha256"]
        rows = 0
        for config in campaign["config"]["configs"]:
            prefix = config["name"] + "/"
            report = json.loads(files[prefix + "results.json"])
            checked = validate_rowset(validate, report, json.loads(files[prefix + "manifest.json"]),
                files[prefix + "results.csv"], original, directory, library)
            rows += checked["rows"]
            valid_rounds += checked["rounds"]
            assert report["provenance"]["executable_sha256"] == manifest["real_epoch"]["binary_sha256"]
        summary_bytes = (ROOT / "real-summary.json").read_bytes()
        assert sha256(summary_bytes) == manifest["real_summary_sha256"]
        assert json.loads(summary_bytes) == campaign["rows"]
        for row in campaign["rows"]:
            assert row["time_over_reference"] == row["vort_median_ns"] / row["reference_median_ns"]
            assert row["size_over_reference"] == row["vort_bytes"] / row["reference_bytes"]
        assert rows == 14
        final = json.loads((ROOT / "current-validation.json").read_text())
        assert all(run["exit_code"] == 0 for run in final["runs"].values())
        overlay_path = ROOT / "final-tool-overlay.tar.xz"
        assert sha256(overlay_path.read_bytes()) == final["final_tool_overlay_sha256"]
        overlay = archive_files(overlay_path)
        for name, digest in final["overlay_source_sha256"].items():
            assert sha256(overlay[name]) == digest
        materialize(overlay, root / "sources")
        # Load the exact final validator, retaining the historical validation
        # already performed with its original source epoch above.
        for module in ["sample_gate", "zstd_common_parameters"]:
            sys.modules.pop(module, None)
        from sample_gate import validate as final_validate
        path = ROOT / "final-functional.tar.xz"
        assert sha256(path.read_bytes()) == final["final_functional_sha256"]
        files = archive_files(path)
        expected = {member: digest for entry in final["final_functional"].values()
                    for member, digest in entry["member_sha256"].items()}
        assert set(files) == set(expected)
        for name, digest in expected.items():
            assert sha256(files[name]) == digest
        final_directory = root / "final-functional"
        materialize(files, final_directory)
        final_rows = 0
        for role, entry in final["final_functional"].items():
            library = archives[("modern" if role == "modern" else "system") + "-functional.tar.xz"][1] / "alias-reference.so"
            directory = final_directory / role
            count = 0
            for name in files:
                if not name.startswith(role + "/") or not name.endswith(".manifest.json"):
                    continue
                prefix = name.removesuffix(".manifest.json")
                checked = validate_rowset(final_validate, json.loads(files[prefix + ".json"]),
                    json.loads(files[name]), files[prefix + ".csv"], Path(entry["original_directory"]), directory, library)
                count += checked["rows"]
            assert count == entry["summary"]["rows"] == 24
            final_rows += count
        print(json.dumps({"functional_rows_verified": valid_rows, "real_rows_verified": rows,
                          "raw_rounds_verified": valid_rounds, "final_functional_rows_verified": final_rows,
                          "archived_validator_used": True}, indent=2))


if __name__ == "__main__":
    main()
