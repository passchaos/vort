#!/usr/bin/env python3
"""Verify the complete frozen diagnostic without executing a codec."""
import gzip
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tarfile
import tempfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify(package):
    sums = {}
    for line in (package / "SHA256SUMS").read_text().splitlines():
        sha, name = line.split("  ", 1)
        assert name not in sums and Path(name).name == name
        sums[name] = sha
        assert digest((package / name).read_bytes()) == sha, name
    actual = {p.name for p in package.iterdir() if p.is_file() and p.name != "SHA256SUMS"}
    assert actual == set(sums), (actual, set(sums))
    bindings = json.loads((package / "archive-bindings.json").read_text())
    archive = package / "raw.tar.gz"
    assert digest(archive.read_bytes()) == bindings["archive_sha256"]
    with tempfile.TemporaryDirectory(prefix="vort-histogram-replay-") as directory:
        root = Path(directory)
        with tarfile.open(archive, "r:gz") as stream:
            members = stream.getmembers()
            assert len(members) == len(bindings["members"])
            assert {m.name for m in members} == set(bindings["members"])
            for member in members:
                name = PurePosixPath(member.name)
                assert member.isfile() and not name.is_absolute() and ".." not in name.parts
                data = stream.extractfile(member).read()
                expected = bindings["members"][member.name]
                assert len(data) == expected["bytes"] and digest(data) == expected["sha256"], member.name
                path = root / member.name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
        source = json.loads((root / "source-git-bindings.json").read_text())
        assert source["base_revision"] == "7bb7ee116c93be1850133be8727bbce9856519ad"
        classes = {"matching": [], "modified": [], "new": []}
        for record in source["records"]:
            data = (root / "source" / record["path"]).read_bytes()
            blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
            assert blob == record["frozen_git_blob"]
            assert digest(data) == record["sha256"] and len(data) == record["bytes"]
            classification = record["classification"]
            if classification == "matching":
                assert blob == record["base_git_blob"]
            elif classification == "modified":
                assert record["base_git_blob"] is not None and blob != record["base_git_blob"]
            else:
                assert classification == "new" and record["base_git_blob"] is None
            classes[classification].append(record["path"])
        assert len(classes["matching"]) == source["matching_files"] == 2191
        assert classes["modified"] == source["modified_files"]
        assert classes["new"] == source["new_files"]
        assert len(classes["modified"]) == 4 and len(classes["new"]) == 2
        elf = gzip.decompress((root / "bin/profile.gz").read_bytes())
        capture = json.loads((root / "profile/histograms.json").read_text())
        receipt = json.loads((root / "profile/run.command.json").read_text())
        assert digest(elf) == receipt["executable_sha256"] == capture["provenance"]["executable_sha256"]
        wire_rows = json.loads((root / "wire-bindings.json").read_text())["rows"]
        wire_map = {r["input_sha256"]: r for r in wire_rows}
        assert len(wire_map) == len(capture["rows"]) == 12
        for row in capture["rows"]:
            reference = wire_map[row["input_sha256"]]
            assert reference["wire_sha256"] == row["wire_sha256"]
            assert reference["wire_bytes"] == row["wire_bytes"]
        for name in ("source-identity-before.json", "source-identity-after.json"):
            assert (root / "first-capture" / name).is_file()
        first_before = json.loads((root / "first-capture/source-identity-before.json").read_text())
        first_after = json.loads((root / "first-capture/source-identity-after.json").read_text())
        assert first_before == first_after
        first = json.loads((root / "first-capture/profile/histograms.json").read_text())
        assert len(first["rows"]) == 12
        for old, new in zip(first["rows"], capture["rows"]):
            assert old["input_sha256"] == new["input_sha256"]
            assert old["wire_sha256"] == new["wire_sha256"]
            old_records = old["rounds"][0]["histograms"]["records"]
            new_records = new["rounds"][0]["histograms"]["records"]
            assert len(old_records) == len(new_records)
            for prior, current in zip(old_records, new_records):
                assert prior["canonical_domain_sha256"] == current["canonical_domain_sha256"]
                assert prior["proposals"] == current["proposals"]
        result = subprocess.run([sys.executable, str(package / "verify_capture.py"),
                                 "--root", str(root), "--expected-summary", str(package / "summary.json")],
                                check=True, capture_output=True, text=True)
        summary = json.loads(result.stdout)
        return {"verified": True, "archive_sha256": bindings["archive_sha256"],
                "source_files": len(source["records"]), "summary_sha256": sums["summary.json"],
                "diagnostic_only": True, "independent_summary": summary}


if __name__ == "__main__":
    print(json.dumps(verify(Path(__file__).resolve().parent), indent=2, sort_keys=True))
