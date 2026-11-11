#!/usr/bin/env python3
"""Standard-library offline raw/source/consumer/reference verifier."""
import argparse
import gzip
import hashlib
import io
import json
import math
from pathlib import Path
import statistics
import subprocess
import tarfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
EXPECTED = {"prefix": 1.0099839656880558, "refill": 0.9611664352386534}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unpack(path):
    data = path.read_bytes()
    require(data[:4] == b"\x1f\x8b\x08\x00" and data[4:8] == bytes(4), "Non-deterministic gzip header")
    files = {}
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(data)), mode="r:") as bundle:
        members = bundle.getmembers()
        require([member.name for member in members] == sorted({member.name for member in members}), "Unsorted/duplicate tar names")
        for member in members:
            require(member.isfile() and not member.name.startswith("/") and ".." not in Path(member.name).parts, "Unsafe archive member")
            require(member.uid == member.gid == member.mtime == 0 and member.uname == member.gname == "", "Tar metadata differs")
            require(member.mode in (0o644, 0o755), "Unexpected file mode")
            files[member.name] = bundle.extractfile(member).read()
    return files


def load(files, name):
    return json.loads(files[name])


def validate_probe(probe, fixture, manifest):
    require(probe["schema"] == "vort.decode-compare.v1" and probe["codec"] == "deflate", "Wrong probe schema/codec")
    require(probe["lifecycle"] == "cold" and probe["lifecycle_match"] == "matched-cold", "Wrong lifecycle")
    require(probe["vort_api"] == "decodeRawDeflate" and probe["reference_api"] == "libdeflate_alloc_decompressor+libdeflate_deflate_decompress_ex+libdeflate_free_decompressor", "Wrong public APIs")
    for field in ("input_path", "encoded_input_path", "input_bytes", "encoded_bytes", "input_sha256", "encoded_sha256"):
        require(probe[field] == fixture[field], "Fixture differs: " + field)
    reference = manifest["references"]["deflate"]
    require(probe["reference_paths"] == [reference["path"]] and probe["reference_version"] == reference["version"] == "1.26", "Reference path/version differs")
    require(probe["reference_version_origin"] == "declared-pinned-header" and probe["reference_abi"] == "opaque-libdeflate_decompressor;LIBDEFLATE_SUCCESS=0;decompress_ex", "Reference ABI/provenance differs")
    mapped = {path for path in probe["loaded_shared_library_paths"] if Path(path).name.startswith("libdeflate.so")}
    require(mapped == {reference["path"]}, "Reference closure differs")
    require(probe["alignment"] == {"guard_bytes": 64, "input_mod64": 0, "encoded_mod64": 0, "vort_output_mod64": 0, "reference_output_mod64": 0}, "Alignment differs")
    require(probe["exact_consumption"] == {"vort": True, "reference": True}, "Missing exact consumption")
    require(all(probe["validation"][field] for field in ("every_iteration_count", "full_output_per_batch", "guards_per_batch", "input_unchanged_per_batch", "exact_consumption_per_batch")), "Validation absent")
    require(probe["validation"]["prepared_priming"] is False, "Wrong priming scope")
    iterations = 500 if fixture["size"] == "65536" else 100
    require(probe["iterations"] == iterations and probe["rounds"] == probe["warmup"] == 2, "Effective selected-row settings differ")
    for field, start in (("warmup_pairs", 0), ("pairs", 2)):
        require(len(probe[field]) == 2, "Raw batches missing")
        for index, pair in enumerate(probe[field]):
            number = start + index
            require(pair["pair_id"] == number and pair["first"] == ("vort" if number % 2 == 0 else "reference"), "Batch order differs")
            require(pair["vort_mix"] == pair["reference_mix"] == iterations * (fixture["input_bytes"] + fixture["input_first_byte"]), "Output count/mix differs")
            require(all(type(pair[side + "_ns"]) is int and pair[side + "_ns"] > 0 for side in ("vort", "reference")), "Invalid duration")
    for side in ("vort", "reference"):
        require(statistics.median(pair[side + "_ns"] for pair in probe["pairs"]) == probe["summary"][side + "_median_ns"], "Summary excludes raw samples")
    expected = {"executable_sha256": manifest["probe_sha256"], "optimize": "ReleaseFast", "zig_version": "0.16.0", "target_arch": "x86_64", "target_os": "linux", "target_abi": "gnu", "target_cpu": "skylake+pku+sgx", "cpu_model": manifest["environment"]["cpu_model"], "cpu_affinity": "15", "affinity_cpu_count": 1, "benchmark_threads": 1, "codec_thread_policy": "single"}
    require(all(probe["provenance"][field] == value for field, value in expected.items()), "Probe provenance differs")


def verify(original=False, git_repo=None, fixtures=False):
    binding = json.loads((HERE / "archive-bindings.json").read_bytes())
    reuse = json.loads((HERE / "reuse.json").read_bytes())
    prior = REPO / reuse["prior_package"]
    require(sha((prior / "archive-bindings.json").read_bytes()) == reuse["prior_binding_sha256"], "Prior source/binary binding changed")
    old = {}
    for name, digest in reuse["archives"].items():
        require(sha((prior / name).read_bytes()) == digest, "Reused archive changed")
        old[name] = unpack(prior / name)
    base = {name.removeprefix(reuse["source_prefix"]): data for name, data in old["shared-dispatch-source.tar.gz"].items()}
    baseline_binary = old["probe-binaries.tar.gz"][reuse["baseline_binary_member"]]
    archives = {}
    for name, record in binding["archives"].items():
        require(sha((HERE / name).read_bytes()) == record["sha256"], "Archive hash differs")
        files = unpack(HERE / name)
        require({path: sha(data) for path, data in files.items()} == record["member_sha256"], "Member hash differs")
        require({path: len(data) for path, data in files.items()} == record["member_bytes"], "Member length differs")
        if original:
            require(all(Path(record["origins"][path]).read_bytes() == data for path, data in files.items()), "Original byte copy differs")
        archives[name] = files
    rows, proofs = archives["screens-raw.tar.gz"], archives["runners-validation.tar.gz"]
    result, selected_fixtures = {}, {}
    for label in ("prefix", "refill"):
        source = archives[label + "-source-probe.tar.gz"]
        overlays = {name.removeprefix(label + "/source/"): data for name, data in source.items() if name.startswith(label + "/source/")}
        require(len(overlays) == (6 if label == "prefix" else 4), "Wrong frozen overlay count")
        manifests = {side: load(rows, label + "/rows/" + side + ".manifest.json") for side in ("baseline", "candidate")}
        freeze = load(proofs, label + "/freeze.json")
        binary = source[label + "/candidate-compare"]
        require(sha(binary) == freeze["probe_sha256"] == manifests["candidate"]["probe_sha256"], "Frozen candidate binary differs")
        require({name: sha(data) for name, data in overlays.items()} == freeze["source_sha256"], "Exact frozen overlay differs")
        for side, manifest in manifests.items():
            mapping = manifest["source"]["sha256"]
            require(manifest["source"]["digest"] == sha(json.dumps(mapping, sort_keys=True).encode()), "Source digest differs")
            material = base if side == "baseline" else base | overlays
            require(all(name in material and sha(material[name]) == digest for name, digest in mapping.items()), "Source reconstruction differs")
        require(sha(baseline_binary) == manifests["baseline"]["probe_sha256"], "Baseline executable differs")
        require(b"All 734 tests passed" in proofs[label + "/full-safe.log"] or b"734/734 tests passed" in proofs[label + "/full-safe.log"], "Full Safe proof missing")
        events = load(rows, label + "/rows/events.json")
        require(len(events) == 96, "Expected96children")
        saved = load(proofs, label + "/independent-stats.json")
        require(saved["events_sha256"] == sha(rows[label + "/rows/events.json"]), "Independent stats bind wrong events")
        all_fixtures = {fixture["key"]: fixture for fixture in manifests["baseline"]["fixtures"]}
        shapes = load(proofs, label + "/first-block-shapes.json")
        require("derived" in shapes["artifact_kind"] and "first block headers only" in shapes["scope"] and shapes["source_revision"] == manifests["baseline"]["source"]["revision"], "First-block shape scope differs")
        require(len(shapes["rows"]) == 12 and len({shape["key"] for shape in shapes["rows"]}) == 12, "First-block fixture keys differ")
        for shape in shapes["rows"]:
            require(shape["key"] in all_fixtures and shape["literal_complete"] and shape["literal_max_bits"] > 9 and not shape["rle258_candidate"] and not shape["rle258_should_use"], "First-block shape record differs")
            fixture = all_fixtures[shape["key"]]
            require(shape["first_block_final"] == (fixture["size"] == "65536"), "First-block final scope differs")
            require(shape["route"] == ("nonOverlap" if shape["distance_max_bits"] >= 12 else "generic11/aligned"), "Recorded first-block classification differs")
        payload = load(proofs, label + "/payload-counts.json")
        require("derived" in payload["artifact_kind"] and "counts are not timings or semantic packed lookup counts" in payload["scope"], "Payload count origin/scope differs")
        require(len(payload["rows"]) == 6 and len({row["key"] for row in payload["rows"]}) == 6, "Payload count fixture set differs")
        for count in payload["rows"]:
            fixture = all_fixtures[count["key"]]
            require(fixture["size"] == "65536" and count["wire_sha256"] == fixture["encoded_sha256"] and count["wire_bytes"] == fixture["encoded_bytes"], "Payload count wire identity differs")
            require(count["literal_bytes"] + count["match_bytes"] == fixture["input_bytes"] == 65536, "Payload output byte accounting differs")
            require((count["endbit"] + 7) // 8 == count["wire_bytes"], "Payload EOB byte consumption differs")
            for field, length in (("match_length_buckets_le16_17to64_65to258", 3), ("ll_extra_widths0to5", 6), ("distance_extra_widths0to13", 14), ("distance_symbol_widths_le8_gt8", 2)):
                require(len(count[field]) == length and sum(count[field]) == count["match_count"], "Payload count bucket invariant differs: " + field)
            require(sum(count["ll_symbol_widths_le11_gt11"]) == count["literal_bytes"] + count["match_count"], "LL symbol counts differ")
            require(count["overlap_count"] + count["nonoverlap_count"] == count["match_count"], "Overlap classes differ")
            require(count["distance1"] + count["distance2to4"] <= count["match_count"], "Subset distance counts differ")
        cursor, recomputed = 0, {}
        for size in ("65536", "1048576"):
            for name in ("reymont", "nci", "xml"):
                for level in (6, 9):
                    fixture = all_fixtures["deflate/" + name + "/" + size + "/" + str(level)]
                    selected_fixtures[fixture["key"]] = fixture
                    key = "deflate_" + name + "_" + size + "_" + str(level) + "_cold"
                    ratios = []
                    for pair in range(4):
                        times = {}
                        order = ("baseline", "candidate") if pair % 2 == 0 else ("candidate", "baseline")
                        for side in order:
                            stem = label + "/rows/" + key + "." + str(pair) + "." + side
                            event = load(rows, stem + ".json")
                            require(event == events[cursor] and event["key"] == key and event["pair"] == pair and event["label"] == side, "Outer pairing differs")
                            cursor += 1
                            require(event["returncode"] == 0 and event["probe"] == load(rows, stem + ".stdout.raw"), "Raw output/returncode differs")
                            require(rows[stem + ".stderr.raw"] == b"" and not event["before"]["compilers"] and not event["after"]["compilers"], "Unexpected stderr/compiler observation")
                            require(event["argv"][:4] == ["taskset", "-c", "15", manifests[side]["probe"]], "Wrong child command")
                            validate_probe(event["probe"], fixture, manifests[side])
                            times[side] = statistics.median(p["vort_ns"] for p in event["probe"]["pairs"])
                        ratios.append(times["baseline"] / times["candidate"])
                    geomean = math.exp(statistics.mean(math.log(value) for value in ratios))
                    summary = load(rows, label + "/rows/" + key + ".summary.json")
                    require(ratios == summary["speed_ratios"] == saved["rows"][key]["speed_ratios"] and geomean == summary["geomean"] == saved["rows"][key]["geomean"], "Raw row statistics differ")
                    recomputed[key] = geomean
        total = math.exp(statistics.mean(math.log(value) for value in recomputed.values()))
        require(total == saved["geomean_twelve_selected_rows"] and math.isclose(total, EXPECTED[label], abs_tol=1e-15, rel_tol=0), "Twelve-row aggregate differs")
        result[label] = {"events": 96, "rows": recomputed, "geomean_twelve_selected_rows": total,
                         "target_reymont_64k_l6": recomputed["deflate_reymont_65536_6_cold"],
                         "controls_below_0_98": {key: value for key, value in recomputed.items() if key != "deflate_reymont_65536_6_cold" and value < .98}}
    libraries = REPO / reuse["reference_libraries"]["path"]
    require(load(proofs, "prefix/payload-counts.json") == load(proofs, "refill/payload-counts.json"), "Identical frozen inputs have different derived payload counts")
    require(sha(libraries.read_bytes()) == reuse["reference_libraries"]["sha256"], "Reference archive differs")
    modern = REPO / reuse["modern_manifest"]["path"]
    require(sha(modern.read_bytes()) == reuse["modern_manifest"]["sha256"], "Prior fixture manifest differs")
    prior_fixtures = {fixture["key"]: fixture for fixture in json.loads(gzip.decompress(modern.read_bytes()))["fixtures"]}
    require(all(prior_fixtures[key] == fixture for key, fixture in selected_fixtures.items()), "Selected producer wire metadata differs from prior package")
    with tarfile.open(libraries, "r:gz") as library_archive:
        library_data = library_archive.extractfile("deflate/libdeflate.so.0").read()
    for label in ("prefix", "refill"):
        manifest = load(rows, label + "/rows/baseline.manifest.json")
        require(sha(library_data) == manifest["references"]["deflate"]["file_sha256"][manifest["references"]["deflate"]["path"]], "Pinned libdeflate SO differs")
        audit = load(proofs, label + "/codegen-audit.json")
        require(audit["baseline_probe_sha256"] == sha(baseline_binary) and audit["candidate_probe_sha256"] == sha(archives[label + "-source-probe.tar.gz"][label + "/candidate-compare"]), "Derived codegen summary binds wrong binaries")
        require("derived" in audit["artifact_kind"] and "Not dynamic" in audit["scope"], "Codegen scope misrepresented")
    if fixtures:
        for fixture in selected_fixtures.values():
            require(sha(Path(fixture["input_path"]).read_bytes()) == fixture["input_sha256"] and sha(Path(fixture["encoded_input_path"]).read_bytes()) == fixture["encoded_sha256"], "Frozen fixture bytes changed")
    if git_repo:
        mapping = load(rows, "prefix/rows/baseline.manifest.json")["source"]
        process = subprocess.Popen(["git", "cat-file", "--batch"], cwd=git_repo, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        for name, digest in mapping["sha256"].items():
            process.stdin.write((mapping["revision"] + ":" + name + "\n").encode()); process.stdin.flush()
            header = process.stdout.readline().split(); require(len(header) == 3 and header[1] == b"blob", "Immutable baseline blob missing")
            data = process.stdout.read(int(header[2])); require(process.stdout.read(1) == b"\n" and sha(data) == digest, "Immutable8ad source differs")
        process.stdin.close(); require(process.wait() == 0, "Git source verification failed")
    return {"schema": "vort.deflate.reader-screens-validation.v1", "archives": len(archives), "members": sum(map(len, archives.values())),
            "screens": result, "events": 192, "selected_rows": 24, "original_bytes": original, "git_blobs": bool(git_repo), "fixture_bytes": fixtures,
            "scope": "Offline identity/source/raw-statistics/guards/input/exact-consumption verification. No profile clocks, codec heap, full72-row acceptance or dynamic codegen claim."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original-bytes", action="store_true")
    parser.add_argument("--git-repo", type=Path)
    parser.add_argument("--fixture-bytes", action="store_true")
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    data = json.dumps(verify(args.original_bytes, args.git_repo, args.fixture_bytes), indent=2, sort_keys=True) + "\n"
    if args.receipt:
        args.receipt.write_text(data)
    print(data, end="")


if __name__ == "__main__":
    main()
