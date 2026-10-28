#!/usr/bin/env python3
"""Check frozen ordinary CPU samples and recompute global instruction shares."""

import hashlib
import json
import math
import tarfile
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    path = ROOT / "evidence.tar.xz"
    assert sha256(path.read_bytes()) == manifest["archive_sha256"]
    with tarfile.open(path) as archive:
        files = {m.name: archive.extractfile(m).read() for m in archive if m.isfile()}
    assert set(files) == set(manifest["archive_member_sha256"])
    for name, digest in manifest["archive_member_sha256"].items():
        assert sha256(files[name]) == digest, name
    assert json.loads(files["compile-terminal.json"])["exit_code"] == 0
    summary = json.loads(files["sample-summary.json"])
    assert summary == json.loads((ROOT / "result.json").read_text())
    recordings = json.loads(files["recordings.json"])
    for recording, item in zip(recordings, summary, strict=True):
        label = item["label"]
        assert recording["label"] == label and recording["exit_code"] == 0
        report = json.loads(files[label + ".stdout"])
        assert report == recording["report"]
        assert report["control_profile_null"] and report["diagnostic_profile_calls"] == 0
        assert report["all_wires_equal"] and report["native_decode_verified"]
        assert sha256(files[label + ".zst"]) == report["wire_sha256"]
        rows = [line.split(maxsplit=2) for line in files[label + ".ip-period.txt"].decode().splitlines()]
        rows = [(int(p), int(ip, 16), symbol) for p, ip, symbol in rows]
        total = sum(p for p, _, _ in rows)
        assert total == item["total_period"] and len(rows) == item["sample_count"]
        cpu_rows = files[label + ".cpu-ip-period.txt"].decode().splitlines()
        cpus = Counter(row.split()[0] for row in cpu_rows)
        assert cpus == item["sample_cpu_counts"] == {"[002]": len(rows)}
        for interval in item["address_ranges"].values():
            begin, end = int(interval["begin"], 16), int(interval["end_exclusive"], 16)
            selected = [p for p, ip, _ in rows if begin <= ip < end]
            assert len(selected) == interval["samples"]
            assert math.isclose(100 * sum(selected) / total, interval["global_pct"], abs_tol=1e-12)
        for hotspot in item["top10"]:
            period = sum(p for p, _, symbol in rows if symbol == hotspot["symbol"])
            assert math.isclose(100 * period / total, hotspot["global_pct"], abs_tol=1e-12)
    print(json.dumps({"valid_recordings": len(recordings), "samples_verified": sum(s["sample_count"] for s in summary), "global_period_shares_verified": True}, indent=2))


if __name__ == "__main__":
    main()
