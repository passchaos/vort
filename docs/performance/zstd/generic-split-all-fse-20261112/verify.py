#!/usr/bin/env python3
"""Verify frozen all-FSE screens and proof epochs without running a codec."""
import argparse
import gzip
import hashlib
import io
import json
import math
from pathlib import Path
import re
import statistics
import subprocess
import tarfile

REVISION = "093d5b9c2793e31a5c23c0913af66ef0c22a5ac5"


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_tar(path, normalize=True, links=False):
    data = path.read_bytes()
    if normalize:
        require(data[:4] == b"\x1f\x8b\x08\x00" and data[4:8] == bytes(4), "Gzip header differs")
    files, symlinks = {}, {}
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(data)), mode="r:") as archive:
        members = archive.getmembers()
        if normalize:
            require([m.name for m in members] == sorted({m.name for m in members}), "Archive order/names differ")
        for member in members:
            require(not member.name.startswith("/") and ".." not in Path(member.name).parts, "Unsafe archive path")
            if normalize:
                require(member.uid == member.gid == member.mtime == 0 and member.uname == member.gname == "", "Archive metadata differs")
            if links and member.issym():
                require("/" not in member.linkname and member.linkname != "..", "Unsafe SONAME link")
                symlinks[member.name] = member.linkname
            else:
                require(member.isfile(), "Unexpected archive member")
                files[member.name] = archive.extractfile(member).read()
    require(all(str(Path(name).parent / target) in files for name, target in symlinks.items()), "Dangling SONAME link")
    return files


def load(files, name):
    return json.loads(files[name])


def source_digest(hashes):
    return sha(json.dumps(hashes, sort_keys=True).encode())


def check_probe(probe, manifest, fixture, lifecycle, iterations, rounds=2):
    require(probe["schema"] == "vort.decode-compare.v1" and probe["codec"] == "zstd", "Wrong probe schema/codec")
    require(probe["lifecycle"] == lifecycle and probe["lifecycle_match"] == "matched-" + lifecycle, "Lifecycle differs")
    apis = {"cold": ("decodeFrameInto", "ZSTD_decompress"),
            "prepared": ("NativeFrameDecoder.decodeIntoSlice", "ZSTD_decompressDCtx;retained-DCtx")}
    require((probe["vort_api"], probe["reference_api"]) == apis[lifecycle], "API lifecycle differs")
    for field in ("input_path", "encoded_input_path", "input_bytes", "encoded_bytes", "input_sha256", "encoded_sha256"):
        require(probe[field] == fixture[field], "Fixture field differs: " + field)
    reference = manifest["references"]["zstd"]
    require(probe["reference_version"] == reference["version"] == "1.6.0" and probe["reference_version_origin"].startswith("queried-"), "Reference version differs")
    require(probe["reference_paths"] == [reference["path"]], "Reference path differs")
    mapped = {p for p in probe["loaded_shared_library_paths"] if Path(p).name.startswith("libzstd.so")}
    require(mapped == {reference["path"]}, "Mixed reference closure")
    require(probe["alignment"] == {"guard_bytes": 64, "input_mod64": 0, "encoded_mod64": 0,
                                   "vort_output_mod64": 0, "reference_output_mod64": 0}, "Alignment differs")
    require(probe["exact_consumption"] == {"vort": False, "reference": False}, "Unsupported consumption claim")
    validation = probe["validation"]
    require(all(validation[k] is True for k in ("every_iteration_count", "full_output_per_batch", "guards_per_batch", "input_unchanged_per_batch")), "Validation coverage missing")
    require(validation["exact_consumption_per_batch"] is False and validation["prepared_priming"] == (lifecycle == "prepared"), "Validation lifecycle differs")
    config, host = manifest["config"], manifest["environment"]
    expected = {"executable_sha256": manifest["probe_sha256"], "optimize": "ReleaseFast", "zig_version": "0.16.0",
                "target_arch": "x86_64", "target_os": "linux", "target_abi": "gnu", "target_cpu": config["target_cpu"],
                "cpu_model": host["cpu_model"], "cpu_affinity": "15", "benchmark_threads": 1,
                "affinity_cpu_count": 1, "codec_thread_policy": "single"}
    require(all(probe["provenance"][k] == v for k, v in expected.items()), "Probe provenance differs")
    require(probe["iterations"] == iterations and probe["rounds"] == rounds and probe["warmup"] == 2, "Actual runner override differs")
    for field, count, offset in (("warmup_pairs", 2, 0), ("pairs", rounds, 2)):
        require(len(probe[field]) == count, "Missing raw samples")
        for index, pair in enumerate(probe[field]):
            pair_id = offset + index
            require(pair["pair_id"] == pair_id and pair["first"] == ("vort" if pair_id % 2 == 0 else "reference"), "Sample order differs")
            require(pair["vort_mix"] == pair["reference_mix"] == iterations * (fixture["input_bytes"] + fixture["input_first_byte"]), "Output count/mix differs")
            require(all(type(pair[side + "_ns"]) is int and pair[side + "_ns"] > 0 for side in ("vort", "reference")), "Invalid batch duration")
    for side in ("vort", "reference"):
        require(probe["summary"][side + "_median_ns"] == statistics.median(p[side + "_ns"] for p in probe["pairs"]), "Median differs")


def verify(root, baseline_package, reference_archive, originals=False, git_repo=None):
    checksum = root / "SHA256SUMS"
    if checksum.exists():
        hashes = {}
        for line in checksum.read_text().splitlines():
            digest, name = line.split("  ", 1)
            require(name not in hashes and "/" not in name, "Invalid checksum name")
            hashes[name] = digest
        require(set(hashes) == {p.name for p in root.iterdir() if p.is_file() and p != checksum}, "Checksum inventory differs")
        require(all(sha((root / name).read_bytes()) == digest for name, digest in hashes.items()), "Package checksum differs")
    binding = json.loads((root / "archive-bindings.json").read_text())
    require(binding["baseline_revision"] == REVISION and binding["pending_proof_only_epoch"] is False, "Archive epoch incomplete or rebound")
    archives, original_files = {}, 0
    for name, record in binding["archives"].items():
        files = read_tar(root / name)
        require({p: sha(data) for p, data in files.items()} == record["files"], "Archived raw bytes differ: " + name)
        archives[name] = files
        if originals:
            for member, origin in record["origins"].items():
                require(Path(origin).read_bytes() == files[member], "Original retained bytes differ: " + origin)
                original_files += 1
    reuse = binding["reuse"]
    base_source_path = baseline_package / "shared-dispatch-source.tar.gz"
    base_binary_path = baseline_package / "probe-binaries.tar.gz"
    require(sha(base_source_path.read_bytes()) == reuse["source_archive_sha256"] and sha(base_binary_path.read_bytes()) == reuse["binary_archive_sha256"], "Reused baseline containers differ")
    require(sha(reference_archive.read_bytes()) == reuse["reference_archive_sha256"], "Reused reference container differs")
    baseline_source = {name.removeprefix(reuse["source_prefix"]): data for name, data in read_tar(base_source_path, normalize=False).items()}
    baseline_binary = read_tar(base_binary_path, normalize=False)[reuse["binary_member"]]
    require(sha(baseline_binary) == reuse["binary_sha256"], "Reused baseline probe differs")
    reference = read_tar(reference_archive, links=True)
    require(sha(reference[reuse["reference_member"]]) == reuse["reference_sha256"], "Reference binary differs")
    candidate_sources = archives["timing-source-overlays.tar.gz"]
    binaries = archives["candidate-binaries.tar.gz"]
    runners = archives["runners-logs.tar.gz"]
    dependencies = archives["runner-dependencies.tar.gz"]
    for name in ("matrix.py", "evidence.py", "fixtures.py"):
        require(dependencies["tools/decode/" + name] == baseline_source["tools/decode/" + name], "Imported runner dependency differs")
    require(b"import matrix" in dependencies["pilot.py"] and b"PRIOR = Path('/tmp/vort-decode-refresh-20261111.ea193be2/manifest.json')" in dependencies["pilot.py"], "Pilot dependency differs")
    require(load(dependencies, "pilot-prior-manifest.json")["schema"] == load(dependencies, "pilot-pairs-manifest.json")["schema"] == "vort.decode-matrix.v1", "Seed manifest schema differs")
    audit = json.loads((root / "independent-stats.json").read_text())
    require(audit == load(runners, "independent-stats.json") and sha(runners["independent-stats.json"]) == "7b62d3baed2b3ae3f9c3fc026dbf85cddd523d6e85de72dbc0e43d03e0f110a3", "Main independent audit differs")
    expected_keys = ["zstd_sao_" + size + "_3_" + life for size in ("65536", "1048576", "full") for life in ("cold", "prepared")]
    results, baseline_manifest, fixture_files = {}, None, {}
    measured_sources = {}
    for folder, phase in binding["timing_phases"].items():
        files = archives[folder + "-raw.tar.gz"]
        manifests = {role: load(files, folder + "/" + role + ".manifest.json") for role in ("baseline", "candidate")}
        for manifest in manifests.values():
            require(manifest["schema"] == "vort.decode-matrix.v1" and len(manifest["fixtures"]) == len(manifest["tasks"]) == 216, "Original full schema lost")
            require(manifest["source"]["revision"] == REVISION and source_digest(manifest["source"]["sha256"]) == manifest["source"]["digest"], "Frozen source epoch/digest differs")
            require(manifest["config"]["lifecycles"] == ["cold"] and manifest["config"]["iterations"] == {"65536": 100, "1048576": 20, "full": 1}, "Original retained manifest config changed")
        base, candidate = manifests["baseline"], manifests["candidate"]
        require({name: sha(data) for name, data in baseline_source.items()} == base["source"]["sha256"] and len(baseline_source) == 2062, "Reused baseline source registry differs")
        require(base["probe_sha256"] == reuse["binary_sha256"], "Baseline manifest probe differs")
        if baseline_manifest is None:
            baseline_manifest = base
        else:
            require(base == baseline_manifest, "Baseline metadata changed between screens")
        full_source = dict(baseline_source)
        prefix = phase["source_prefix"]
        overlay = {name.removeprefix(prefix): data for name, data in candidate_sources.items() if name.startswith(prefix)}
        full_source.update(overlay)
        require({name: sha(data) for name, data in full_source.items()} == candidate["source"]["sha256"] and len(full_source) == phase["registry_count"], "Exact timing overlay differs")
        require(sha(binaries[phase["binary"]]) == candidate["probe_sha256"], "Candidate timing probe differs")
        measured_sources[folder] = overlay
        events = load(files, folder + "/events.json")
        expected_order = [(key, pair, role) for key in expected_keys for pair in range(4)
                          for role in (("baseline", "candidate") if pair % 2 == 0 else ("candidate", "baseline"))]
        require(len(events) == 48 and [(e["key"], e["pair"], e["label"]) for e in events] == expected_order, "Screen schedule incomplete")
        require(audit["variants"][folder]["events_sha256"] == sha(files[folder + "/events.json"]), "Audited event bytes differ")
        fixture_map = {f["key"]: f for f in base["fixtures"]}
        compiler_observations = 0
        for event in events:
            stem = folder + "/" + event["key"] + "." + str(event["pair"]) + "." + event["label"]
            require(event == load(files, stem + ".json") and event["probe"] == load(files, stem + ".stdout.raw") and files[stem + ".stderr.raw"] == b"", "Complete raw event/stdout/stderr differs")
            size, lifecycle = event["key"].split("_")[-3], event["key"].split("_")[-1]
            fixture = fixture_map["zstd/sao/" + size + "/3"]
            iterations = 10 if size == "full" else 100
            check_probe(event["probe"], manifests[event["label"]], fixture, lifecycle, iterations)
            for key, digest in (("input_path", "input_sha256"), ("encoded_input_path", "encoded_sha256")):
                fixture_files[fixture[key]] = fixture[digest]
            compiler_observations += len(event["before"]["compilers"]) + len(event["after"]["compilers"])
        require(compiler_observations == audit["variants"][folder]["compiler_observation_count"] == 0, "Compiler observation differs")
        phase_results = {}
        for key in expected_keys:
            ratios = []
            for pair in range(4):
                reports = {e["label"]: e["probe"] for e in events if e["key"] == key and e["pair"] == pair}
                old = statistics.median(p["vort_ns"] for p in reports["baseline"]["pairs"])
                new = statistics.median(p["vort_ns"] for p in reports["candidate"]["pairs"])
                ratios.append(old / new)
            center = math.exp(statistics.mean(math.log(value) for value in ratios))
            saved = load(files, folder + "/" + key + ".summary.json")
            audited = audit["variants"][folder]["rows"][key]
            require(saved["speed_ratios"] == audited["speed_ratios"] == ratios and saved["geomean"] == audited["geomean"] == center, "Independent raw statistic differs")
            phase_results[key] = {"speed_ratios": ratios, "geomean": center}
        results[folder] = phase_results
    require(results == json.loads((root / "results.json").read_text())["variants"], "Readable result derivative differs")
    inline = load(runners, "inline-freeze.json")
    require(inline["source_sha256"] == {name: sha(data) for name, data in measured_sources["inline-screen"].items()}, "Inline freeze source differs")
    require(inline["binary_sha256"] == sha(binaries["inline-compare"]) and inline["safe_log_sha256"] == sha(runners["inline-safe.log"]) and inline["build_log_sha256"] == sha(runners["inline-build.log"]), "Inline freeze proof differs")
    for name in ("group-safe.log", "inline-safe.log"):
        require(b"5/5 steps succeeded; 13/13 tests passed" in runners[name], "Captured Safe proof differs")
    original_proof = archives["reader-v1-proof.tar.gz"]
    receipt = load(original_proof, "vort-zstd-generic-split-contracts-receipt.json")
    before = load(original_proof, "vort-zstd-generic-split-source-final-before.json")
    after = load(original_proof, "vort-zstd-generic-split-source-final-after.json")
    require(before == after and receipt["source_files_before_after_equal"] is True, "Original oracle source changed")
    oracle_source = dict(baseline_source)
    oracle_source.update({name.removeprefix("reader-v1-proof-source/"): data for name, data in original_proof.items() if name.startswith("reader-v1-proof-source/")})
    for name, record in before["files"].items():
        require(sha(oracle_source[name]) == record["sha256"] and len(oracle_source[name]) == record["bytes"], "Original proof source differs")
    require(oracle_source["src/zstd/sequence/generic_split.zig"] == measured_sources["screen"]["src/zstd/sequence/generic_split.zig"] and oracle_source["src/zstd.zig"] != measured_sources["screen"]["src/zstd.zig"], "Test wiring was rebound to timing epoch")
    for run in receipt["runs"]:
        data = original_proof[Path(run["raw_log"]).name]
        require(run["returncode"] == 0 and run["tests_passed"] == 13 and sha(data) == run["raw_log_sha256"] and b"All 13 tests passed." in data, "Original Debug/Safe log differs")
    proof = archives["guarded-proof-only.tar.gz"]
    guarded = load(proof, "guarded-proof-receipt.json")
    require(sha(proof["guarded-proof-receipt.json"]) == "f731250c6b801593c26662c705a9a6641efbf0ffc02cdf23fd904b6c54ae1140", "Guarded receipt differs")
    guarded_source = {name.removeprefix("guarded-proof-source/"): data for name, data in proof.items() if name.startswith("guarded-proof-source/")}
    private_before = {name.removeprefix("private-wide-before-source/"): data for name, data in proof.items() if name.startswith("private-wide-before-source/")}
    require({name: sha(data) for name, data in guarded_source.items()} == guarded["source_sha256"], "Proof-only guarded source differs")
    require(private_before["src/zstd/sequence/generic_split.zig"] == measured_sources["inline-screen"]["src/zstd/sequence/generic_split.zig"] and private_before["src/zstd/sequence/generic_split_tests.zig"] == guarded_source["src/zstd/sequence/generic_split_tests.zig"], "Private-wide reproduction source differs")
    require(guarded_source["src/zstd/sequence/generic_split.zig"] != measured_sources["inline-screen"]["src/zstd/sequence/generic_split.zig"], "Guarded code substituted for measured inline code")
    require(guarded["before_exit_code"] == 1 and sha(proof["private-wide-before-safe.log"]) == guarded["before_log_sha256"] and b"12/13 tests passed (1 crashed)" in proof["private-wide-before-safe.log"], "Original private-wide crash absent")
    for mode, record in guarded["after"].items():
        data = proof[Path(record["log"]).name]
        require(record["exit_code"] == 0 and record["tests_passed"] == 13 and sha(data) == record["log_sha256"] and b"13/13 tests passed" in data, "Guarded final proof differs")
    main_audit = load(proof, "inline-audit.json")
    transcript = load(proof, "inline-reviewer-transcript.json")
    require(sha(proof["inline-audit.json"]) == "9f52b41398ab92ac953326047a15b941361a10f0ce2493a682acca3e8ebdfb8c", "Main-authored audit differs")
    require(sha(proof["inline-reviewer-transcript.json"]) == "b13dc6c3108b84d4da7251395da3cf257f8ecda24bb86a725925d30a8b91589c", "Reviewer message transcript differs")
    for name in ("inline-audit.json", "inline-reviewer-transcript.json", "guarded-proof-receipt.json"):
        require((root / name).read_bytes() == proof[name], "Readable proof/audit copy differs")
    inline_hashes = {name: sha(data) for name, data in measured_sources["inline-screen"].items()}
    require(main_audit["timing_epoch"]["source_sha256"] == transcript["source_sha256"] == inline_hashes and main_audit["guarded_proof_epoch"]["source_sha256"] == guarded["source_sha256"], "Audit source epochs differ")
    profile = archives["sao-profile.tar.gz"]
    profile_manifest = load(profile, "manifest.json")
    manifest, task = profile_manifest["manifest"], profile_manifest["task"]
    require(manifest["source"] == baseline_manifest["source"] and manifest["probe_sha256"] == reuse["binary_sha256"], "Profile rebound to candidate/new HEAD")
    execution = load(profile, "execution.json")
    require(execution["argv"] == load(profile, "command.json") == profile_manifest["argv"] and execution["returncode"] == 0 and not execution["before"]["compilers"] and not execution["after"]["compilers"], "Perf execution receipt differs")
    check_probe(load(profile, "stdout.raw"), manifest, task["fixture"], "cold", 10, rounds=6)
    require(profile["sao-full-L3.data"][:8] == b"PERFILE2" and b"dwarf,65528" in json.dumps(execution["argv"]).encode(), "Perf capture policy differs")
    physical = profile["symbols-physical.txt"]
    require(b"Samples: 806" in physical and b"Event count (approx.): 7570719030" in physical and b"Total Lost Samples: 0" in physical and profile["report.stderr"] == b"", "Successful physical report differs")
    require(b"Samples:" not in profile["symbols.txt"], "Initial failed inline report included as complete report")
    require(binding["profile_scope"]["initial_inline_report_excluded"] is True and binding["profile_scope"]["public_root_denominator_complete"] is False, "Profile scope overstated")
    git_count = 0
    if git_repo:
        names = list(baseline_source)
        result = subprocess.run(["git", "cat-file", "--batch"], cwd=git_repo,
                                input="".join(REVISION + ":" + name + "\n" for name in names).encode(), capture_output=True, check=True)
        position = 0
        for name in names:
            end = result.stdout.index(b"\n", position); header = result.stdout[position:end].split()
            require(len(header) == 3 and header[1] == b"blob", "Missing 093d5b9c Git blob")
            size = int(header[2]); position = end + 1
            require(result.stdout[position:position + size] == baseline_source[name], "Frozen baseline Git blob differs")
            position += size + 1; git_count += 1
    if originals:
        for name, digest in fixture_files.items():
            require(sha(Path(name).read_bytes()) == digest, "Original selected fixture changed")
    return {"schema": "vort.zstd.generic-split-archive-validation.v1", "valid": True,
            "scope": "independent raw-byte/source reconstruction/median statistics/proof binding; no compiler, codec or perf rerun",
            "baseline_revision": REVISION, "baseline_source_files": 2062, "baseline_git_blobs_verified": git_count,
            "timing_phases": 3, "child_events_each": 48, "total_timing_child_events": 144,
            "measured_pairs_each": 96, "warmup_pairs_each": 96, "row_summaries_recomputed": 18,
            "individual_process_pair_ratios_recomputed": 72, "results": results,
            "original_raw_files_verified": original_files, "selected_fixture_files": len(fixture_files),
            "reference_binaries_verified": 1, "original_oracle_debug_safe_tests_each": 13,
            "group_and_inline_prior_safe_tests_each": 13, "guarded_proof_only_after_tests_each": 13,
            "guarded_before_exit_code": 1, "guarded_before_passed": 12, "guarded_before_crashed": 1,
            "proof_only_performance_measured": False, "group_branch_hit_counters_present": False,
            "successful_profile_report_samples": 806, "successful_profile_report_period": 7570719030,
            "initial_inline_report_excluded": True, "complete_public_root_denominator": False,
            "codec_heap_measurement": False, "complete_matrix_or_dedicated_host_acceptance": False,
            "adopted": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-package", type=Path)
    parser.add_argument("--reference-archive", type=Path)
    parser.add_argument("--originals", action="store_true")
    parser.add_argument("--git-repo", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    baseline = args.baseline_package or root.parents[1] / "br/decode-mozilla-distributions-20261112"
    reference = args.reference_archive or root.parents[1] / "modern-decode-current-20261111/reference-libraries.tar.gz"
    print(json.dumps(verify(root, baseline, reference, args.originals, args.git_repo), indent=2))


if __name__ == "__main__":
    main()
