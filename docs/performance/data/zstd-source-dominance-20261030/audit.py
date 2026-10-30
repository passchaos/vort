#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import math
import statistics
import tarfile
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent
BASELINE = "88eebd7f211674c820a4c94e82b2da6a2d7930fc"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def geomean(values: list[float]) -> float:
    return math.exp(statistics.mean(map(math.log, values)))


def checksums() -> int:
    entries = 0
    for line in (ROOT / "SHA256SUMS").read_text().splitlines():
        digest, name = line.split("  ", 1)
        assert sha256(ROOT / name) == digest
        entries += 1
    assert entries >= 10
    return entries


def sources() -> dict:
    manifest = json.loads((ROOT / "source-manifest.json").read_text())
    assert manifest["baseline_commit"] == BASELINE
    assert sha256(ROOT / "inputs.tar.xz") == manifest["inputs_sha256"]
    assert sha256(ROOT / "source-overlay.tar.xz") == manifest["source_overlay_sha256"]
    with tempfile.TemporaryDirectory(prefix="vort-zstd-dominance-source-") as temp:
        source_root = Path(temp)
        with tarfile.open(ROOT / "source-overlay.tar.xz") as archive:
            archive.extractall(source_root, filter="data")
        for name, digest in manifest["sources"].items():
            assert sha256(source_root / name) == digest
    return {"baseline": BASELINE, "files": len(manifest["sources"])}


def performance() -> dict:
    report = json.loads((ROOT / "comparison.json").read_text())
    assert report["sweeps"] == 8 and report["all_wire_settings_equal"]
    assert len(report["rows"]) == 10
    for row in report["rows"]:
        assert row["samples_per_side"] == 16
        assert abs(row["candidate_ns"] / row["baseline_ns"] - row["ratio"]) < 1e-12
        assert row["baseline_profile"]["peak_working_memory"] == \
            row["candidate_profile"]["peak_working_memory"]
        if "control" in row["config"]:
            assert row["baseline_profile"] == row["candidate_profile"]
        elif row["case"].startswith("dickens"):
            assert row["baseline_profile"]["price_evaluations"] == \
                row["candidate_profile"]["price_evaluations"]
        else:
            assert row["candidate_profile"]["price_evaluations"] < \
                row["baseline_profile"]["price_evaluations"]

    for name, summary in report["summary"].items():
        rows = [row for row in report["rows"] if row["config"] == name]
        assert abs(geomean([row["ratio"] for row in rows]) - summary["geomean"]) < 1e-12
        assert abs(max(row["ratio"] for row in rows) - summary["maximum"]) < 1e-12
    assert report["summary"]["4k-btultra2"]["geomean"] <= 0.97
    assert report["summary"]["16k-btultra2"]["geomean"] <= 1.0
    assert report["summary"]["4k-btultra2"]["maximum"] <= 1.01
    assert report["summary"]["16k-btultra2"]["maximum"] <= 1.01
    assert 0.98 <= report["summary"]["4k-btopt-control"]["geomean"] <= 1.02
    assert 0.98 <= report["summary"]["trained-control"]["geomean"] <= 1.02
    return report["summary"]


def differential() -> dict:
    report = json.loads((ROOT / "hq-search-report.json").read_text())
    assert report["status"] == "ok"
    assert len(report["rows"]) == 41
    assert report["baseline_rows"] == 8
    assert report["source_before_after_equal"]
    return {"rows": 41, "baseline_rows": 8}


def main() -> int:
    result = {
        "status": "ok",
        "checksum_entries": checksums(),
        "sources": sources(),
        "performance": performance(),
        "differential": differential(),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
