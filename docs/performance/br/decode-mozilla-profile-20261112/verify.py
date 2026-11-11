#!/usr/bin/env python3
"""Independently verify frozen Mozilla evidence without running codec probes."""
import argparse
import csv
import gzip
import hashlib
import io
import json
import math
from pathlib import Path
import random
import re
import statistics
import struct
import subprocess
import tarfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unpack(path, allow_links=False):
    data = path.read_bytes()
    require(data[:4] == b"\x1f\x8b\x08\x00" and data[4:8] == bytes(4), "Non-deterministic gzip header")
    files, links = {}, {}
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(data)), mode="r:") as archive:
        members = archive.getmembers()
        require([m.name for m in members] == sorted({m.name for m in members}), "Duplicate/unsorted tar names")
        for member in members:
            require(not member.name.startswith("/") and ".." not in Path(member.name).parts, "Unsafe tar member")
            require(member.mtime == member.uid == member.gid == 0 and member.uname == member.gname == "", "Nonzero archive metadata")
            if allow_links and member.issym():
                require("/" not in member.linkname and member.linkname != ".." and member.mode == 0o777, "Unsafe reference SONAME link")
                links[member.name] = member.linkname
                continue
            require(member.isfile(), "Unexpected non-file archive member")
            require(member.mode in (0o644, 0o755), "Unexpected tar mode")
            files[member.name] = archive.extractfile(member).read()
    require(all(str(Path(name).parent / target) in files for name, target in links.items()), "Dangling reference SONAME link")
    return files


def json_file(files, name):
    return json.loads(files[name])


def source_digest(source):
    return sha(json.dumps(source, sort_keys=True).encode())


def validate_probe(probe, task, manifest):
    fixture = task["fixture"]
    require(probe["schema"] == "vort.decode-compare.v1" and probe["codec"] == "brotli", "Wrong probe schema/codec")
    require(probe["lifecycle"] == "cold" and probe["lifecycle_match"] == "matched-cold", "Wrong lifecycle")
    require(probe["vort_api"] == "brDecodeStreamInto" and probe["reference_api"] == "BrotliDecoderDecompress;one-shot-state-and-internal-heap-per-call", "Wrong public API")
    for key in ("input_path", "encoded_input_path", "input_bytes", "encoded_bytes", "input_sha256", "encoded_sha256"):
        require(probe[key] == fixture[key], "Fixture drift: " + key)
    reference = manifest["references"]["brotli"]
    selected = [reference[role] for role in ("encoder", "decoder", "common")]
    require(probe["reference_paths"] == selected and probe["reference_version"] == reference["version"] == "1.2.0", "Reference binding differs")
    mapped = {p for p in probe["loaded_shared_library_paths"] if Path(p).name.startswith(("libbrotlienc.so", "libbrotlidec.so", "libbrotlicommon.so"))}
    require(mapped == set(selected), "Mixed reference closure")
    require(probe["reference_version_origin"].startswith("queried-") and probe["brotli_encoder_abi_version"] == probe["brotli_decoder_abi_version"] == 0x1002000, "Reference ABI/version differs")
    require(probe["alignment"] == {"guard_bytes": 64, "input_mod64": 0, "encoded_mod64": 0, "vort_output_mod64": 0, "reference_output_mod64": 0}, "Alignment differs")
    require(probe["exact_consumption"] == {"vort": False, "reference": False}, "Unsupported consumption coverage claimed")
    validation = probe["validation"]
    require(all(validation[k] is True for k in ("every_iteration_count", "full_output_per_batch", "guards_per_batch", "input_unchanged_per_batch")), "Missing recorded validation")
    require(validation["exact_consumption_per_batch"] is False and validation["prepared_priming"] is False, "Wrong validation scope")
    config, host = manifest["config"], manifest["environment"]
    for key, value in {"executable_sha256": manifest["probe_sha256"], "optimize": "ReleaseFast", "zig_version": "0.16.0",
                       "target_arch": "x86_64", "target_os": "linux", "target_abi": "gnu", "target_cpu": config["target_cpu"],
                       "cpu_model": host["cpu_model"], "cpu_affinity": "15", "benchmark_threads": 1,
                       "affinity_cpu_count": 1, "codec_thread_policy": "single"}.items():
        require(probe["provenance"][key] == value, "Probe provenance differs: " + key)
    require(probe["iterations"] == task["iterations"] and probe["rounds"] == config["rounds"] and probe["warmup"] == config["warmup"], "Sampling differs")
    for field, count, offset in (("warmup_pairs", config["warmup"], 0), ("pairs", config["rounds"], config["warmup"])):
        require(len(probe[field]) == count, "Missing samples")
        for index, pair in enumerate(probe[field]):
            pair_id = index + offset
            require(pair["pair_id"] == pair_id and pair["first"] == ("vort" if pair_id % 2 == 0 else "reference"), "Unbalanced pair order")
            require(pair["vort_mix"] == pair["reference_mix"] == task["iterations"] * (fixture["input_bytes"] + fixture["input_first_byte"]), "Output count/mix differs")
            require(all(type(pair[side + "_ns"]) is int and pair[side + "_ns"] > 0 for side in ("vort", "reference")), "Invalid duration")
    for side in ("vort", "reference"):
        require(probe["summary"][side + "_median_ns"] == statistics.median(p[side + "_ns"] for p in probe["pairs"]), "Median excludes raw samples")


def bootstrap(rows, seed, resamples):
    rng = random.Random(seed)
    strata = [[[math.log(p["vort_ns"] / p["reference_ns"]) for p in row["pairs"] if p["first"] == order]
               for order in ("vort", "reference")] for row in rows]
    center = math.exp(statistics.mean(statistics.mean(a + b) for a, b in strata))
    samples = []
    for _ in range(resamples):
        samples.append(math.exp(statistics.mean(statistics.mean([rng.choice(a) for _ in a] + [rng.choice(b) for _ in b]) for a, b in strata)))
    samples.sort()
    return center, [samples[int(.025 * resamples)], samples[min(resamples - 1, int(.975 * resamples))]]


def elf_symbol_and_bytes(data, symbol, address=None, length=0):
    require(data[:6] == b"\x7fELF\x02\x01", "Expected little-endian ELF64")
    shoff = struct.unpack_from("<Q", data, 40)[0]
    shsize, shcount = struct.unpack_from("<HH", data, 58)
    sections = [struct.unpack_from("<IIQQQQIIQQ", data, shoff + index * shsize) for index in range(shcount)]
    found = None
    for section in sections:
        if section[1] != 2:
            continue
        strings = sections[section[6]]
        names = data[strings[4]:strings[4] + strings[5]]
        for offset in range(section[4], section[4] + section[5], section[9]):
            name, _, _, _, value, _ = struct.unpack_from("<IBBHQQ", data, offset)
            end = names.find(b"\0", name)
            if names[name:end].decode(errors="replace") == symbol:
                found = value
    require(found is not None, "ELF symbol absent: " + symbol)
    if address is None:
        return found, b""
    phoff = struct.unpack_from("<Q", data, 32)[0]
    phsize, phcount = struct.unpack_from("<HH", data, 54)
    for index in range(phcount):
        segment = struct.unpack_from("<IIQQQQQQ", data, phoff + index * phsize)
        if segment[0] == 1 and segment[3] <= address and address + length <= segment[3] + segment[5]:
            offset = segment[2] + address - segment[3]
            return found, data[offset:offset + length]
    raise ValueError("ELF address is outside mapped file bytes")


def audit_periods(text, audit, binary):
    samples = []
    for record in text.decode().strip().split("\n\n"):
        lines = record.splitlines()
        header = re.search(r":\s+(\d+)\s+cycles:u:", lines[0])
        require(header is not None, "Unparsed perf sample header")
        frames, physical = [], []
        for line in lines[1:]:
            match = re.match(r"\s+[0-9a-fA-F]+\s+(.+?)\s+\((.*?)\)\s*$", line)
            require(match is not None, "Unparsed perf frame")
            symbol = re.sub(r"\+0x[0-9a-fA-F]+$", "", match[1])
            frames.append(symbol)
            if match[2] != "inlined":
                physical.append(symbol)
        require(bool(physical), "Perf sample lacks physical self")
        samples.append((int(header[1]), physical[0], frames))
    require(len(samples) == audit["sampling"]["all_samples"] == 1917 and sum(p for p, _, _ in samples) == audit["sampling"]["all_period"] == 18438825507, "Perf totals differ")
    generic = audit["coverage"]["generic_payload_symbol_seen"]
    for scope in audit["scopes"]:
        if scope["name"] == "strict_public_root_unavailable":
            selected = [(p, self, frames) for p, self, frames in samples if "br.decodeStreamInto" in frames]
        elif scope["name"] == "observed_br_symbol_union":
            selected = [(p, self, frames) for p, self, frames in samples if any(f.startswith("br.") for f in frames)]
        else:
            require(scope["name"] == "observed_generic_payload_root", "Unknown audit scope")
            selected = [(p, self, frames) for p, self, frames in samples if generic in frames]
        denominator = sum(p for p, _, _ in selected)
        require(len(selected) == scope["samples"] and denominator == scope["denominator_period"], "Local perf denominator differs")
        for function in scope["functions"]:
            family = function["symbol_family"]
            match = lambda symbol: symbol == family or symbol.startswith(family + "__anon_")
            selves = [p for p, self, _ in selected if match(self)]
            inclusive = [p for p, _, frames in selected if any(match(frame) for frame in frames)]
            require((len(selves), len(inclusive), sum(selves), sum(inclusive)) ==
                    (function["self_samples"], function["inclusive_samples"], function["self_period"], function["inclusive_period"]), "Perf family attribution differs")
            for key, period in (("self_percent", sum(selves)), ("inclusive_percent", sum(inclusive))):
                expected = 100 * period / denominator if denominator else None
                require(function[key] is None if expected is None else math.isclose(function[key], expected, rel_tol=1e-13), "Perf percentage differs")
    unknown = [(p, frames) for p, _, frames in samples if "[unknown]" in frames]
    observed = audit["coverage"]["annotated_callchains_with_unknown_frame"]
    require(len(unknown) == observed["samples"] and sum(p for p, _ in unknown) == observed["period"], "Unknown-frame scope differs")
    generic_unknown = [(p, frames) for p, frames in unknown if generic in frames]
    observed_generic = audit["coverage"]["generic_payload_callchains_with_unknown_frame"]
    require(len(generic_unknown) == observed_generic["samples"] and sum(p for p, _ in generic_unknown) == observed_generic["period"], "Generic unknown-frame scope differs")
    require(max(len(frames) for _, _, frames in samples) == audit["coverage"]["max_annotated_frames"], "Frame count differs")
    root = audit["coverage"]["public_root_symbol_in_elf"]
    require(elf_symbol_and_bytes(binary, root["symbol"])[0] == int(root["address"], 16), "Public ELF symbol differs")
    wrapper = audit["coverage"]["wide_wrapper_stack_subtraction"]
    value, instruction = elf_symbol_and_bytes(binary, wrapper["symbol"], int(wrapper["instruction_address"], 16), 7)
    require(value == int(wrapper["address"], 16) and instruction == b"\x48\x81\xec\x78\x35\x08\x00", "Wide wrapper prologue differs")
    require(wrapper["bytes"] == 0x83578 == 537976 and audit["sampling"]["user_stack_bytes"] == 16384, "Stack coverage differs")
    return len(samples)


def verify(root, reference_archive, raw_root=None, repo=None, fixture_root=None):
    checksum_path = root / "SHA256SUMS"
    if checksum_path.exists():
        hashes = {}
        for line in checksum_path.read_text().splitlines():
            digest, name = line.split("  ", 1)
            require(name not in hashes and "/" not in name, "Invalid package checksum name")
            hashes[name] = digest
        require(set(hashes) == {p.name for p in root.iterdir() if p.is_file() and p != checksum_path}, "Checksum inventory differs")
        require(all(sha((root / name).read_bytes()) == digest for name, digest in hashes.items()), "Package checksum differs")
    binding = json.loads((root / "archive-bindings.json").read_text())
    archives, raw_files = {}, 0
    for name, record in binding["archives"].items():
        files = unpack(root / name)
        require({name: sha(data) for name, data in files.items()} == record["files"], "Archive member bytes differ: " + name)
        archives[name] = files
        if raw_root and record["origin"] == binding["raw_root"]:
            for path, data in files.items():
                require((raw_root / path).read_bytes() == data, "Original raw bytes differ: " + path)
                raw_files += 1
    pairs = archives["pairs-raw.tar.gz"]
    base = json_file(pairs, "pairs/manifest.json")
    require(base["schema"] == "vort.decode-matrix.v1" and len(base["fixtures"]) == len(base["tasks"]) == 216, "Full matrix schema lost")
    require(base["source"]["revision"] == binding["baseline_revision"] == "5fb4c6957342ba51af6902172af02a5369e020cb", "Wrong baseline revision")
    source = archives["baseline-source.tar.gz"]
    require({name: sha(data) for name, data in source.items()} == base["source"]["sha256"] and len(source) == 2044, "Baseline source differs")
    require(source_digest(base["source"]["sha256"]) == base["source"]["digest"], "Baseline source digest differs")
    selected = base["tasks"][:3]
    keys = [task["fixture"]["key"].replace("/", "_") + "_cold" for task in selected]
    require(set(keys) == {"brotli_mozilla_full_11_cold", "brotli_mozilla_1048576_11_cold", "brotli_mozilla_full_6_cold"}, "Pilot tasks differ")
    require(len({f["key"] for f in base["fixtures"]}) == 216 and all(task["lifecycle"] == "cold" and task["fixture"] in base["fixtures"] for task in base["tasks"]), "Duplicate/mismatched matrix tasks")
    binaries = archives["probe-binaries.tar.gz"]
    require(sha(binaries["baseline/vort-decode-compare"]) == base["probe_sha256"], "Baseline executable differs")
    baseline_rows, groups, baseline_ratios = [], {}, {}
    for key, task in zip(keys, selected):
        row = json_file(pairs, "pairs/rows/" + key + ".json")
        require(row["task"] == task and row["probe"] == json_file(pairs, "pairs/rows/" + key + ".stdout.raw"), "Original stdout differs from full probe JSON")
        require(pairs["pairs/rows/" + key + ".stderr.raw"] == pairs["pairs/rows/" + key + ".stderr.txt"] == b"", "Baseline stderr nonempty")
        require(int(pairs["pairs/rows/" + key + ".rss.txt"]) == row["rss_kib"] > 0, "RSS sidecar differs")
        validate_probe(row["probe"], task, base)
        baseline_rows.append(row)
        group = "brotli/cold/" + task["fixture"]["size"]
        groups.setdefault(group, []).append(row["probe"])
        baseline_ratios[key] = math.exp(statistics.mean(math.log(p["vort_ns"] / p["reference_ns"]) for p in row["probe"]["pairs"]))
    summary = json_file(pairs, "pairs/summary.json")
    require(summary == json.loads((root / "baseline-summary.json").read_text()) and summary["complete"] is False and summary["completed_rows"] == 3 and summary["expected_rows"] == 216, "Partial completion was changed")
    for key, rows in groups.items():
        saved = summary["groups"][key]
        center, ci = bootstrap(rows, saved["seed"], saved["resamples"])
        require(center == saved["time_ratio_geomean"] and ci == saved["ci95"] and saved["rows"] == len(rows), "Baseline fixed-row summary differs")
    original_csv = gzip.decompress((root / "baseline-matrix.csv.gz").read_bytes())
    require(original_csv == pairs["pairs/matrix.csv"] and sha(original_csv) == binding["csv_binding"]["original_sha256"], "Original CSV bytes differ")
    readable_csv = (root / "baseline-matrix.csv").read_bytes()
    require(readable_csv == original_csv.replace(b"\r\n", b"\n") and sha(readable_csv) == binding["csv_binding"]["readable_sha256"], "Readable CSV differs beyond newline normalization")
    csv_rows = list(csv.DictReader(io.StringIO(readable_csv.decode())))
    require(len(csv_rows) == 3, "Readable CSV row count differs")
    for item, row in zip(csv_rows, baseline_rows):
        fixture = row["task"]["fixture"]
        for name in ("codec", "name", "size", "level", "input_bytes", "encoded_bytes"):
            require(item[name] == str(fixture[name]), "CSV fixture field differs")
        require(item["lifecycle"] == "cold" and int(item["rss_kib"]) == row["rss_kib"], "CSV lifecycle/RSS differs")
        for name in ("vort_median_ns", "reference_median_ns"):
            require(float(item[name]) == row["probe"]["summary"][name], "CSV median differs")
        require(float(item["time_ratio"]) == row["probe"]["summary"]["vort_median_ns"] / row["probe"]["summary"]["reference_median_ns"], "CSV median ratio differs")
    host = [json.loads(line) for line in pairs["pairs/host-observations.jsonl"].splitlines()]
    require(len(host) == 3 and all(item["exit"] == 0 and not item["before"]["compilers"] and not item["after"]["compilers"] for item in host), "Baseline host observation differs")
    freeze = archives["candidate-sources.tar.gz"]
    screens, screen_manifest = {}, {}
    for folder, prefix, override in (("cache-screen", "cache-pointer", {"src/br.zig": "cache-pointer-screen-br.zig"}),
                                     ("packed-planes-screen", "packed-planes", {k: "packed-planes-source/" + k for k in ("src/br.zig", "src/br/decoder/packed_aux_lookup.zig", "src/br/decoder/packed_aux_planes.zig")})):
        files = archives[folder + "-raw.tar.gz"]
        manifests = {label: json_file(files, folder + "/" + label + ".manifest.json") for label in ("baseline", "candidate")}
        require(manifests["baseline"]["source"] == base["source"], "Screen baseline source drift")
        merged = dict(source)
        merged.update({name: freeze[path] for name, path in override.items()})
        candidate = manifests["candidate"]
        require({name: sha(data) for name, data in merged.items()} == candidate["source"]["sha256"], "Measured candidate source differs")
        require(source_digest(candidate["source"]["sha256"]) == candidate["source"]["digest"] and sha(binaries[prefix + "/vort-decode-compare"]) == candidate["probe_sha256"], "Candidate source/probe digest differs")
        events = json_file(files, folder + "/events.json")
        require(len(events) == 24, "Incomplete screen events")
        expected_order = [(key, pair, label) for key in keys for pair in range(4) for label in (("baseline", "candidate") if pair % 2 == 0 else ("candidate", "baseline"))]
        require([(e["key"], e["pair"], e["label"]) for e in events] == expected_order, "Screen child order differs")
        for event in events:
            stem = folder + "/" + event["key"] + "." + str(event["pair"]) + "." + event["label"]
            require(event == json_file(files, stem + ".json") and event["probe"] == json_file(files, stem + ".stdout.raw") and files[stem + ".stderr.raw"] == b"", "Screen raw streams differ")
            require(not event["before"]["compilers"] and not event["after"]["compilers"], "Screen compiler observation changed")
            task = selected[keys.index(event["key"])]
            require(manifests[event["label"]]["config"]["rounds"] == manifests[event["label"]]["config"]["warmup"] == 2, "Wrong screen sampling")
            validate_probe(event["probe"], task, manifests[event["label"]])
        result = {}
        for key in keys:
            ratios, paired_logs = [], []
            for pair in range(4):
                both = {e["label"]: e["probe"] for e in events if e["key"] == key and e["pair"] == pair}
                ratios.append(both["baseline"]["summary"]["vort_median_ns"] / both["candidate"]["summary"]["vort_median_ns"])
                paired_logs.extend(math.log(both["baseline"]["pairs"][i]["vort_ns"] / both["candidate"]["pairs"][i]["vort_ns"]) for i in range(2))
            center = math.exp(statistics.mean(math.log(x) for x in ratios))
            saved = json_file(files, folder + "/" + key + ".summary.json")
            require(saved["speed_ratios"] == ratios and saved["geomean"] == center, "Producer screen summary differs")
            result[key] = {"producer_median_process_pair_geomean": center, "raw_measured_pair_log_geomean": math.exp(statistics.mean(paired_logs))}
        screens[folder] = result
        screen_manifest[folder] = candidate
    perf = archives["perf-recordings.tar.gz"]
    perf_manifest = json_file(perf, "perf/manifest.json")
    require(perf_manifest["source"] == base["source"] and perf_manifest["probe_sha256"] == base["probe_sha256"] and len(perf_manifest["records"]) == 3, "Perf epoch binding differs")
    runners = archives["runners-diagnostics.tar.gz"]
    require(sha(runners["profile_calls.py"]) == perf_manifest["script_sha256"], "Perf runner differs")
    for key, task in zip(keys, selected):
        record = json_file(perf, "perf/" + key + ".json")
        require(record in perf_manifest["records"] and record["task"] == task and record["exit"] == 0, "Perf record identity differs")
        require(record["probe"] == json_file(perf, "perf/" + key + ".stdout.raw") and sha(perf["perf/" + key + ".data"]) == record["data_sha256"], "Perf recording/stdout differs")
        validate_probe(record["probe"], task, base)
        require("dwarf,16384" in record["argv"] and "499" in record["argv"] and "cycles:u" in record["argv"] and not record["before"]["compilers"] and not record["after"]["compilers"], "Perf sampling policy differs")
    header_counts = {}
    for task in selected:
        fixture = task["fixture"]
        stem = "brotli_mozilla_" + fixture["size"] + "_" + str(fixture["level"])
        header = json_file(runners, stem + ".headers.json")
        require(header["wire_sha256"] == fixture["encoded_sha256"] and header["plain_sha256"] == fixture["input_sha256"] and header["wire_bytes"] == fixture["encoded_bytes"] and header["plain_bytes"] == fixture["input_bytes"], "Header fixture differs")
        require(header["iterations"] == 2 and header["validation"]["output_written"] == fixture["input_bytes"] and header["validation"]["outside_timing"] is True, "Header diagnostic scope differs")
        require(all(header["validation"][k] is True for k in ("output_matches_plain", "wire_guards", "output_guards", "wire_unchanged")), "Header validation absent")
        aggregate = header["profile"]["aggregate"]
        require(aggregate["compressed_meta_block_count"] == 2 * header["compressed_headers_per_stream"] and aggregate["input_bits"] == 2 * header["compressed_header_bits_per_stream"], "Header aggregate incomplete")
        require(header["profile"]["outer_stage_sum_ns"] == sum(aggregate[k] for k in ("block_switch_ns", "context_map_ns", "literal_tree_ns", "command_tree_ns", "distance_tree_ns")), "Nested clocks wrongly added")
        require(header["interpretation"]["whole_codec_total_time_measured"] is False and header["interpretation"]["public_payload_route_identified"] is False and runners[stem + ".headers.stderr"] == b"", "Header diagnostic promoted to payload timing")
        header_counts[stem] = header["compressed_headers_per_stream"]
    audit = json_file(perf, "perf/root-attribution-audit.json")
    require(audit == json.loads((root / "root-attribution-audit.json").read_text()) and audit["source"]["source_digest"] == base["source"]["digest"] and audit["source"]["probe_sha256"] == base["probe_sha256"], "Audit epoch differs")
    for name, digest in audit["artifacts"].items():
        require(sha(perf["perf/" + Path(name).name]) == digest, "Audit input hash differs")
    audit_samples = audit_periods(perf["perf/full-q11-stacks.txt"], audit, binaries["baseline/vort-decode-compare"])
    require(b"Total Lost Samples: 0" in perf["perf/full-q11-symbols.txt"] and audit["sampling"]["reported_lost_samples"] == 0, "Lost-sample report differs")
    validation = archives["validation-supplement.tar.gz"]
    require(b"8/8 steps succeeded; 3/3 tests passed" in validation["final-header-build.log"], "Header final build proof differs")
    alias = json_file(validation, "header-alias-smoke.json")
    require(sha(validation["header-validation/vort-br-header-profile"]) == alias["probe_sha256"] and len(alias["cases"]) == 5, "Post-timing header probe differs")
    require({c["target_kind"] for c in alias["cases"]} == {"wire", "plain", "hardlink", "symlink", "executable"} and all(c["returncode"] == 2 and c["all_protected_bytes_unchanged"] is True for c in alias["cases"]), "Alias refusal proof differs")
    safe = json_file(validation, "payload-validation/release-safe-receipt.json")
    require(safe["returncode"] == 0 and safe["timing_evidence"] is False and safe["measurement_run"] is False, "Safe proof misclassified")
    for name, record in safe["raw_streams"].items():
        data = validation["payload-validation/" + name]
        require(len(data) == record["bytes"] and sha(data) == record["sha256"], "Safe raw stream differs")
    require(b"5/5 steps succeeded; 22/22 tests passed" in validation["payload-validation/release-safe.stderr"], "Safe gate failed")
    before = json_file(validation, "payload-validation/release-safe-source-sha-before.json")["files"]
    after = json_file(validation, "payload-validation/release-safe-source-sha-after.json")["files"]
    require(before == after and len(after) == 4, "Safe source changed")
    for name, record in after.items():
        data = validation["payload-validation/source/" + name]
        require(len(data) == record["bytes"] and sha(data) == record["sha256"], "Safe copied source differs")
    require(after["src/br.zig"]["sha256"] != screen_manifest["packed-planes-screen"]["source"]["sha256"]["src/br.zig"], "Post-timing source was substituted for measured source")
    debug = json_file(validation, "payload-validation/debug-tool-receipt.json")
    require(debug["returncode"] == 0 and debug["timing_evidence"] is False and debug["raw_stdout_saved"] is False and debug["raw_stderr_saved"] is False and debug["rerun"] is False, "Debug transcript scope changed")
    references = unpack(reference_archive, allow_links=True)
    reference_count = 0
    for name, digest in base["references"]["brotli"]["file_sha256"].items():
        require(sha(references["brotli/" + Path(name).name]) == digest, "Reused exact reference library differs")
        reference_count += 1
    git_count, fixture_count = 0, 0
    if repo:
        names = list(source)
        result = subprocess.run(["git", "cat-file", "--batch"], cwd=repo,
                                input="".join(base["source"]["revision"] + ":" + name + "\n" for name in names).encode(), capture_output=True, check=True)
        position = 0
        for name in names:
            end = result.stdout.index(b"\n", position)
            header = result.stdout[position:end].split()
            require(len(header) == 3 and header[1] == b"blob", "Missing baseline Git blob")
            size = int(header[2]); position = end + 1
            require(result.stdout[position:position + size] == source[name], "Baseline Git blob differs")
            position += size + 1; git_count += 1
    if fixture_root:
        unique = {}
        for task in selected:
            for path_key, hash_key in (("input_path", "input_sha256"), ("encoded_input_path", "encoded_sha256")):
                name = Path(task["fixture"][path_key]).name
                unique[name] = task["fixture"][hash_key]
        for name, digest in unique.items():
            require(sha((fixture_root / name).read_bytes()) == digest, "Original fixture bytes differ")
            fixture_count += 1
    if raw_root:
        for name, origin in binding["validation_origins"].items():
            path = raw_root / Path(origin).relative_to(Path(binding["raw_root"])) if origin.startswith(binding["raw_root"] + "/") else Path(origin)
            require(path.read_bytes() == validation[name], "Original validation bytes differ")
            raw_files += 1
    return {"schema": "vort.brotli.mozilla-profile-validation.v1", "valid": True,
            "scope": "independent offline source/probe/raw-statistic/attribution validation; no build, recording, codec call or experiment rerun",
            "baseline_revision": base["source"]["revision"], "baseline_complete": False,
            "baseline_completed_rows": 3, "baseline_expected_rows": 216,
            "baseline_source_files": len(source), "packed_source_files": len(screen_manifest["packed-planes-screen"]["source"]["sha256"]),
            "baseline_per_row_time_ratios": baseline_ratios, "screens": screens,
            "screen_child_events_each": 24, "screen_measured_pairs_each": 48, "screen_warmup_pairs_each": 48,
            "perf_recordings": 3, "perf_audit_samples": audit_samples, "strict_public_root_samples": 0,
            "header_diagnostic_header_counts": header_counts, "header_measurement_exported_identity": False,
            "post_timing_header_parser_tests": 3, "post_timing_header_alias_cases": 5, "post_timing_safe_tests": 22,
            "debug_proof_is_transcript": True, "reference_binaries_verified": reference_count,
            "baseline_git_blobs_verified": git_count, "original_fixture_files_verified": fixture_count,
            "original_raw_files_verified": raw_files, "candidate_merged": False,
            "complete_acceptance_or_industry_leadership_claim": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-archive", type=Path)
    parser.add_argument("--raw-root", type=Path)
    parser.add_argument("--repo", type=Path)
    parser.add_argument("--fixture-root", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    reference = args.reference_archive or root.parents[1] / "modern-decode-current-20261111/reference-libraries.tar.gz"
    print(json.dumps(verify(root, reference, args.raw_root, args.repo, args.fixture_root), indent=2))


if __name__ == "__main__":
    main()
