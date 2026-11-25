#!/usr/bin/env python3
"""Recompute the frozen history audit without codecs, Git, or external files."""
import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import re
import statistics
import tarfile


ROOT = Path(__file__).resolve().parent


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_json(path):
    return json.loads((ROOT / path).read_bytes())


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def geometric_mean(values):
    return math.exp(statistics.mean(math.log(value) for value in values))


def per_call_median(rows, field):
    return statistics.median(
        sample[field] / row["iterations"]
        for row in rows
        for sample in row["rounds"]
    )


def one_row(report):
    require(len(report["rows"]) == 1, "expected exactly one corpus row")
    return report["rows"][0]


def check_brotli_rounds(row):
    require(row["input_bytes"] == 65536 and row["iterations"] == 3, "Brotli row scope changed")
    require(len(row["rounds"]) == 5, "Brotli measured round missing")
    for index, sample in enumerate(row["rounds"]):
        require(sample["index"] == index and sample["vort_first"] == (index % 2 == 0), "Brotli order changed")
        for side in ("vort", "reference"):
            require(sample[side + "_ns"] > 0, "nonpositive timing")
            require(sample[side + "_mix"] == row["wires"][side + "_bytes"] * row["iterations"], "Brotli mix mismatch")


def check_inputs(row, plain):
    require(row["input_bytes"] == len(plain), "input length mismatch")
    require(row["input_sha256"] == sha256(plain), "input SHA mismatch")


def check_reference_files(report):
    for reference in report["references"]:
        requested = reference["requested_path"]
        name = Path(requested).name
        actual = (ROOT / "references" / name).read_bytes()
        require(reference["file_sha256"] == sha256(actual), "reference file SHA mismatch")


def verify_brotli(cases):
    old_build = read_json("source/old-q8/build-bench-final.json")
    new_manifest = read_json("raw/new-checkpoint-manifest.json")
    legacy = {row["id"]: row for row in csv.DictReader(io.StringIO((ROOT / "raw/brotli/old-csv.csv").read_text()))}
    results = []
    old_timing, new_timing = None, None
    for case in cases:
        old_reports = [read_json(f"raw/brotli/old/{case}-sweep{sweep}.json") for sweep in range(3)]
        new_report = read_json(f"raw/brotli/new/{case}.json")
        old = [one_row(report) for report in old_reports]
        new = one_row(new_report)
        plain = (ROOT / "inputs" / (case + ".64k.plain")).read_bytes()
        for report, row in zip(old_reports + [new_report], old + [new]):
            require(report["codec"] == "brotli", "wrong codec")
            check_brotli_rounds(row)
            check_inputs(row, plain)
            check_reference_files(report)
            setting = row["settings"]
            require(setting["planned_quality"] == 8 and setting["reference_quality"] == 8, "quality changed")
            require(setting["vort_mode"] == "generic" and setting["reference_mode"] == 0, "mode changed")
            require(setting["vort_wire_window_bits"] == 16 and setting["reference_wire_window_bits"] == 16, "wire window changed")
            require(setting["parameters_match"] is True and setting["vort_hq_enabled"] is False, "primary mode changed")
            require(setting["vort_command_state_max_input_kib"] == 255, "quality sentinel changed")
        require(all(report["provenance"]["executable_sha256"] == old_build["binary_sha256"] for report in old_reports), "old measured binary/source binding differs")
        require(new_report["provenance"]["executable_sha256"] == new_manifest["probes"]["brotli"]["sha256"], "new measured binary label differs")
        for row in old:
            require(row["wires"] == old[0]["wires"], "old sweep wire changed")
            require(row["settings"]["vort_window_bits"] is None, "old window request changed")
        require(new["settings"]["vort_window_bits"] == 16, "new explicit window changed")
        require(old[0]["wires"]["reference_sha256"] == new["wires"]["reference_sha256"], "reference wire changed")
        require(old[0]["wires"]["reference_bytes"] == new["wires"]["reference_bytes"], "reference wire length changed")
        require(all(report["provenance"]["cpu_affinity"] == "2" for report in old_reports), "old CPU changed")
        require(new_report["provenance"]["cpu_affinity"] == "15", "new CPU changed")
        old_vort = per_call_median(old, "vort_ns")
        old_reference = per_call_median(old, "reference_ns")
        new_vort = per_call_median([new], "vort_ns")
        new_reference = per_call_median([new], "reference_ns")
        legacy_vort = statistics.median(per_call_median([row], "vort_ns") for row in old)
        require(math.isclose(legacy_vort, float(legacy[case + "-65536"]["candidate_ns"]), rel_tol=1e-14), "legacy CSV median does not rederive")
        old_timing = old_reports[0]["timing"]
        new_timing = new_report["timing"]
        results.append({
            "case": case,
            "input_bytes": len(plain),
            "input_sha256": sha256(plain),
            "old_vort_ns_per_call": old_vort,
            "new_vort_ns_per_call": new_vort,
            "old_reference_ns_per_call": old_reference,
            "new_reference_ns_per_call": new_reference,
            "old_legacy_csv_vort_ns_per_call": legacy_vort,
            "new_over_old_vort_time": new_vort / old_vort,
            "new_over_legacy_csv_vort_time": new_vort / legacy_vort,
            "old_vort_over_reference_time": old_vort / old_reference,
            "new_vort_over_reference_time": new_vort / new_reference,
            "old_vort_bytes": old[0]["wires"]["vort_bytes"],
            "new_vort_bytes": new["wires"]["vort_bytes"],
            "old_vort_sha256": old[0]["wires"]["vort_sha256"],
            "new_vort_sha256": new["wires"]["vort_sha256"],
            "reference_bytes": new["wires"]["reference_bytes"],
            "reference_wire_sha256": new["wires"]["reference_sha256"],
        })
    return {
        "rows": results,
        "geomean_new_over_old_vort_time": geometric_mean([row["new_over_old_vort_time"] for row in results]),
        "geomean_new_over_legacy_csv_vort_time": geometric_mean([row["new_over_legacy_csv_vort_time"] for row in results]),
        "geomean_old_vort_over_reference_time": geometric_mean([row["old_vort_over_reference_time"] for row in results]),
        "geomean_new_vort_over_reference_time": geometric_mean([row["new_vort_over_reference_time"] for row in results]),
        "geomean_new_over_old_size": geometric_mean([row["new_vort_bytes"] / row["old_vort_bytes"] for row in results]),
        "old_raw_rounds_per_case": 15,
        "new_raw_rounds_per_case": 5,
        "all_input_and_reference_wire_sha_match": True,
        "old_window_request": None,
        "new_window_request": 16,
        "both_actual_wire_windows": 16,
        "old_cpu_affinity": "2",
        "new_cpu_affinity": "15",
        "old_timing_metadata": old_timing,
        "new_timing_metadata": new_timing,
        "causal_code_regression_established": False,
    }


def verify_deflate(cases):
    old = read_json("raw/deflate/old-live-comparison.json")
    require(old["cpu_affinity"] == "2", "old Deflate CPU changed")
    new_manifest = read_json("raw/new-checkpoint-manifest.json")
    rows = []
    permutations = {
        ("vort", "zlib", "libdeflate"), ("zlib", "libdeflate", "vort"),
        ("libdeflate", "vort", "zlib"), ("vort", "libdeflate", "zlib"),
        ("libdeflate", "zlib", "vort"), ("zlib", "vort", "libdeflate"),
    }
    for case in cases:
        new_report = read_json(f"raw/deflate/new/{case}.json")
        new = one_row(new_report)
        plain = (ROOT / "inputs" / (case + ".64k.plain")).read_bytes()
        check_inputs(new, plain)
        require(new["settings"]["vort_level"] == 9 and new["settings"]["libdeflate_level"] == 12, "Deflate levels changed")
        require(new_report["provenance"]["cpu_affinity"] == "15", "new Deflate CPU changed")
        require(new_report["provenance"]["executable_sha256"] == new_manifest["probes"]["deflate"]["sha256"], "new Deflate measured binary label differs")
        require(len(new["rounds"]) == 6 and len(new["warmup_rounds"]) == 6, "Deflate round missing")
        for rounds in (new["rounds"], new["warmup_rounds"]):
            require({tuple(round["order"]) for round in rounds} == permutations, "Deflate permutation missing")
            for index, sample in enumerate(rounds):
                require(sample["index"] == index, "Deflate chronology changed")
                for side in ("vort", "zlib", "libdeflate"):
                    require(sample[side + "_mix"] == new["wires"][side + "_bytes"] * new["iterations"], "Deflate mix mismatch")
        sides = {}
        for side, new_name in (("live9", "vort"), ("libdeflate12", "libdeflate")):
            records = [record for record in old["raw"] if record["case"] == case + "-65536" and record["side"] == side]
            require(len(records) == 3 and {record["sweep"] for record in records} == {0, 1, 2}, "old Deflate sweep missing")
            for record in records:
                require(record["input_sha256"] == sha256(plain), "old Deflate input SHA mismatch")
                require(record["wire_sha256"] == new["wires"][new_name + "_sha256"], "Deflate wire SHA mismatch")
                require(record["wire_bytes"] == new["wires"][new_name + "_bytes"], "Deflate wire length mismatch")
                require(record["exit_code"] == 0, "old Deflate process failed")
                matched = re.fullmatch(r"elapsed_ns=(\d+) frame_bytes=(\d+) zlib_bytes=(\d+) mix=(\d+)\s*", record["stdout"])
                require(matched is not None and int(matched[1]) == record["elapsed_ns"], "old Deflate raw stdout timing mismatch")
                require(int(matched[2]) == record["wire_bytes"] and int(matched[3]) == record["wire_bytes"], "old Deflate raw stdout wire length mismatch")
            sides[new_name] = statistics.median(record["elapsed_ns"] / record["iterations"] for record in records)
        new_vort = per_call_median([new], "vort_ns")
        rows.append({
            "case": case, "input_sha256": sha256(plain),
            "old_vort_ns_per_call": sides["vort"], "new_vort_ns_per_call": new_vort,
            "old_reference_ns_per_call": sides["libdeflate"],
            "new_reference_ns_per_call": per_call_median([new], "libdeflate_ns"),
            "new_over_old_vort_time": new_vort / sides["vort"],
            "vort_bytes": new["wires"]["vort_bytes"], "vort_sha256": new["wires"]["vort_sha256"],
            "reference_bytes": new["wires"]["libdeflate_bytes"], "reference_sha256": new["wires"]["libdeflate_sha256"],
        })
    return {"rows": rows, "geomean_new_over_old_vort_time": geometric_mean([row["new_over_old_vort_time"] for row in rows]),
            "all_input_and_both_wire_sha_match": True, "old_cpu_affinity": "2", "new_cpu_affinity": "15",
            "old_reference_version": "libdeflate 1.26 L12", "new_reference_version": "libdeflate 1.26 L12",
            "causal_code_speedup_established": False}


def verify_source():
    manifest = read_json("source/old-q8/source-final-sha256.json")
    binding = read_json("source/old-q8/git-bindings.json")
    build = read_json("source/old-q8/build-bench-final.json")
    require(build["source_sha256"] == manifest, "old build source differs from archive manifest")
    with tarfile.open(ROOT / "source/old-q8/source-final.tar.xz") as archive:
        files = [member for member in archive.getmembers() if member.isfile()]
        require({member.name for member in files} == set(manifest), "source archive file set mismatch")
        for member in files:
            data = archive.extractfile(member).read()
            require(sha256(data) == manifest[member.name], "archived source SHA mismatch")
            if member.name in binding["tracked_files"]:
                recorded = binding["tracked_files"][member.name]
                blob = b"blob " + str(len(data)).encode() + b"\0" + data
                require(hashlib.sha1(blob).hexdigest() == recorded["git_blob_sha1"], "archived Git blob mismatch")
        require(len(files) == 1807 and len(binding["tracked_files"]) == 1790, "source binding counts changed")
        require(all(path.startswith("tools/br/__pycache__/") for path in binding["untracked_archive_files"]), "untracked production source")
    return {"exact_old_codec_revision": binding["commit"], "archive_files": 1807, "git_matched_files": 1790,
            "untracked_python_cache_files": 17, "production_missing_or_mismatched_files": 0,
            "old_benchmark_sha256": build["binary_sha256"], "old_linked_record_object_sha256": build["record_o_sha256"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Write the recomputed JSON summary.")
    args = parser.parse_args()
    capture = read_json("capture.json")
    for file in capture["files"]:
        data = (ROOT / file["path"]).read_bytes()
        require(len(data) == file["bytes"] and sha256(data) == file["sha256"], "captured file changed: " + file["path"])
    if (ROOT / "SHA256SUMS").exists():
        for line in (ROOT / "SHA256SUMS").read_text().splitlines():
            digest, path = line.split("  ", 1)
            require(sha256((ROOT / path).read_bytes()) == digest, "bundle checksum mismatch: " + path)
    cases = capture["cases"]
    require(len(cases) == 12, "corpus row missing")
    new_manifest = read_json("raw/new-checkpoint-manifest.json")
    require(new_manifest["source"]["revision"] == capture["new_encoder_baseline_revision"], "new source label differs")
    result = {"schema": "vort.performance_history_audit", "version": 1,
              "statistic": "median_of_all_raw_elapsed_ns_divided_by_iterations_then_equal_row_geomean",
              "cross_epoch_causal_acceptance": False, "source_binding": verify_source(),
              "new_baseline_source_label": new_manifest["source"]["revision"],
              "new_baseline_environment": new_manifest["environment"],
              "new_baseline_manifest_complete": new_manifest["complete"],
              "brotli_q8_64k": verify_brotli(cases), "deflate_l9_64k": verify_deflate(cases)}
    serialized = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(serialized)
    else:
        require(read_json("summary.json") == result, "saved summary does not rederive")
    print(json.dumps({"verified_cases_per_codec": len(cases),
                      "brotli_cross_epoch_time": result["brotli_q8_64k"]["geomean_new_over_old_vort_time"],
                      "deflate_cross_epoch_time": result["deflate_l9_64k"]["geomean_new_over_old_vort_time"],
                      "causal_acceptance": False}, sort_keys=True))


if __name__ == "__main__":
    main()
