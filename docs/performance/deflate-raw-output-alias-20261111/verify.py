#!/usr/bin/env python3
"""Verify frozen Raw Deflate alias evidence without running codec probes."""
import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import statistics
import subprocess
import tarfile
import zlib

FIX = "f74ca1fefd26b35936af94a719ae6bdd9c2c7494"
BASE = "6618b0c5833bf48dcc1a3cb99b9cec238f9e67b1"
PROBE = "7e4998d3f19065a1a5b422919b70c64b7c9aa3473ec351263cac696dab8ca6cc"
OVERVIEW = "deflate-raw-output-alias-20261111.md"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def compressed(path):
    data = path.read_bytes()
    require(data[:4] == b"\x1f\x8b\x08\x00" and data[4:8] == bytes(4), "Gzip header must have zero timestamp and no filename")
    return gzip.decompress(data)


def archive(path):
    files = {}
    with tarfile.open(fileobj=io.BytesIO(compressed(path)), mode="r:") as tar:
        members = tar.getmembers()
        require([m.name for m in members] == sorted({m.name for m in members}), "Unsorted/duplicate tar members")
        for member in members:
            require(member.isfile() and not member.name.startswith("/") and ".." not in Path(member.name).parts, "Unsafe archive member")
            require(member.uid == member.gid == member.mtime == 0 and member.uname == member.gname == "", "Nonzero archive metadata")
            require(member.mode in (0o644, 0o755), "Unexpected archive mode")
            files[member.name] = tar.extractfile(member).read()
    return files


def verify(root, live_root=None, raw_root=None, fixture_root=None):
    overview = root.parent / OVERVIEW
    checksum_path = root / "SHA256SUMS"
    if checksum_path.exists():
        checksums = {}
        for line in checksum_path.read_text().splitlines():
            digest, name = line.split("  ", 1)
            require(name not in checksums, "Duplicate package checksum")
            checksums[name] = digest
        actual = {p.name for p in root.iterdir() if p.is_file() and p != checksum_path}
        actual.add("../" + OVERVIEW)
        require(set(checksums) == actual, "Package checksum inventory differs")
        for name, digest in checksums.items():
            require(sha((root / name).read_bytes()) == digest, "Package checksum differs: " + name)
    binding = json.loads((root / "archive-bindings.json").read_text())
    summary = json.loads((root / "smoke-summary.json").read_text())
    gates = json.loads((root / "gate-summary.json").read_text())
    require(binding["fix_commit"] == FIX and binding["base_commit"] == BASE, "Unexpected repair commits")
    require(binding["source_sha256"] == summary["source_sha256"] and len(binding["source_sha256"]) == 5, "Source/smoke binding differs")
    archives = {}
    live_raw_files = 0
    for name, record in binding["archives"].items():
        files = archive(root / name)
        require({path: sha(data) for path, data in files.items()} == record["files"], "Exact archived bytes differ: " + name)
        archives[name] = files
        if raw_root and record["origin"] == "raw-root":
            for path, data in files.items():
                require((raw_root / path).read_bytes() == data, "Original evidence differs: " + path)
                live_raw_files += 1
    source = archives["source-overlay.tar.gz"]
    require({name: sha(data) for name, data in source.items()} == summary["source_sha256"], "Source overlay differs")
    binaries = archives["executables.tar.gz"]
    require(set(binaries) == {"final-probe", "alias.wasm"}, "Executable inventory differs")
    require(sha(binaries["final-probe"]) == summary["probe_sha256"] == PROBE, "Final probe differs")
    raw = archives["raw-evidence.tar.gz"]
    before_hash = raw["before-source.sha256"].decode().split()[0]
    require(before_hash == binding["before_deflate_sha256"], "Before source hash differs")
    expected = {"dictionary": (6, 17, "Xabcdefghijklmnop"), "stored": (9, 4, "abcd"),
                "future-auto": (16, 6, "abcdef"), "future-stored": (16, 6, "abcdef")}
    initial = {"dictionary": (b"abcdefghijklmnop" + b"\x55" * 16).hex(),
               "stored": "010400fbff61626364", "future-auto": "000300fcff616263010300fcff646566555555",
               "future-stored": "000300fcff616263010300fcff646566555555"}
    for mode in ("safe", "fast"):
        for case, (consumed, written, output) in expected.items():
            independent = f"independent consumed={consumed} written={written} output={output}\n"
            before = raw[f"before-{mode}-{case}.log"].decode()
            after = raw[f"after-{mode}-{case}.log"].decode()
            require(binding["before_probe_exit_codes"][f"{mode}/{case}"] ==
                    (134 if mode == "safe" and case in ("dictionary", "stored") else 0), "Recorded before exit differs")
            require(binding["after_probe_exit_codes"][f"{mode}/{case}"] == 0, "Recorded after exit differs")
            require(before.startswith(independent), "Before independent control differs")
            require(after == independent + f"alias error=InvalidBlockPlan backing={initial[case]}\n", "After rejection/storage differs")
            if mode == "safe" and case in ("dictionary", "stored"):
                require("panic: @memcpy arguments alias" in before, "Before panic absent")
            else:
                corrupted = {"dictionary": "Xaacdeeghhikllnop", "stored": "dbcd"}.get(case, "abcabc")
                require("output=" + corrupted in before[len(independent):], "Before corruption absent")
    require(sum(binding["scenario_count_derivation"].values()) == 81, "Core rejection scenario count differs")
    for gate in gates["gates"]:
        require(gate["exit_code"] == 0 and gate["success_marker"].encode() in raw[gate["log"]], "Recorded gate success differs")
    require(len(gates["gates"]) == 9, "Incomplete gate receipt")
    wasm = json.loads((root / "wasm-receipt.json").read_text())
    require(wasm == json.loads(raw["wasm-run.log"]), "WASI stdout/receipt differs")
    require(wasm["ok"] is True and wasm["status"] == "ok" and wasm["aggregate_exit_code"] == 0, "WASI aggregate failed")
    require(wasm["artifact_count"] == 1 and len(wasm["artifacts"]) == 1, "WASI artifact count differs")
    artifact = wasm["artifacts"][0]
    require(artifact["execution_started"] is True and artifact["actual_exit_code"] == 0, "Actual WASI execution failed")
    require(artifact["wasm_sha256"] == sha(binaries["alias.wasm"]) and artifact["wasm_size"] == len(binaries["alias.wasm"]), "WASI artifact differs")
    require(binaries["alias.wasm"][:8] == b"\x00asm\x01\x00\x00\x00" and artifact["imports_valid"] is True, "Invalid WASI module/imports")
    require(all(entry["module"] == "wasi_snapshot_preview1" and entry["kind"] == "function" for entry in artifact["imports"]), "Unexpected WASI imports")
    require(artifact["stdout"] == {"size": 0, "sha256": sha(b"")}, "Unexpected WASI stdout")
    require(artifact["stderr"] == {"size": len(raw["contracts-safe.log"]), "sha256": sha(raw["contracts-safe.log"])}, "WASI focused test output differs")
    oracle = json.loads((root / "fixture-oracle.json").read_text())
    require(oracle["runtime"] == "1.2.11" and len(oracle["cases"]) == 5, "Independent fixture oracle differs")
    for case in oracle["cases"]:
        wire = bytes.fromhex(case["wire_hex"])
        dictionary = case["dictionary_hex"]
        decoder = zlib.decompressobj(wbits=-15, **({"zdict": bytes.fromhex(dictionary)} if dictionary else {}))
        output = decoder.decompress(wire) + decoder.flush()
        require(sha(wire) == case["wire_sha256"] and output == bytes.fromhex(case["output_hex"]), "Oracle wire/output differs")
        require(decoder.eof and not decoder.unconsumed_tail and len(output) == case["output_bytes"], "Oracle completion differs")
        require(len(wire) - len(decoder.unused_data) == case["consumed_bytes"], "Oracle consumption differs")
    manifest_bytes = compressed(root / "fixture-manifest.json.gz")
    require(sha(manifest_bytes) == summary["base_fixture_manifest_sha256"], "Frozen fixture manifest differs")
    manifest = json.loads(manifest_bytes)
    fixtures = {f["key"]: f for f in manifest["fixtures"] if f["codec"] == "deflate"}
    names = {"dickens", "mozilla", "mr", "nci", "ooffice", "osdb", "reymont", "samba", "sao", "webster", "xml", "x-ray"}
    require(set(fixtures) == {f"deflate/{name}/{size}/{level}" for name in names for size in ("65536", "1048576", "full") for level in (6, 9)}, "Incomplete smoke dimensions")
    require(summary["valid"] is True and summary["fixtures"] == 72 and summary["paired_batches"] == 144,
            "Incomplete smoke summary")
    require(summary["iterations"] == 1 and summary["warmup_pairs"] == 0 and len(summary["rows"]) == 72, "Unexpected smoke sampling")
    require(summary["reference"] == manifest["references"]["deflate"], "Smoke reference binding differs")
    rows = archives["smoke-rows.tar.gz"]
    require(set(rows) == {"smoke/" + item["row"][:-5] + suffix for item in summary["rows"]
                         for suffix in (".json", ".stderr.txt")}, "Raw smoke inventory differs")
    require({item["key"] for item in summary["rows"]} == set(fixtures), "Raw smoke keys differ")
    fixture_files = {}
    for item in summary["rows"]:
        fixture = fixtures[item["key"]]
        data = rows["smoke/" + item["row"]]
        stderr = rows["smoke/" + item["row"][:-5] + ".stderr.txt"]
        require(sha(data) == item["sha256"] and stderr == b"" and sha(stderr) == item["stderr_sha256"], "Raw smoke bytes/stderr differ")
        row = json.loads(data)
        require(row["schema"] == "vort.decode-compare.v1" and row["codec"] == "deflate", "Unexpected smoke schema/codec")
        require(row["lifecycle"] == "cold" and row["lifecycle_match"] == "matched-cold", "Smoke lifecycle differs")
        require(row["vort_api"] == "decodeRawDeflate" and row["reference_api"] ==
                "libdeflate_alloc_decompressor+libdeflate_deflate_decompress_ex+libdeflate_free_decompressor", "Smoke API differs")
        for field in ("input_path", "encoded_input_path", "input_bytes", "encoded_bytes", "input_sha256", "encoded_sha256"):
            require(row[field] == fixture[field], "Frozen fixture differs: " + field)
        reference = summary["reference"]
        require(row["reference_version"] == reference["version"] == "1.26" and row["reference_paths"] == [reference["path"]], "Smoke reference differs")
        mapped = {p for p in row["loaded_shared_library_paths"] if Path(p).name.startswith("libdeflate.so")}
        require(mapped == {reference["path"]} and row["reference_version_origin"] == "declared-pinned-header", "Mixed reference closure")
        require(row["exact_consumption"] == {"vort": True, "reference": True}, "Consumption coverage absent")
        require(row["alignment"] == {"guard_bytes": 64, "input_mod64": 0, "encoded_mod64": 0,
                                     "vort_output_mod64": 0, "reference_output_mod64": 0}, "Alignment/guard extent differs")
        require(row["validation"]["prepared_priming"] is False, "Unexpected prepared smoke lifecycle")
        require(all(row["validation"][field] is True for field in ("every_iteration_count", "full_output_per_batch", "guards_per_batch", "input_unchanged_per_batch", "exact_consumption_per_batch")), "Recorded validation absent")
        require(row["iterations"] == 1 and row["rounds"] == 2 and row["warmup"] == 0 and row["warmup_pairs"] == [], "Sampling scope differs")
        require(row["provenance"]["executable_sha256"] == PROBE and row["provenance"]["cpu_affinity"] == "15", "Probe/affinity differs")
        require(row["provenance"]["benchmark_threads"] == row["provenance"]["affinity_cpu_count"] == 1, "Thread policy differs")
        require(row["provenance"]["optimize"] == "ReleaseFast" and row["provenance"]["zig_version"] == "0.16.0" and
                row["provenance"]["target_cpu"] == "skylake+pku+sgx" and row["provenance"]["codec_thread_policy"] == "single", "Probe build policy differs")
        require(len(row["pairs"]) == 2, "Missing paired smoke batch")
        for index, pair in enumerate(row["pairs"]):
            require(pair["pair_id"] == index and pair["first"] == ("vort" if index == 0 else "reference"), "Pair order differs")
            require(pair["vort_mix"] == pair["reference_mix"] == fixture["input_bytes"] + fixture["input_first_byte"], "Output accounting differs")
            require(all(type(pair[side + "_ns"]) is int and pair[side + "_ns"] > 0 for side in ("vort", "reference")), "Invalid batch duration")
        for side in ("vort", "reference"):
            require(row["summary"][side + "_median_ns"] == statistics.median(pair[side + "_ns"] for pair in row["pairs"]), "Recorded median differs")
        if fixture_root:
            for path_field, hash_field in (("input_path", "input_sha256"), ("encoded_input_path", "encoded_sha256")):
                name = Path(fixture[path_field]).name
                if name not in fixture_files:
                    require(sha((fixture_root / name).read_bytes()) == fixture[hash_field], "Live frozen fixture differs")
                    fixture_files[name] = fixture[hash_field]
    live_sources = 0
    if live_root:
        for name, digest in summary["source_sha256"].items():
            data = (live_root / name).read_bytes()
            require(sha(data) == digest and data == subprocess.check_output(["git", "show", FIX + ":" + name], cwd=live_root), "Live/committed source differs")
            live_sources += 1
        require(sha(subprocess.check_output(["git", "show", BASE + ":src/deflate.zig"], cwd=live_root)) == before_hash, "Base source binding differs")
        for name, digest in summary["reference"]["file_sha256"].items():
            require(sha(Path(name).read_bytes()) == digest, "Live libdeflate differs")
    if raw_root:
        for name in ("fixture-oracle.json", "smoke-summary.json", "wasm-receipt.json"):
            require((root / name).read_bytes() == (raw_root / name).read_bytes(), "Exact readable evidence differs")
            live_raw_files += 1
    return {"schema": "vort.raw-output-alias-archive-validation.v1", "valid": True,
            "scope": "independent byte/contract/recorded-gate verification; no codec probe or benchmark rerun",
            "fix_commit": FIX, "base_commit": BASE, "source_overlay_files": len(source),
            "core_alias_rejection_scenarios": 81, "before_after_logs": 16, "recorded_gates": 9,
            "small_fixtures_reinflated": 5, "verification_zlib_runtime": zlib.ZLIB_RUNTIME_VERSION,
            "actual_recorded_wasi_exit_code": 0, "wasi_artifact_sha256": sha(binaries["alias.wasm"]),
            "smoke_rows": 72, "paired_batches": 144, "iterations": 1, "warmup_pairs": 0,
            "nonempty_smoke_stderr": 0, "probe_sha256": PROBE,
            "live_source_files_verified": live_sources, "live_raw_files_verified": live_raw_files,
            "live_frozen_files_verified": len(fixture_files), "performance_claim": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live-root", type=Path)
    parser.add_argument("--raw-root", type=Path)
    parser.add_argument("--fixture-root", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(Path(__file__).resolve().parent, args.live_root, args.raw_root, args.fixture_root), indent=2))


if __name__ == "__main__":
    main()
