#!/usr/bin/env python3
"""Verify preserved evidence and independently recompute statistics, without decoding."""
import argparse
import csv
import gzip
import hashlib
import io
import json
import math
from pathlib import Path
import random
import statistics
import subprocess
import tarfile

HERE = Path(__file__).resolve().parent


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def near(actual, expected, message):
    require(math.isclose(actual, expected, rel_tol=1e-12, abs_tol=1e-12), message)


def gunzip(path):
    data = path.read_bytes()
    require(data[:3] == b"\x1f\x8b\x08" and data[3] == 0 and data[4:8] == bytes(4), "Non-deterministic gzip header")
    return gzip.decompress(data)


def read_archive(path, mode=0o644, allow_links=False):
    files, links, names = {}, {}, []
    with tarfile.open(fileobj=io.BytesIO(gunzip(path)), mode="r:") as archive:
        for member in archive:
            name = member.name
            require(not Path(name).is_absolute() and ".." not in Path(name).parts and name not in names, "Unsafe or duplicate archive path")
            names.append(name)
            require(member.uid == member.gid == member.mtime == 0 and member.uname == member.gname == "", "Archive metadata differs")
            if member.isfile():
                require(member.mode in (0o644, 0o755) if mode is None else member.mode == mode, f"Archive file mode differs: {path.name}/{name}")
                files[name] = archive.extractfile(member).read()
            elif member.issym() and allow_links:
                require(member.mode == 0o777, "Archive link mode differs")
                links[name] = member.linkname
            else:
                raise ValueError("Unexpected archive member type")
    require(names == sorted(names), "Archive order differs")
    return files, links


def bootstrap(probes, seed, resamples):
    # Independent implementation with the epoch's exact order-statistic CI.
    rng = random.Random(seed)
    strata = []
    for probe in probes:
        strata.append([[math.log(pair["vort_ns"] / pair["reference_ns"])
                        for pair in probe["pairs"] if pair["first"] == order]
                       for order in ("vort", "reference")])
    center = math.exp(statistics.mean(statistics.mean(a + b) for a, b in strata))
    draws = []
    for _ in range(resamples):
        means = []
        for a, b in strata:
            selected = [rng.choice(a) for _ in a] + [rng.choice(b) for _ in b]
            means.append(statistics.mean(selected))
        draws.append(math.exp(statistics.mean(means)))
    draws.sort()
    return center, [draws[int(0.025 * resamples)], draws[min(resamples - 1, int(0.975 * resamples))]]


def verify(args):
    root = args.package.resolve()
    if not args.freeze_receipt:
        inventory = {}
        for line in (root / "SHA256SUMS").read_text().splitlines():
            expected, name = line.split("  ", 1)
            require("/" not in name and name not in inventory, "Unsafe checksum entry")
            require(digest((root / name).read_bytes()) == expected, f"Checksum differs: {name}")
            inventory[name] = expected
        require(set(inventory) == {p.name for p in root.iterdir() if p.is_file() and p.name != "SHA256SUMS"}, "Incomplete checksum inventory")
    bindings = json.loads((root / "archive-bindings.json").read_text())
    overview = HERE.parent / "modern-decode-refresh-20261111.md"
    if overview.exists():
        require(digest(overview.read_bytes()) == bindings["overview_sha256"], "Readable overview bytes differ")
    manifest = json.loads(gunzip(root / "manifest.json.gz"))
    packet = json.loads(gunzip(root / "packet.json.gz"))
    aggregate = json.loads((root / "aggregate-summary.json").read_text())
    summary = json.loads((root / "summary.json").read_text())
    validation = json.loads((root / "validation.json").read_text())
    require(manifest["source"]["revision"] == bindings["source_revision"] == "ea193be259579ceda476c9278dd726fbfaec7e51", "Source revision differs")
    require(summary["complete"] is True and summary["completed_rows"] == summary["expected_rows"] == 360, "Incomplete matrix")
    for name, expected in bindings["exact_standalone_bytes"].items():
        require(digest((root / name).read_bytes()) == expected, f"Original standalone bytes differ: {name}")
    for name, expected in bindings["exact_gzip_payloads"].items():
        require(digest(gunzip(root / name)) == expected, f"Original gzip payload differs: {name}")
    raw, metadata, source, binary, stdout = {}, {}, {}, {}, {}
    destinations = {"raw-rows.tar.gz": raw, "metadata.tar.gz": metadata,
                    "source-snapshot.tar.gz": source, "probe.tar.gz": binary,
                    "probe-stdout-json.tar.gz": stdout}
    for name, destination in destinations.items():
        bound = bindings["archives"][name]
        require(digest((root / name).read_bytes()) == bound["sha256"], f"Archive container differs: {name}")
        files, links = read_archive(root / name, mode=bound["mode"])
        require(not links and len(files) == bound["members"], "Archive cardinality differs")
        expected = manifest["source"]["sha256"] if name == "source-snapshot.tar.gz" else bound["member_sha256"]
        require({key: digest(data) for key, data in files.items()} == expected, f"Archive member bytes differ: {name}")
        destination.update(files)
    require(digest(binary["bin/vort-decode-compare"]) == manifest["probe_sha256"] == packet["probe_sha256"], "Probe binding differs")
    require(len(source) == bindings["source_files"] == 2029, "Source snapshot incomplete")
    source_digest = digest(json.dumps({name: digest(data) for name, data in source.items()}, sort_keys=True).encode())
    require(source_digest == manifest["source"]["digest"] == bindings["source_digest"], "Source digest differs")
    require(json.loads(metadata["manifest.json"]) == manifest and metadata["packet.json"] == gunzip(root / "packet.json.gz"), "Metadata manifest/packet differs")
    require(digest(metadata["packet.json"]) == bindings["original_packet_sha256"], "Original packet bytes differ")
    for name, bound in packet["artifacts"].items():
        data = raw[name] if name.startswith("rows/") else metadata[name]
        require(digest(data) == bound["sha256"] and len(data) == bound["bytes"], f"Original artifact differs: {name}")
    reuse = json.loads((root / "reference-reuse.json").read_text())
    reference_files = {}
    for key in ("reference_library_archive", "reference_build_archive"):
        bound = reuse[key]
        path = args.reference_package / Path(bound["path"]).name
        require(digest(path.read_bytes()) == bound["sha256"], "Reused reference archive differs")
        files, links = read_archive(path, mode=None, allow_links=True)
        require({name: digest(data) for name, data in files.items()} == bound["files"] and links == bound["symlinks"], "Reused reference members differ")
        if key == "reference_library_archive":
            reference_files = files
    for member, original in reuse["reference_library_archive"]["original_paths"].items():
        expected = next(ref["file_sha256"][original] for ref in manifest["references"].values() if original in ref["file_sha256"])
        require(digest(reference_files[member]) == expected, "Selected reference binary differs")
    levels = {"deflate": (6, 9), "zstd": (3, 19), "brotli": (6, 11)}
    names = ("dickens", "mozilla", "mr", "nci", "ooffice", "osdb", "reymont", "samba", "sao", "webster", "xml", "x-ray")
    expected_fixtures = {f"{codec}/{name}/{size}/{level}" for codec in levels for name in names for size in ("65536", "1048576", "full") for level in levels[codec]}
    fixture_map = {f["key"]: f for f in manifest["fixtures"]}
    require(len(manifest["fixtures"]) == 216 and set(fixture_map) == expected_fixtures, "Incomplete fixture dimensions")
    prior = json.loads(metadata["prior-fixture-manifest.json"])
    require(prior["fixtures"] == manifest["fixtures"], "Frozen wire metadata changed during reuse")
    expected_tasks = {(key, mode) for key, f in fixture_map.items() for mode in ("cold", "prepared") if not (f["codec"] == "brotli" and mode == "prepared")}
    tasks = manifest["tasks"]
    require(len(tasks) == 360 and {(t["fixture"]["key"], t["lifecycle"]) for t in tasks} == expected_tasks, "Incomplete lifecycle dimensions")
    raw_names = {"rows/" + t["fixture"]["key"].replace("/", "_") + "_" + t["lifecycle"] + suffix for t in tasks for suffix in (".json", ".stderr.txt", ".rss.txt")}
    require(set(raw) == raw_names and len(stdout) == 360, "Raw/stdout archive incomplete")
    groups, size_groups, rows = {}, {}, []
    measured = warmup = 0
    api_pairs = {
        ("deflate", "cold"): ("decodeRawDeflate", "libdeflate_alloc_decompressor+libdeflate_deflate_decompress_ex+libdeflate_free_decompressor"),
        ("deflate", "prepared"): ("decodeRawDeflate", "libdeflate_deflate_decompress_ex;retained-decompressor"),
        ("zstd", "cold"): ("decodeFrameInto", "ZSTD_decompress"),
        ("zstd", "prepared"): ("NativeFrameDecoder.decodeIntoSlice", "ZSTD_decompressDCtx;retained-DCtx"),
        ("brotli", "cold"): ("brDecodeStreamInto", "BrotliDecoderDecompress;one-shot-state-and-internal-heap-per-call"),
    }
    config = manifest["config"]
    require(config["cpu"] == 15 and config["rounds"] == 6 and config["warmup"] == 2, "Sampling schedule differs")
    require(config["iterations"] == {"65536": 100, "1048576": 20, "full": 1}, "Iteration schedule differs")
    require(aggregate["size_groups"] == summary["groups"], "Aggregate size groups differ")
    for task in tasks:
        f = task["fixture"]
        codec, mode = f["codec"], task["lifecycle"]
        require(f == fixture_map[f["key"]] and task["iterations"] == config["iterations"][f["size"]], "Task metadata differs")
        key = f["key"].replace("/", "_") + "_" + mode
        row = json.loads(raw["rows/" + key + ".json"])
        p = row["probe"]
        require(row["task"] == task and raw["rows/" + key + ".stderr.txt"] == b"", "Raw task or stderr differs")
        require(int(raw["rows/" + key + ".rss.txt"].strip()) == row["rss_kib"] > 0, "RSS sidecar differs")
        require(json.loads(stdout["stdout/" + key + ".json"]) == p, "Derived stdout values differ")
        require(p["schema"] == "vort.decode-compare.v1" and p["codec"] == codec and p["lifecycle"] == mode, "Probe schema/task differs")
        for field in ("input_bytes", "encoded_bytes", "input_sha256", "encoded_sha256", "input_path", "encoded_input_path"):
            require(p[field] == f[field], f"Frozen fixture field differs: {field}")
        require(p["iterations"] == task["iterations"] and p["rounds"] == 6 and p["warmup"] == 2, "Probe sample schedule differs")
        ref = manifest["references"][codec]
        roles = ("encoder", "decoder", "common") if codec == "brotli" else ("path",)
        selected = [ref[role] for role in roles]
        require(p["reference_paths"] == selected and p["reference_version"] == ref["version"], "Reference path/version differs")
        prefixes = {"deflate": ("libdeflate.so",), "zstd": ("libzstd.so",), "brotli": ("libbrotlienc.so", "libbrotlidec.so", "libbrotlicommon.so")}[codec]
        require({path for path in p["loaded_shared_library_paths"] if Path(path).name.startswith(prefixes)} == set(selected), "Mixed reference closure")
        require(p["reference_version_origin"] == "declared-pinned-header" if codec == "deflate" else p["reference_version_origin"].startswith("queried-"), "Reference version origin differs")
        if codec == "brotli":
            require(p["brotli_encoder_abi_version"] == p["brotli_decoder_abi_version"], "Brotli version mismatch")
        match = "reference-only-prepared" if codec == "deflate" and mode == "prepared" else "matched-" + mode
        require(p["lifecycle_match"] == match and (p["vort_api"], p["reference_api"]) == api_pairs[(codec, mode)], "API/lifecycle differs")
        provenance = p["provenance"]
        for field, expected in {"optimize": "ReleaseFast", "zig_version": "0.16.0", "target_arch": "x86_64", "target_os": "linux", "target_abi": "gnu", "target_cpu": "skylake+pku+sgx", "cpu_affinity": "15", "affinity_cpu_count": 1, "benchmark_threads": 1, "codec_thread_policy": "single", "executable_sha256": manifest["probe_sha256"]}.items():
            require(provenance[field] == expected, f"Provenance differs: {field}")
        require(provenance["cpu_model"] == manifest["environment"]["cpu_model"], "CPU model differs")
        require(p["alignment"]["guard_bytes"] == 64 and all(p["alignment"][field] == 0 for field in ("input_mod64", "encoded_mod64", "vort_output_mod64", "reference_output_mod64")), "Guard/alignment differs")
        for field in ("every_iteration_count", "full_output_per_batch", "guards_per_batch", "input_unchanged_per_batch"):
            require(p["validation"][field] is True, "Required validation missing")
        require(p["validation"]["exact_consumption_per_batch"] == (codec == "deflate"), "Consumption scope differs")
        require(p["exact_consumption"] == {"vort": codec == "deflate", "reference": codec == "deflate"}, "Consumption API exposure differs")
        require(p["validation"]["prepared_priming"] == (mode == "prepared"), "Prepared priming scope differs")
        for field, count, offset in (("warmup_pairs", 2, 0), ("pairs", 6, 2)):
            require(len(p[field]) == count, "Missing raw pair")
            for i, pair in enumerate(p[field]):
                require(pair["pair_id"] == offset + i and pair["first"] == ("vort" if (offset + i) % 2 == 0 else "reference"), "Pair order differs")
                require(all(type(pair[s + "_ns"]) is int and 0 < pair[s + "_ns"] <= (1 << 64) - 1 for s in ("vort", "reference")), "Invalid raw clock")
                expected_mix = task["iterations"] * (f["input_bytes"] + f["input_first_byte"]) % (1 << 64)
                require(pair["vort_mix"] == pair["reference_mix"] == expected_mix, "Batch checksum differs")
        for side in ("vort", "reference"):
            require(p["summary"][side + "_median_ns"] == statistics.median(pair[side + "_ns"] for pair in p["pairs"]), "Median dropped samples")
        measured += 6
        warmup += 2
        groups.setdefault(codec + "/" + mode, []).append(p)
        size_groups.setdefault(codec + "/" + mode + "/" + f["size"], []).append(p)
        rows.append(row)
    require(measured == 2160 and warmup == 720, "Pair inventory differs")
    for key, probes in size_groups.items():
        stored = summary["groups"][key]
        require(len(probes) == stored["rows"] == 24 and stored["resamples"] == 2000, "Size summary dimensions differ")
        center, interval = bootstrap(probes, stored["seed"], stored["resamples"])
        near(center, stored["time_ratio_geomean"], "Size paired mean differs")
        near(1 / center, stored["throughput_ratio_geomean"], "Size throughput differs")
        weakest = max(math.exp(statistics.mean(math.log(pair["vort_ns"] / pair["reference_ns"]) for pair in p["pairs"])) for p in probes)
        near(weakest, stored["weakest_time_ratio"], "Size weak row differs")
        for actual, expected in zip(interval, stored["ci95"]):
            near(actual, expected, "Size bootstrap interval differs")
    for key, probes in groups.items():
        stored = aggregate["aggregate_groups"][key]
        require(len(probes) == stored["rows"] == 72 and stored["resamples"] == 2000, "Aggregate dimensions differ")
        center, interval = bootstrap(probes, stored["seed"], stored["resamples"])
        near(center, stored["time_ratio_geomean"], "Aggregate paired mean differs")
        near(1 / center, stored["throughput_ratio_geomean"], "Aggregate throughput differs")
        for actual, expected in zip(interval, stored["ci95"]):
            near(actual, expected, "Aggregate bootstrap interval differs")
        for actual, expected in zip((1 / interval[1], 1 / interval[0]), stored["throughput_ci95"]):
            near(actual, expected, "Aggregate throughput interval differs")
        scored = []
        byte_count = vt = rt = 0
        for row in rows:
            f, p = row["task"]["fixture"], row["probe"]
            if f["codec"] + "/" + row["task"]["lifecycle"] != key:
                continue
            score = math.exp(statistics.mean(math.log(pair["vort_ns"] / pair["reference_ns"]) for pair in p["pairs"]))
            scored.append((score, f["key"]))
            byte_count += f["input_bytes"] * p["iterations"] * 6
            vt += sum(pair["vort_ns"] for pair in p["pairs"])
            rt += sum(pair["reference_ns"] for pair in p["pairs"])
        for actual, expected in zip(sorted(scored, reverse=True)[:5], stored["weakest_rows"]):
            require(actual[1] == expected["fixture_key"], "Weak-row identity differs")
            near(actual[0], expected["time_ratio"], "Weak-row ratio differs")
        near(byte_count / (1024 * 1024) / (vt / 1e9), stored["pooled_vort_mib_s"], "Pooled Vort rate differs")
        near(byte_count / (1024 * 1024) / (rt / 1e9), stored["pooled_reference_mib_s"], "Pooled reference rate differs")
    csv_bytes = gunzip(root / "matrix.csv.gz")
    require((root / "matrix.csv").read_bytes() == csv_bytes.replace(b"\r\n", b"\n"), "Readable CSV conversion differs")
    csv_rows = list(csv.DictReader(io.StringIO(csv_bytes.decode())))
    require(len(csv_rows) == 360, "CSV incomplete")
    for c, row in zip(csv_rows, rows):
        f, p = row["task"]["fixture"], row["probe"]
        for field, expected in {"codec": f["codec"], "name": f["name"], "size": f["size"], "level": str(f["level"]), "lifecycle": row["task"]["lifecycle"]}.items():
            require(c[field] == expected, "CSV identity differs")
        for field, expected in {"input_bytes": f["input_bytes"], "encoded_bytes": f["encoded_bytes"], "rss_kib": row["rss_kib"]}.items():
            require(int(c[field]) == expected, "CSV count differs")
        for side in ("vort", "reference"):
            near(float(c[side + "_median_ns"]), p["summary"][side + "_median_ns"], "CSV median differs")
        near(float(c["time_ratio"]), p["summary"]["vort_median_ns"] / p["summary"]["reference_median_ns"], "CSV ratio differs")
    observations = [json.loads(line) for line in gunzip(root / "host-observations.jsonl.gz").splitlines()]
    require(len(observations) == 360 and not any(o["compiler_present"] for o in observations), "Compiler observation differs")
    require(all(o["returncode"] == 0 and not s["active_compiler_processes"] for o in observations for s in (o["before"], o["after"])), "Host compiler lists or child statuses differ")
    activity_rows = 0
    for o in observations:
        before = {p["pid"]: p for p in o["before"]["processes_last_seen_on_cpu15"]}
        after = {p["pid"]: p for p in o["after"]["processes_last_seen_on_cpu15"]}
        activity_rows += any(after[pid]["cpu_ticks"] > before[pid]["cpu_ticks"] for pid in before.keys() & after.keys())
    loads = [s["load_average"][0] for o in observations for s in (o["before"], o["after"])]
    require(activity_rows == aggregate["host"]["rows_with_potential_background_activity"] == 272, "Background activity scope differs")
    require(min(loads) == aggregate["host"]["load1_min"] == 0.3125 and max(loads) == aggregate["host"]["load1_max"] == 1.30810546875, "Host load differs")
    final_host = json.loads((root / "host-after-measurement.json").read_text())
    require(not final_host["active_compiler_processes"] and final_host["governor"] == "powersave" and final_host["turbo_disabled"] == "0", "Final host capture differs")
    live_count = fixture_count = 0
    if args.live_root:
        require(subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=args.live_root, text=True).strip() == bindings["source_revision"], "Live root is not the frozen EA193 worktree")
        for name, data in source.items():
            require((args.live_root / name).read_bytes() == data, f"Live frozen source differs: {name}")
        query = "\n".join(bindings["source_revision"] + ":" + name for name in source) + "\n"
        blobs = subprocess.check_output(["git", "cat-file", "--batch"], cwd=args.live_root, input=query.encode())
        offset = 0
        for name, data in source.items():
            end = blobs.index(b"\n", offset)
            header = blobs[offset:end].split()
            require(header[1] == b"blob", "Missing committed source blob")
            size = int(header[2])
            require(blobs[end + 1:end + 1 + size] == data, "Committed source blob differs")
            offset = end + size + 2
        live_count = len(source)
    if args.fixture_root:
        frozen = {f[path_key]: f[hash_key] for f in manifest["fixtures"] for path_key, hash_key in (("input_path", "input_sha256"), ("encoded_input_path", "encoded_sha256"))}
        for original, expected in frozen.items():
            require(digest((args.fixture_root / Path(original).name).read_bytes()) == expected, "Live frozen fixture differs")
        fixture_count = len(frozen)
    require(validation["validated_rows"] == 360 and validation["source_current_and_git_blobs_match"] is True, "Producer validation receipt differs")
    receipt = {"schema": "vort.decode-refresh-archive-validation.v1", "success": True, "rows": 360, "measured_pairs": measured, "warmup_pairs": warmup, "source_files": len(source), "source_revision": bindings["source_revision"], "source_digest": source_digest, "source_overlay": None, "source_snapshot_complete": True, "live_source_and_git_blobs_verified": live_count, "live_frozen_fixture_files_verified": fixture_count, "reference_archives_reused_and_verified": True, "independent_size_bootstrap_groups": 15, "independent_aggregate_bootstrap_groups": 5, "structured_stdout_values_preserved": 360, "original_stdout_text_bytes_retained": False, "raw_stderr_rss_exact": True, "host_observations": 360, "rows_with_compiler_present": 0, "rows_with_potential_background_activity": activity_rows, "no_decoder_or_benchmark_execution": True}
    if args.freeze_receipt:
        (root / "validation-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    print(json.dumps(receipt, indent=2, sort_keys=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=HERE)
    parser.add_argument("--reference-package", type=Path, default=HERE.parent / "modern-decode-current-20261111")
    parser.add_argument("--live-root", type=Path)
    parser.add_argument("--fixture-root", type=Path)
    parser.add_argument("--freeze-receipt", action="store_true", help="initial packaging only, before SHA256SUMS is frozen")
    try:
        verify(parser.parse_args())
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))


if __name__ == "__main__":
    main()
