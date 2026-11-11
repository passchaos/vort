"""Validate raw paired decoder evidence and summarize without selecting minima."""
import math
from pathlib import Path
import random
import statistics

from fixtures import LEVELS, SILESIA, sha256


def require(condition, message):
    if not condition:
        raise ValueError(message)


def positive_integer(value):
    return type(value) is int and 0 < value <= (1 << 64) - 1


def median(values):
    return statistics.median(values)


def reference_files(reference, codec):
    keys = ("encoder", "decoder", "common") if codec == "brotli" else ("path",)
    return [str(Path(reference[key]).resolve()) for key in keys]


def validate_manifest(manifest):
    require(manifest.get("schema") == "vort.decode-matrix.v1", "Wrong matrix schema")
    config = manifest["config"]
    for key, allowed in (("sizes", {"65536", "1048576", "full"}), ("lifecycles", {"cold", "prepared"})):
        values = config[key]
        require(bool(values) and len(values) == len(set(values)) and set(values) <= allowed, f"Invalid or duplicate {key}")
    expected = {f"{codec}/{name}/{size}/{level}" for codec, levels in LEVELS.items() for name in SILESIA for size in config["sizes"] for level in levels}
    fixtures = manifest["fixtures"]
    require(len(fixtures) == len(expected) and {f["key"] for f in fixtures} == expected, "Missing, duplicate or unknown fixture rows")
    for fixture in fixtures:
        require(fixture["key"] == f"{fixture['codec']}/{fixture['name']}/{fixture['size']}/{fixture['level']}", "Fixture key and codec/name/size/level disagree")
        require(fixture["codec"] in LEVELS and fixture["name"] in SILESIA and fixture["size"] in config["sizes"] and fixture["level"] in LEVELS[fixture["codec"]], "Invalid fixture dimensions")
    fixture_map = {f["key"]: f for f in fixtures}
    expected_tasks = {(key, lifecycle) for key, f in fixture_map.items() for lifecycle in config["lifecycles"] if not (f["codec"] == "brotli" and lifecycle == "prepared")}
    tasks = manifest["tasks"]
    require(len(tasks) == len(expected_tasks), "Missing or duplicate lifecycle tasks")
    actual = set()
    for task in tasks:
        key = task["fixture"]["key"]
        require(key in fixture_map and task["fixture"] == fixture_map[key], "Task fixture metadata drift")
        require(task["iterations"] == config["iterations"][task["fixture"]["size"]], "Task iteration schedule drift")
        actual.add((key, task["lifecycle"]))
    require(actual == expected_tasks, "Missing, duplicate or unknown lifecycle tasks")
    return manifest


def validate_report(report, task, manifest, verify_files=True):
    fixture = task["fixture"]
    codec, lifecycle = fixture["codec"], task["lifecycle"]
    require(report.get("schema") == "vort.decode-compare.v1", "Wrong raw probe schema")
    require(report.get("codec") == codec and report.get("lifecycle") == lifecycle, "Codec or lifecycle mismatch")
    config = manifest["config"]
    for key in ("iterations", "rounds", "warmup"):
        expected = task["iterations"] if key == "iterations" else config[key]
        require(report.get(key) == expected, f"Wrong {key}")
    require(report["rounds"] >= 2 and report["rounds"] % 2 == 0, "Unbalanced rounds")
    require(report["warmup"] >= 0 and report["warmup"] % 2 == 0, "Unbalanced warmup")
    for key in ("input_bytes", "encoded_bytes", "input_sha256", "encoded_sha256"):
        require(report.get(key) == fixture[key], f"Frozen fixture {key} mismatch")
    for reported, expected in (("input_path", "input_path"), ("encoded_input_path", "encoded_input_path")):
        require(str(Path(report[reported]).resolve()) == fixture[expected], "Fixture path mismatch")
    if verify_files:
        for path_key, hash_key in (("input_path", "input_sha256"), ("encoded_input_path", "encoded_sha256")):
            require(sha256(fixture[path_key]) == fixture[hash_key], "Frozen bytes changed")
        with Path(fixture["input_path"]).open("rb") as source:
            require(source.read(1) == bytes([fixture["input_first_byte"]]), "Frozen input first-byte metadata drift")
    reference = manifest["references"][codec]
    require(report.get("reference_version") == reference["version"], "Reference version mismatch")
    expected_paths = reference_files(reference, codec)
    paths = [str(Path(path).resolve()) for path in report["reference_paths"]]
    require(paths == expected_paths, "Reference path mismatch")
    loaded = {str(Path(path).resolve()) for path in report["loaded_shared_library_paths"]}
    require(set(expected_paths).issubset(loaded), "Selected reference was not actually mapped")
    prefixes = {"deflate": ("libdeflate.so",), "zstd": ("libzstd.so",), "brotli": ("libbrotlienc.so", "libbrotlidec.so", "libbrotlicommon.so")}[codec]
    relevant = {path for path in loaded if Path(path).name.startswith(prefixes)}
    require(relevant == set(expected_paths), "Mixed reference library closure")
    if verify_files:
        for path in expected_paths:
            require(sha256(path) == reference["file_sha256"][path], "Reference library changed")
    origin = report.get("reference_version_origin", "")
    require(origin == "declared-pinned-header" if codec == "deflate" else origin.startswith("queried-"), "Version origin missing")
    if codec == "brotli":
        require(report["brotli_encoder_abi_version"] == report["brotli_decoder_abi_version"], "Brotli ABI version disagreement")
    match = "reference-only-prepared" if codec == "deflate" and lifecycle == "prepared" else f"matched-{lifecycle}"
    require(report.get("lifecycle_match") == match, "Unmatched lifecycle labeled matched")
    require(not (codec == "brotli" and lifecycle == "prepared"), "Brotli has no prepared reset comparison")
    apis = {
        ("deflate", "cold"): ("decodeRawDeflate", "libdeflate_alloc_decompressor+libdeflate_deflate_decompress_ex+libdeflate_free_decompressor"),
        ("deflate", "prepared"): ("decodeRawDeflate", "libdeflate_deflate_decompress_ex;retained-decompressor"),
        ("zstd", "cold"): ("decodeFrameInto", "ZSTD_decompress"),
        ("zstd", "prepared"): ("NativeFrameDecoder.decodeIntoSlice", "ZSTD_decompressDCtx;retained-DCtx"),
        ("brotli", "cold"): ("brDecodeStreamInto", "BrotliDecoderDecompress;one-shot-state-and-internal-heap-per-call"),
    }
    require((report.get("vort_api"), report.get("reference_api")) == apis[(codec, lifecycle)], "API lifecycle mismatch")
    provenance = report["provenance"]
    require(provenance["optimize"] == "ReleaseFast", "Non-release timing")
    require(provenance["benchmark_threads"] == 1 and provenance["affinity_cpu_count"] == 1, "Thread or affinity mismatch")
    require(provenance["cpu_affinity"] == str(config["cpu"]), "Wrong benchmark CPU")
    require(provenance["executable_sha256"] == manifest["probe_sha256"], "Benchmark executable changed")
    require(provenance["zig_version"] == manifest["environment"]["zig_version"], "Compiler mismatch")
    require(provenance["cpu_model"] == manifest["environment"]["cpu_model"], "Host CPU model mismatch")
    require(provenance["target_cpu"] == config["target_cpu"] and provenance["target_abi"] == "gnu", "Target features or ABI mismatch")
    require(provenance["codec_thread_policy"] == "single", "Codec thread policy mismatch")
    require(provenance["target_arch"] == "x86_64" and provenance["target_os"] == "linux", "Unexpected target")
    for key in ("input_mod64", "encoded_mod64", "vort_output_mod64", "reference_output_mod64"):
        require(report["alignment"][key] == 0, "Buffer alignment mismatch")
    require(report["alignment"]["guard_bytes"] == 64, "Guard extent mismatch")
    for key in ("every_iteration_count", "full_output_per_batch", "guards_per_batch", "input_unchanged_per_batch"):
        require(report["validation"].get(key) is True, f"Validation missing: {key}")
    require(report["validation"]["exact_consumption_per_batch"] == (codec == "deflate"), "Consumption scope mismatch")
    for field, count, offset in (("warmup_pairs", config["warmup"], 0), ("pairs", config["rounds"], config["warmup"])):
        pairs = report[field]
        require(len(pairs) == count, f"Dropped or extra {field}")
        for index, pair in enumerate(pairs):
            expected_id = offset + index
            require(pair["pair_id"] == expected_id, "Pair identity/order mismatch")
            require(pair["first"] == ("vort" if expected_id % 2 == 0 else "reference"), "Unbalanced sample order")
            require(positive_integer(pair["vort_ns"]) and positive_integer(pair["reference_ns"]), "Invalid raw duration")
            expected_mix = (task["iterations"] * (fixture["input_bytes"] + fixture["input_first_byte"])) % (1 << 64)
            require(type(pair["vort_mix"]) is int and type(pair["reference_mix"]) is int and pair["vort_mix"] == expected_mix and pair["reference_mix"] == expected_mix, "Per-batch checksum disagreement or unexpected value")
    for side in ("vort", "reference"):
        require(report["summary"][f"{side}_median_ns"] == median([p[f"{side}_ns"] for p in report["pairs"]]), "Median does not include every sample")
    return report


def bootstrap_log_mean(rows, seed, resamples):
    rng = random.Random(seed)
    # Resample within each row and order so the fixed corpus and AB/BA balance
    # stay unchanged. It estimates sampling uncertainty on this host/matrix.
    strata = [[[(math.log(p["vort_ns"] / p["reference_ns"])) for p in row["pairs"] if p["first"] == order] for order in ("vort", "reference")] for row in rows]
    center = math.exp(statistics.mean(statistics.mean(a + b) for a, b in strata))
    samples = []
    for _ in range(resamples):
        means = []
        for a, b in strata:
            chosen = [rng.choice(a) for _ in a] + [rng.choice(b) for _ in b]
            means.append(statistics.mean(chosen))
        samples.append(math.exp(statistics.mean(means)))
    samples.sort()
    return {"time_ratio_geomean": center, "throughput_ratio_geomean": 1 / center, "ci95": [samples[int(0.025 * resamples)], samples[min(resamples - 1, int(0.975 * resamples))]], "method": "order-stratified paired log-ratio bootstrap; fixed rows", "seed": seed, "resamples": resamples}


def summarize(rows, seed=0x20261111, resamples=2000):
    require(resamples >= 100, "Insufficient bootstrap resamples")
    groups = {}
    for row in rows:
        fixture = row["task"]["fixture"]
        key = f"{fixture['codec']}/{row['task']['lifecycle']}/{fixture['size']}"
        groups.setdefault(key, []).append(row["probe"])
    output = {}
    for index, (key, group) in enumerate(sorted(groups.items())):
        result = bootstrap_log_mean(group, seed + index, resamples)
        result["rows"] = len(group)
        result["weakest_time_ratio"] = max(math.exp(statistics.mean(math.log(p["vort_ns"] / p["reference_ns"]) for p in row["pairs"])) for row in group)
        output[key] = result
    return output
