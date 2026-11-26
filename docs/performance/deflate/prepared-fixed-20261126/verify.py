"""Pending entry point; never treats preflight or old focused exits as full green."""
import json
from pathlib import Path
import argparse
import sys

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parent


def verify_ready(root):
    # This branch is never entered while pending. Both reducers consume only
    # package dictionaries, and no original producer imports are evaluated.
    from package_io import load, read_packages, require
    import contract_replay
    import independent_statistics  # Root-owned pure independent implementation.
    import probe_contract
    import source_replay
    import statistics_replay
    import validation_replay
    packages, binding = read_packages(root)
    source, benchmark, validation = [packages[name] for name in ("sources.tar.gz", "benchmark.tar.gz", "validation.tar.gz")]
    manifest = load(benchmark, "manifest.json")
    source_result = source_replay.verify(source, benchmark, manifest)
    preflight_result = contract_replay.verify_preflight(benchmark, manifest)
    native_result = contract_replay.verify_latest_native_records(validation)
    wasi_result = contract_replay.verify_latest_wasi_receipt(validation)
    terminal, release = probe_contract.sampling_after_terminal(benchmark, validation)
    final_validation = validation_replay.verify(validation)
    records = contract_replay.verify_sampling_records(benchmark, manifest)
    expected = load(benchmark, "result.json")
    original = statistics_replay.replay(benchmark["campaign.py"], manifest, benchmark["samples/raw.jsonl"], load(benchmark, "preflight.json"), expected)
    independent = independent_statistics.verify(manifest, records, expected, preflight_result["exact_three_side_rows"] == 33)
    failures = [row for row in expected["rows"] if not row["floor_pass"]]
    require(len(failures) == 14 and {row["row"] for row in failures if row["family"] == "prepared"} == {"mozilla.256", "nci.256"} and
            len([row for row in failures if row["family"] == "legacy"]) == 12 and not original["accepted"] and not independent["accepted"],
            "Preserved rejected performance floors differ")
    sample_exit = load(benchmark, "sample-exit.json")
    from package_io import sha
    require(sample_exit["returncode"] == 0 and sample_exit["raw_records"] == 540 and sample_exit["no_retries"] and
            sample_exit["no_outlier_filtering"] and sha(benchmark["sample.stdout"]) == sample_exit["stdout_sha256"] and
            sha(benchmark["sample.stderr"]) == sample_exit["stderr_sha256"], "Actual sample terminal/output differs")
    result = {"schema": "vort.deflate.prepared-fixed.archive-summary.v1", "decision": "rejected-performance-floor", "merge_allowed": False,
              "pack_readiness": True, "evidence_integrity_pass": True, "failed_floor_rows": failures,
              "source": source_result, "preflight": preflight_result, "native": native_result, "wasi": wasi_result,
              "final_validation": final_validation,
              "actual_final_full_terminal": terminal, "sampling_release": release, "producer_math": original,
              "independent_math": independent, "raw_records": len(records), "actual_sampling_terminal": sample_exit,
              "scope": "Package data only; final full/native modes separate; allocation/zeroheap evidence independent of timing and native RSS"}
    return result


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def inventory(root):
    from package_io import sha
    records = {path.name: {"bytes": path.stat().st_size, "sha256": sha(path.read_bytes())} for path in sorted(root.iterdir())
               if path.is_file() and path.name not in ("inventory.json", "SHA256SUMS")}
    value = encoded({"schema": "vort.deflate.prepared-fixed.inventory.v1", "files": records})
    sums = "".join(record["sha256"] + "  " + name + "\n" for name, record in records.items()) + sha(value) + "  inventory.json\n"
    return value, sums.encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--write-derived", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    state = json.loads((root / "release-state.json").read_bytes())
    if not state["heavy0_confirmed"] or state["final_full_exit_code"] is None:
        print(json.dumps({"status": "pending", "final_full": "not yet terminal-verified", "actual_samples": 0,
                          "formal_acceptance": None, "merge_allowed": None, "archive_execution_enabled": False}, sort_keys=True))
        return 2
    if state["final_full_exit_code"] != 0 or state["sampling_exit_code"] is None:
        print(json.dumps({"status": "pending-final-terminal-or-samples", "formal_acceptance": None}, sort_keys=True))
        return 2
    result = verify_ready(root)
    from package_io import require
    bindings = json.loads((root / "archive-bindings.json").read_bytes())
    receipt = {"schema": "vort.deflate.prepared-fixed.archive-receipt.v1", "verification_passed": True,
               "decision": result["decision"], "merge_allowed": False, "pack_readiness": True, "raw_records": 540,
               "rows": 45, "target_rows": 24, "pairs_per_row": 6, "negative_floor_rows": 14,
               "producer_accepted": False, "independent_accepted": False, "source_files": 2214,
               "preflight_wire_bytes_verified": 99, "public_decode_records_verified": 198, "C_decode_records_verified": 99,
               "archives": bindings["archives"], "members": sum(len(data) for data in bindings["members"].values()),
               "scope": "Package-only exact source/ELF/byte-wire/reference/chronology/terminal and two independent statistical implementations; no codec/SO/producer argv/original tmp execution"}
    derived = {"summary.json": encoded(result), "verification-receipt.json": encoded(receipt)}
    if args.write_derived:
        for name, data in derived.items():
            (root / name).write_bytes(data)
        value, sums = inventory(root)
        (root / "inventory.json").write_bytes(value)
        (root / "SHA256SUMS").write_bytes(sums)
    else:
        for name, data in derived.items():
            require((root / name).read_bytes() == data, "Derived verified result differs: " + name)
        value, sums = inventory(root)
        require((root / "inventory.json").read_bytes() == value and (root / "SHA256SUMS").read_bytes() == sums, "Final publication inventory differs")
    print(json.dumps({"status": "verified", "raw_records": result["raw_records"],
                      "accepted": result["producer_math"]["accepted"], "independent_math": result["independent_math"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
