"""Bind each routed-distance audit and timing result to the frozen experiment."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

from check_route import MARKER, OUTLIERS, ROWS, TARGET
from evidence import require


BASE_REVISION = "261bbba0097d1e10f68f0e48cc26a47793e43bd8"


def read_json(path):
    return json.loads(path.read_text())


def verify(package, extracted):
    manifests = {}
    for name in ("candidate", "layout"):
        capture = extracted / (name + "-raw")
        m = manifests[name] = read_json(capture / "manifest.json")
        require(m["base_revision"] == BASE_REVISION, "Unexpected mainline base")
        patch = gzip.decompress((package / (name + ".patch.gz")).read_bytes())
        require(m["candidate_patch_sha256"] == hashlib.sha256(patch).hexdigest(), "Patch does not bind the timing run")
        require(read_json(package / (name + "-summary.json")) == read_json(capture / "summary.json"), "Summary copy disagrees with raw archive")
    left, right = manifests.values()
    for field in ("tasks", "config", "references", "frozen_manifest_sha256"):
        require(left[field] == right[field], f"The comparison epochs use different {field}")
    require(left["probes"]["baseline"]["sha256"] == right["probes"]["baseline"]["sha256"], "Wrong baseline")
    require(left["probes"]["candidate"]["sha256"] != right["probes"]["candidate"]["sha256"], "Placement control is not distinct")
    by_key = {task["fixture"]["key"]: task["fixture"] for task in left["tasks"]}
    audits = (("route", "route-counts.json", ROWS), ("outliers", "outlier-counts.json", OUTLIERS))
    for folder, report_file, rows in audits:
        counts = read_json(package / report_file)
        require(set(counts) == set(rows), "Unexpected debug audit rows")
        for i, key in enumerate(rows):
            log = (extracted / folder / f"{i}.stdout").read_text()
            require(sum(line == MARKER for line in log.splitlines()) == counts[key], "Debugger route report drift")
            require(counts[key] == (8 if key == TARGET else 0), "Unexpected routed meta-block count")
            report, _ = json.JSONDecoder().raw_decode(log[log.index("\n{\n") + 1:])
            fixture = by_key[key]
            require(report["iterations"] == 1 and report["rounds"] == 2 and report["warmup"] == 0, "Unexpected diagnostic execution scope")
            require(report["provenance"]["executable_sha256"] == left["probes"]["candidate"]["sha256"], "Used a different diagnostic executable")
            for key_hash in ("input_sha256", "encoded_sha256"):
                require(report[key_hash] == fixture[key_hash], "Diagnostic fixture mismatch")
            for check in ("full_output_per_batch", "guards_per_batch", "input_unchanged_per_batch"):
                require(report["validation"][check] is True, f"Missing diagnostic {check}")
    wasm = read_json(package / "wasm-tests.json")
    require(wasm["status"] == "ok" and wasm["exit_code"] == 0, "Failed WASI contract receipt")
    print("Verified both source patches, frozen epochs, debugger route audit, and WASI receipt")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("extracted", type=Path)
    opts = parser.parse_args()
    verify(opts.package, opts.extracted)
