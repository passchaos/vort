#!/usr/bin/env python3
"""Independently verify this frozen package without running a benchmark."""
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
import tarfile
import xml.etree.ElementTree as ET


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_exact_gzip(path):
    compressed = path.read_bytes()
    require(compressed[:4] == b"\x1f\x8b\x08\x00" and compressed[4:8] == bytes(4),
            f"Gzip must have empty filename and zero timestamp: {path.name}")
    return gzip.decompress(compressed)


def svg_geometry(data):
    elements = [(element.tag, sorted((key, " ".join(value.split()))
                                    for key, value in element.attrib.items()),
                 " ".join((element.text or "").split()), " ".join((element.tail or "").split()))
                for element in ET.fromstring(data).iter()]
    return json.dumps(elements).encode()


def read_archive(path):
    raw = path.read_bytes()
    require(raw[4:8] == bytes(4), f"Nonzero gzip timestamp: {path.name}")
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(raw)), mode="r:") as archive:
        members = archive.getmembers()
        names = [member.name for member in members]
        require(names == sorted(set(names)), f"Unsorted or duplicate archive members: {path.name}")
        files, links = {}, {}
        for member in members:
            require(member.mtime == member.uid == member.gid == 0, f"Nonzero archive metadata: {member.name}")
            require(member.uname == member.gname == "", f"Named archive owner: {member.name}")
            require(not member.name.startswith("/") and ".." not in Path(member.name).parts, "Unsafe archive path")
            if member.isfile():
                files[member.name] = archive.extractfile(member).read()
            elif member.issym():
                require("/" not in member.linkname and member.linkname != "..", "Unsafe symlink")
                links[member.name] = member.linkname
            else:
                raise ValueError(f"Unexpected archive member: {member.name}")
    for name, target in links.items():
        require(str(Path(name).parent / target) in files, f"Dangling SONAME link: {name}")
    return files, links


def bootstrap(rows, seed, count):
    # Reimplemented here, independently of the archived production evidence.py.
    rng = random.Random(seed)
    strata = []
    for row in rows:
        strata.append([[math.log(pair["vort_ns"] / pair["reference_ns"])
                        for pair in row["pairs"] if pair["first"] == order]
                       for order in ("vort", "reference")])
    center = math.exp(statistics.mean(statistics.mean(a + b) for a, b in strata))
    samples = []
    for _ in range(count):
        means = [statistics.mean([rng.choice(a) for _ in a] + [rng.choice(b) for _ in b])
                 for a, b in strata]
        samples.append(math.exp(statistics.mean(means)))
    samples.sort()
    return center, [samples[int(0.025 * count)], samples[min(count - 1, int(0.975 * count))]]


def verify(root, live_root=None, fixture_root=None):
    checksums = root / "SHA256SUMS"
    if checksums.exists():
        expected = {}
        for line in checksums.read_text().splitlines():
            checksum, name = line.split("  ", 1)
            require(name not in expected, "Duplicate package checksum")
            expected[name] = checksum
        actual = {str(path.relative_to(root)) for path in root.rglob("*")
                  if path.is_file() and path != checksums and "__pycache__" not in path.parts}
        require(set(expected) == actual, "Package checksum inventory differs")
        for name, checksum in expected.items():
            require(digest((root / name).read_bytes()) == checksum, f"Package checksum mismatch: {name}")

    original = read_exact_gzip(root / "manifest.json.gz")
    manifest = json.loads(original)
    require(manifest["schema"] == "vort.decode-matrix.v1", "Unexpected manifest schema")
    bindings = json.loads((root / "archive-bindings.json").read_text())
    require(digest(original) == bindings["original_manifest_sha256"], "Exact original manifest bytes differ")
    original_csv = read_exact_gzip(root / "matrix.csv.gz")
    readable_csv = (root / "matrix.csv").read_bytes()
    csv_binding = bindings["csv_binding"]
    require(digest(original_csv) == csv_binding["original_sha256"] ==
            "f7af1b8b1eb7c3526f416033f3e7b1f98626837aa919c0f90a2e4606d402bfaf", "Exact original CSV bytes differ")
    require(len(original_csv) == csv_binding["original_bytes"] == 31315, "Original CSV length differs")
    require(readable_csv == original_csv.replace(b"\r\n", b"\n") and b"\r" not in readable_csv,
            "Readable CSV differs beyond CRLF to LF normalization")
    require(digest(readable_csv) == csv_binding["readable_sha256"] and
            len(readable_csv) == csv_binding["readable_bytes"], "Readable CSV binding differs")
    svg = (root / "cold-size-ratios.svg").read_bytes()
    svg_binding = bindings["svg_presentation"]
    require(digest(svg) == svg_binding["normalized_sha256"], "SVG byte binding differs")
    require(digest(svg_geometry(svg)) == svg_binding["xml_geometry_sha256"] and
            svg_binding["geometry_preserved"] is True, "SVG geometry differs")
    require(all(line.rstrip(b" \t\r") == line for line in svg.split(b"\n")), "SVG trailing whitespace")
    require(json.loads((root / "manifest.json").read_text()) == manifest, "Readable manifest differs")
    require(manifest["source"]["revision"] == "4bca528b36e2c9ac9065826000b3ee66e6c65966", "Unexpected codec base")
    require(manifest["probe_sha256"] == "eddd7b5deaef84f1dc7fc50cc736cb64e0083b6e02e6a40ae8298c8ccc5bb8ba", "Unexpected probe")
    registry = manifest["source"]["sha256"]
    require(len(registry) == 2014, "Incomplete source registry")
    require(digest(json.dumps(registry, sort_keys=True).encode()) == manifest["source"]["digest"], "Source registry digest differs")
    overlay, overlay_links = read_archive(root / "source-overlay.tar.gz")
    expected_overlay = {name for name in registry if name.startswith("tools/decode/")
                        or name in ("build.zig", "build/decode_compare.zig")}
    require(set(overlay) == expected_overlay and not overlay_links, "Source overlay inventory differs")
    for name, data in overlay.items():
        require(digest(data) == registry[name], f"Overlay hash mismatch: {name}")
    executable, executable_links = read_archive(root / "probe.tar.gz")
    require(set(executable) == {"bin/vort-decode-compare"} and not executable_links, "Probe inventory differs")
    require(digest(executable["bin/vort-decode-compare"]) == manifest["probe_sha256"], "Probe hash mismatch")
    libraries, links = read_archive(root / "reference-libraries.tar.gz")
    expected_libraries = {}
    for codec, reference in manifest["references"].items():
        for name, checksum in reference["file_sha256"].items():
            archived_name = f"{codec}/{Path(name).name}"
            require(digest(libraries[archived_name]) == checksum, f"Library hash mismatch: {archived_name}")
            expected_libraries[archived_name] = checksum
    require(len(expected_libraries) == 5, "Incomplete selected library set")
    require(set(libraries) == set(expected_libraries) | {
        "deflate/COPYING", "zstd/LICENSE", "zstd/COPYING", "brotli/LICENSE"}, "Library/license inventory differs")
    require(links == {
        "deflate/libdeflate.so": "libdeflate.so.0",
        "zstd/libzstd.so": "libzstd.so.1.6.0", "zstd/libzstd.so.1": "libzstd.so.1.6.0",
        "brotli/libbrotlicommon.so": "libbrotlicommon.so.1.2.0",
        "brotli/libbrotlicommon.so.1": "libbrotlicommon.so.1.2.0",
        "brotli/libbrotlidec.so": "libbrotlidec.so.1.2.0",
        "brotli/libbrotlidec.so.1": "libbrotlidec.so.1.2.0",
        "brotli/libbrotlienc.so": "libbrotlienc.so.1.2.0",
        "brotli/libbrotlienc.so.1": "libbrotlienc.so.1.2.0"}, "SONAME links differ")
    metadata, metadata_links = read_archive(root / "reference-build-metadata.tar.gz")
    require(not metadata_links, "Unexpected metadata link")
    deflate = json.loads(metadata["deflate/provenance.json"])
    require(digest(metadata["deflate/build.log"]) == deflate["build"]["log_sha256"], "Deflate build log differs")
    require(digest(metadata["deflate/CMakeCache.txt"]) == deflate["build"]["cmake_cache_sha256"], "Deflate build cache differs")
    require(digest(metadata["deflate/compile_commands.json"]) == deflate["build"]["compile_commands_sha256"], "Deflate compile commands differ")
    require(digest(metadata["deflate/libdeflate.h"]) == manifest["references"]["deflate"]["version_header_sha256"], "Deflate version header differs")
    require(digest(metadata["deflate/verify.py"]) == deflate["verification"]["script_sha256"], "Deflate runtime verification script differs")
    require(digest(metadata["zstd/zstd.h"]) == manifest["references"]["zstd"]["header_sha256"], "Zstd version header differs")
    zstd = json.loads(metadata["zstd/provenance.json"])
    require(zstd["sha256"] == manifest["references"]["zstd"]["file_sha256"][zstd["path"]], "Zstd build/library binding differs")
    for codec, record in (("deflate", deflate["source"]), ("zstd", zstd)):
        revision = record.get("revision", record.get("source_revision"))
        require(revision == manifest["references"][codec]["source_revision"], "Reference source revision differs")
    require(b"CMAKE_C_FLAGS:STRING=-O3 -march=skylake" in metadata["brotli/CMakeCache.txt"], "Brotli compiler flags differ")

    fixtures, tasks = manifest["fixtures"], manifest["tasks"]
    names = {"dickens", "mozilla", "mr", "nci", "ooffice", "osdb", "reymont", "samba", "sao", "webster", "xml", "x-ray"}
    levels = {"deflate": (6, 9), "zstd": (3, 19), "brotli": (6, 11)}
    expected_fixtures = {f"{codec}/{name}/{size}/{level}" for codec in levels for name in names
                         for size in ("65536", "1048576", "full") for level in levels[codec]}
    require(len(fixtures) == 216 and {item["key"] for item in fixtures} == expected_fixtures, "Incomplete fixture dimensions")
    fixture_map = {item["key"]: item for item in fixtures}
    task_map = {}
    for task in tasks:
        fixture = task["fixture"]
        require(fixture == fixture_map[fixture["key"]], "Task/fixture metadata differs")
        key = fixture["key"].replace("/", "_") + "_" + task["lifecycle"]
        require(key not in task_map, "Duplicate task")
        require(task["iterations"] == {"65536": 100, "1048576": 20, "full": 1}[fixture["size"]], "Iteration schedule differs")
        task_map[key] = task
    expected_tasks = {(key, mode) for key, fixture in fixture_map.items() for mode in ("cold", "prepared")
                      if not (fixture["codec"] == "brotli" and mode == "prepared")}
    require(len(tasks) == 360 and {(task["fixture"]["key"], task["lifecycle"]) for task in tasks} == expected_tasks, "Incomplete lifecycle dimensions")
    config = manifest["config"]
    require(config["rounds"] == 6 and config["warmup"] == 2 and config["cpu"] == 15, "Unexpected sample schedule")
    host = manifest["environment"]
    require(host["governor"] == "powersave" and host["driver"] == "intel_pstate" and host["turbo_disabled"] == "0", "Host policy differs")
    raw, raw_links = read_archive(root / "raw-rows.tar.gz")
    for name, files, symlinks in (
        ("raw-rows.tar.gz", raw, raw_links),
        ("source-overlay.tar.gz", overlay, overlay_links),
        ("probe.tar.gz", executable, executable_links),
        ("reference-libraries.tar.gz", libraries, links),
        ("reference-build-metadata.tar.gz", metadata, metadata_links),
    ):
        bound = bindings["archives"][name]
        require({key: digest(data) for key, data in files.items()} == bound["files"], f"Archive member bytes differ: {name}")
        require(symlinks == bound["symlinks"], f"Archive symlink bindings differ: {name}")
    require(not raw_links and set(raw) == {f"rows/{key}{suffix}" for key in task_map
                                          for suffix in (".json", ".stderr.txt", ".rss.txt")}, "Incomplete raw archive")
    rows, groups, counts = [], {}, {"warmup_pairs": 0, "measured_pairs": 0}
    for key, task in task_map.items():
        row = json.loads(raw[f"rows/{key}.json"])
        require(row["task"] == task, "Raw task identity differs")
        require(raw[f"rows/{key}.stderr.txt"] == b"", "Nonempty probe stderr")
        require(int(raw[f"rows/{key}.rss.txt"].strip()) == row["rss_kib"] > 0, "RSS sidecar differs")
        p, fixture = row["probe"], task["fixture"]
        require(p["schema"] == "vort.decode-compare.v1", "Unexpected raw probe schema")
        codec, mode = fixture["codec"], task["lifecycle"]
        require((p["codec"], p["lifecycle"], p["iterations"]) == (codec, mode, task["iterations"]), "Probe task differs")
        for field in ("input_bytes", "encoded_bytes", "input_sha256", "encoded_sha256", "input_path", "encoded_input_path"):
            require(p[field] == fixture[field], f"Frozen fixture differs: {field}")
        reference = manifest["references"][codec]
        require(p["reference_version"] == reference["version"], "Reference version differs")
        roles = ("encoder", "decoder", "common") if codec == "brotli" else ("path",)
        selected = [reference[role] for role in roles]
        require(p["reference_paths"] == selected, "Reference paths differ")
        prefixes = {"deflate": ("libdeflate.so",), "zstd": ("libzstd.so",),
                    "brotli": ("libbrotlienc.so", "libbrotlidec.so", "libbrotlicommon.so")}[codec]
        mapped = {name for name in p["loaded_shared_library_paths"] if Path(name).name.startswith(prefixes)}
        require(mapped == set(selected), "Mixed reference closure")
        match = "reference-only-prepared" if codec == "deflate" and mode == "prepared" else f"matched-{mode}"
        require(p["lifecycle_match"] == match, "Lifecycle match differs")
        apis = {
            ("deflate", "cold"): ("decodeRawDeflate", "libdeflate_alloc_decompressor+libdeflate_deflate_decompress_ex+libdeflate_free_decompressor"),
            ("deflate", "prepared"): ("decodeRawDeflate", "libdeflate_deflate_decompress_ex;retained-decompressor"),
            ("zstd", "cold"): ("decodeFrameInto", "ZSTD_decompress"),
            ("zstd", "prepared"): ("NativeFrameDecoder.decodeIntoSlice", "ZSTD_decompressDCtx;retained-DCtx"),
            ("brotli", "cold"): ("brDecodeStreamInto", "BrotliDecoderDecompress;one-shot-state-and-internal-heap-per-call"),
        }
        require((p["vort_api"], p["reference_api"]) == apis[(codec, mode)], "Selected API lifecycle differs")
        origin = p["reference_version_origin"]
        require(origin == "declared-pinned-header" if codec == "deflate" else origin.startswith("queried-"), "Reference version origin differs")
        if codec == "brotli":
            require(p["brotli_encoder_abi_version"] == p["brotli_decoder_abi_version"] == 0x1002000, "Brotli ABI versions differ")
        provenance = p["provenance"]
        for field, value in {"executable_sha256": manifest["probe_sha256"], "target_cpu": config["target_cpu"],
                             "zig_version": host["zig_version"], "cpu_model": host["cpu_model"],
                             "cpu_affinity": "15", "affinity_cpu_count": 1, "benchmark_threads": 1,
                             "codec_thread_policy": "single", "optimize": "ReleaseFast",
                             "target_arch": "x86_64", "target_os": "linux", "target_abi": "gnu"}.items():
            require(provenance[field] == value, f"Probe provenance differs: {field}")
        require(p["alignment"] == {"guard_bytes": 64, "input_mod64": 0, "encoded_mod64": 0,
                                   "vort_output_mod64": 0, "reference_output_mod64": 0}, "Alignment/guards differ")
        validation = p["validation"]
        require(all(validation[field] is True for field in ("every_iteration_count", "full_output_per_batch",
                                                            "guards_per_batch", "input_unchanged_per_batch")), "Safety validation missing")
        require(validation["exact_consumption_per_batch"] == (codec == "deflate"), "Consumption scope differs")
        require(p["exact_consumption"] == {"vort": codec == "deflate", "reference": codec == "deflate"}, "Consumption metadata differs")
        require(validation["prepared_priming"] == (mode == "prepared"), "Priming metadata differs")
        for field, count, offset in (("warmup_pairs", 2, 0), ("pairs", 6, 2)):
            pairs = p[field]
            require(len(pairs) == count, "Missing raw sample")
            counts["warmup_pairs" if field == "warmup_pairs" else "measured_pairs"] += len(pairs)
            for index, pair in enumerate(pairs):
                require(pair["pair_id"] == offset + index, "Pair identity differs")
                require(pair["first"] == ("vort" if (offset + index) % 2 == 0 else "reference"), "Unbalanced pair order")
                require(all(type(pair[f"{side}_ns"]) is int and pair[f"{side}_ns"] > 0 for side in ("vort", "reference")), "Invalid duration")
                expected_mix = task["iterations"] * (fixture["input_bytes"] + fixture["input_first_byte"]) % (1 << 64)
                require(pair["vort_mix"] == pair["reference_mix"] == expected_mix, "Output accounting differs")
        for side in ("vort", "reference"):
            require(p["summary"][f"{side}_median_ns"] == statistics.median(pair[f"{side}_ns"] for pair in p["pairs"]), "Median differs")
        group = f"{codec}/{mode}/{fixture['size']}"
        groups.setdefault(group, []).append(p)
        rows.append(row)
    require(counts == {"warmup_pairs": 720, "measured_pairs": 2160}, "Pair totals differ")
    summary = json.loads((root / "summary.json").read_text())
    require(summary["schema"] == "vort.decode-matrix-summary.v1", "Unexpected summary schema")
    require(summary["complete"] is True and summary["completed_rows"] == summary["expected_rows"] == 360, "Partial summary")
    require(set(summary["groups"]) == set(groups) and len(groups) == 15, "Summary groups differ")
    for index, (name, group) in enumerate(sorted(groups.items())):
        saved = summary["groups"][name]
        require(saved["seed"] == 0x20261111 + index and saved["resamples"] == 2000 and saved["rows"] == len(group) == 24, "Bootstrap schedule differs")
        center, ci = bootstrap(group, saved["seed"], saved["resamples"])
        require(saved["time_ratio_geomean"] == center and saved["ci95"] == ci, f"Bootstrap summary differs: {name}")
        require(saved["throughput_ratio_geomean"] == 1 / center, "Throughput ratio differs")
        weakest = max(math.exp(statistics.mean(math.log(pair["vort_ns"] / pair["reference_ns"]) for pair in row["pairs"])) for row in group)
        require(saved["weakest_time_ratio"] == weakest, "Weak-row summary differs")
    records = list(csv.DictReader((root / "matrix.csv").open(newline="")))
    require(len(records) == len(rows), "CSV row count differs")
    for record, row in zip(records, rows):
        fixture, probe = row["task"]["fixture"], row["probe"]
        for field in ("codec", "name", "size", "level", "input_bytes", "encoded_bytes"):
            require(record[field] == str(fixture[field]), f"CSV fixture differs: {field}")
        require(record["lifecycle"] == row["task"]["lifecycle"], "CSV lifecycle differs")
        for field in ("vort_median_ns", "reference_median_ns"):
            require(float(record[field]) == probe["summary"][field], "CSV median differs")
        require(float(record["time_ratio"]) == probe["summary"]["vort_median_ns"] / probe["summary"]["reference_median_ns"], "CSV ratio differs")
        require(int(record["rss_kib"]) == row["rss_kib"], "CSV RSS differs")

    live_files = 0
    if live_root:
        for name, checksum in registry.items():
            require(digest((live_root / name).read_bytes()) == checksum, f"Live source differs: {name}")
            live_files += 1
    frozen_files = {}
    if fixture_root:
        for fixture in fixtures:
            for path_field, hash_field in (("input_path", "input_sha256"), ("encoded_input_path", "encoded_sha256")):
                name = Path(fixture[path_field]).name
                checksum = fixture[hash_field]
                require(name not in frozen_files or frozen_files[name] == checksum, "Inconsistent frozen hash")
                if name not in frozen_files:
                    require(digest((fixture_root / name).read_bytes()) == checksum, f"Frozen input differs: {name}")
                    frozen_files[name] = checksum
    cold = {}
    for codec in levels:
        selected = [row["probe"] for row in rows if row["probe"]["codec"] == codec and row["probe"]["lifecycle"] == "cold"]
        require(len(selected) == 72, "Incomplete global cold rows")
        cold[codec] = math.exp(statistics.mean(statistics.mean(math.log(pair["vort_ns"] / pair["reference_ns"]) for pair in row["pairs"]) for row in selected))
    return {"schema": "vort.decode-archive-validation.v1", "valid": True,
            "validator": "independent stdlib implementation; no benchmark rerun",
            "source_registry_entries": len(registry), "source_overlay_files": len(overlay),
            "reference_shared_libraries": len(expected_libraries), "reference_symlinks": len(links),
            "fixtures": len(fixtures), "tasks": len(tasks), "raw_archive_members": len(raw),
            **counts, "recomputed_summary_groups": len(groups), "csv_rows": len(records),
            "csv_original_sha256": digest(original_csv), "csv_readable_sha256": digest(readable_csv),
            "csv_line_endings_normalized": True, "svg_geometry_preserved": True,
            "nonempty_stderr": 0, "live_source_files_verified": live_files,
            "live_fixture_files_verified": len(frozen_files), "cold_global_time_ratios": cold,
            "scope": "Recorded output/count/guard/consumption claims checked; timed decoders are not rerun. RSS is whole child, and fixed-row CIs describe development-host sampling."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live-root", type=Path)
    parser.add_argument("--fixture-root", type=Path)
    args = parser.parse_args()
    receipt = verify(Path(__file__).resolve().parent, args.live_root, args.fixture_root)
    print(json.dumps(receipt, indent=2) + "\n", end="")


if __name__ == "__main__":
    main()
