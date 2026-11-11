#!/usr/bin/env python3
"""Offline verification of frozen reports, binaries and sources; no codec runs."""
import argparse
import gzip
import hashlib
import io
import json
import math
from pathlib import Path
import re
import statistics
import struct
import subprocess
import tarfile
import tempfile

HERE = Path(__file__).resolve().parent
SUM_FIELDS = (
    "static_dictionary_copy_count", "static_dictionary_bytes", "shared_dictionary_copy_count", "shared_dictionary_bytes",
    "command_count", "zero_insert_command_count", "single_literal_insert_command_count", "implicit_distance_command_count",
    "implicit_distance_copy_count", "short_distance_copy_count", "direct_distance_copy_count", "regular_distance_copy_count",
    "copy_length_log2_histogram", "lz77_copy_count", "lz77_copy_bytes", "non_overlapping_lz77_copy_count", "non_overlapping_lz77_copy_bytes",
    "short_non_overlapping_lz77_copy_count", "short_non_overlapping_lz77_copy_bytes", "literal_context_mode_bytes",
)
MAX_FIELDS = (
    "max_lz77_distance", "max_literal_block_types", "max_literal_context_trees", "max_command_block_types",
    "max_distance_block_types", "max_distance_context_trees", "max_distance_postfix_bits", "max_direct_distance_codes",
)
ROWS = (
    ("mozilla.full.q11", "brotli_mozilla_full_11", "brotli/mozilla/full/11", 1),
    ("mozilla.1048576.q11", "brotli_mozilla_1048576_11", "brotli/mozilla/1048576/11", 1),
    ("mozilla.full.q6", "brotli_mozilla_full_6", "brotli/mozilla/full/6", 8),
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def json_data(files, name):
    return json.loads(files[name])


def source_digest(source):
    return sha(json.dumps(source, sort_keys=True).encode())


def unpack(path):
    data = path.read_bytes()
    require(data[:4] == b"\x1f\x8b\x08\x00" and data[4:8] == bytes(4), "Non-deterministic gzip header")
    result = {}
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(data)), mode="r:") as bundle:
        entries = bundle.getmembers()
        require([e.name for e in entries] == sorted({e.name for e in entries}), "Tar names are duplicate or unsorted")
        for entry in entries:
            require(entry.isfile() and not entry.name.startswith("/") and ".." not in Path(entry.name).parts, "Unsafe tar member")
            require(entry.uid == entry.gid == entry.mtime == 0 and entry.uname == entry.gname == "", "Tar metadata changed")
            require(entry.mode in (0o644, 0o755), "Unexpected tar permissions")
            result[entry.name] = bundle.extractfile(entry).read()
    return result


def check_sources(expected, base, overlay=None):
    overlay = overlay or {}
    require(set(overlay) <= set(expected), "Unregistered overlay source")
    for name, digest in expected.items():
        require(name in overlay or name in base, "Source bytes missing: " + name)
        require(sha(overlay.get(name, base.get(name))) == digest, "Source SHA differs: " + name)


def identity_matches(record, data):
    require(record["sha256"] == sha(data) and record["bytes"] == len(data), "Identity differs")


def elf_info(data):
    require(data[:6] == b"\x7fELF\x02\x01", "Expected little-endian ELF64")
    section_offset = struct.unpack_from("<Q", data, 40)[0]
    section_size, section_count, names_index = struct.unpack_from("<HHH", data, 58)
    sections = [struct.unpack_from("<IIQQQQIIQQ", data, section_offset + index * section_size) for index in range(section_count)]
    name_section = sections[names_index]
    section_names = data[name_section[4]:name_section[4] + name_section[5]]
    sizes = {section_names[s[0]:section_names.find(b"\0", s[0])].decode(): s[5] for s in sections}
    symbols = {}
    for section in sections:
        if section[1] != 2:
            continue
        strings = sections[section[6]]
        names = data[strings[4]:strings[4] + strings[5]]
        for position in range(section[4], section[4] + section[5], section[9]):
            name, info, other, index, value, size = struct.unpack_from("<IBBHQQ", data, position)
            if info & 15 == 2 and index and size:
                symbols[names[name:names.find(b"\0", name)].decode()] = (value, size)
    return sizes, symbols


def elf_bytes(data, address, length):
    offset = struct.unpack_from("<Q", data, 32)[0]
    size, count = struct.unpack_from("<HH", data, 54)
    for index in range(count):
        segment = struct.unpack_from("<IIQQQQQQ", data, offset + index * size)
        if segment[0] == 1 and segment[3] <= address and address + length <= segment[3] + segment[5]:
            start = segment[2] + address - segment[3]
            return data[start:start + length]
    raise ValueError("ELF address outside file-backed segments")


def stack_frame(data, address):
    prologue = elf_bytes(data, address, 80)
    found = re.search(b"\x48\x81\xec(.{4})", prologue, re.DOTALL)
    if found:
        return int.from_bytes(found[1], "little")
    found = re.search(b"\x48\x83\xec(.)", prologue, re.DOTALL)
    require(found is not None, "Stack adjustment not found in prologue")
    return found[1][0]


def natural_loop_metrics(path, address, size, head, tail):
    command = ["objdump", "-d", "--no-show-raw-insn", "--start-address=" + hex(address), "--stop-address=" + hex(address + size), str(path)]
    text = subprocess.run(command, check=True, capture_output=True).stdout.decode()
    instructions = {}
    for line in text.splitlines():
        match = re.match(r"\s*([0-9a-f]+):\s+([a-z][\w.]*)\s*(.*?)\s*$", line)
        if match:
            instructions[int(match[1], 16)] = (match[2], match[3].split("#", 1)[0].strip())
    require(instructions and min(instructions) == address and "(bad)" not in text, "Incomplete/misaligned disassembly")
    addresses = sorted(instructions)
    successors, predecessors = {node: set() for node in addresses}, {node: set() for node in addresses}
    for index, node in enumerate(addresses):
        mnemonic, operands = instructions[node]
        target = re.match(r"([0-9a-f]+)\s", operands)
        if mnemonic.startswith("j") and target and int(target[1], 16) in instructions:
            successors[node].add(int(target[1], 16))
        if not mnemonic.startswith(("jmp", "ret")) and mnemonic not in ("ud2", "hlt") and index + 1 < len(addresses):
            successors[node].add(addresses[index + 1])
        for successor in successors[node]:
            predecessors[successor].add(node)
    require(head in successors[tail], "Recorded command backedge differs")
    reachable, pending = set(), [address]
    while pending:
        node = pending.pop()
        if node not in reachable:
            reachable.add(node)
            pending.extend(successors[node])
    # Dominance: removing the loop head must make the backedge tail unreachable.
    seen, pending = set(), [address]
    while pending:
        node = pending.pop()
        if node == head or node in seen:
            continue
        seen.add(node)
        pending.extend(successors[node])
    require(tail not in seen, "Recorded head does not dominate command backedge")
    body, pending = {head, tail}, [tail]
    while pending:
        node = pending.pop()
        for predecessor in predecessors[node]:
            if predecessor in reachable and predecessor not in body:
                body.add(predecessor)
                pending.append(predecessor)
    counts = {"loop_instructions": len(body), "call_sites": 0, "branch_sites": 0, "stack_mov_load_sites": 0, "stack_mov_store_sites": 0}
    for node in body:
        mnemonic, operands = instructions[node]
        counts["call_sites"] += mnemonic.startswith("call")
        counts["branch_sites"] += mnemonic.startswith("j")
        if not mnemonic.startswith("mov"):
            continue
        parts, start, depth = [], 0, 0
        for index, char in enumerate(operands):
            depth += (char == "(") - (char == ")")
            if char == "," and depth == 0:
                parts.append(operands[start:index]); start = index + 1
        parts.append(operands[start:])
        is_stack = lambda part: "(" in part and re.search(r"%r(?:bp|sp)\b", part) is not None
        counts["stack_mov_load_sites"] += len(parts) > 1 and is_stack(parts[0])
        counts["stack_mov_store_sites"] += len(parts) > 1 and is_stack(parts[-1])
    return counts


def validate_codegen(audit, binaries):
    original = binaries["original/semantic-compare"]
    baseline = binaries["original/baseline-compare"]
    cold = binaries["cold-fallback-v2/semantic-compare"]
    require(audit["original"]["baseline_sha256"] == sha(baseline) and audit["original"]["candidate_sha256"] == sha(original), "Original codegen binary differs")
    require(audit["cold_version"]["candidate_sha256"] == sha(cold), "V2 codegen binary differs")
    base_sections, base_symbols = elf_info(baseline)
    sections, symbols = elf_info(original)
    cold_sections, cold_symbols = elf_info(cold)
    require(base_sections[".text"] == audit["original"]["elf_text_baseline"] and sections[".text"] == audit["original"]["elf_text_candidate"], "ELF .text totals differ")
    payload_symbols = [value for name, value in symbols.items() if name.startswith("br.decoder.semantic_wide_payload.payload__anon_")]
    require(len(payload_symbols) == 20 and sum(size for _, size in payload_symbols) == audit["original"]["semantic_payload_text_sum"], "Semantic text total differs")
    setups = [value for name, value in symbols.items() if name.startswith("br.decoder.semantic_wide_payload.setup")]
    require(len(setups) == 1, "Ambiguous semantic setup entity")
    setup = setups[0]
    require(setup[1] == audit["original"]["setup_text_bytes"] and stack_frame(original, setup[0]) == audit["original"]["setup_sub_rsp_bytes"], "Setup text/frame differs")
    anchors = (("baseline_generic", "br.processWideExternalLiteralLookupCompressedPayloadNative__anon_37334", baseline, base_symbols, 0x10ef608, 0x10efeda),
               ("p3_signed", "br.decoder.semantic_wide_payload.payload__anon_52227", original, symbols, 0x1106445, 0x1107736),
               ("p0_utf8", "br.decoder.semantic_wide_payload.payload__anon_52209", original, symbols, 0x111bdb6, 0x111d05c))
    with tempfile.TemporaryDirectory(prefix="vort-static-codegen-") as temporary:
        for name, symbol, data, table, head, tail in anchors:
            address, size = table[symbol]
            expected = audit["original"][name]
            require(size == expected["text_bytes"] and stack_frame(data, address) == expected["sub_rsp_bytes"], "Original payload text/frame differs")
            path = Path(temporary) / name
            path.write_bytes(data)
            metrics = natural_loop_metrics(path, address, size, head, tail)
            require(all(metrics[field] == expected[field] for field in metrics), "Natural-loop static counts differ: " + name + " " + str(metrics))
    expected = audit["cold_version"]["p3_signed"]
    address, size = cold_symbols["br.decoder.semantic_wide_payload." + expected["symbol"]]
    require(address == int(expected["address"], 16) and size == expected["text_bytes"] and stack_frame(cold, address) == expected["sub_rsp_bytes"], "V2 payload text/frame differs")
    return {"original_payloads_checked": 3, "v2_payloads_checked": 1, "scope": "Static ELF and complete entity disassembly only; not dynamic counts/cycles/spill frequency"}


def validate_meta_counts(whole, meta, ignored_copies):
    summary, records = whole["summary"], meta["records"]
    require(len(records) == summary["compressed_meta_block_count"], "Meta count differs")
    require(all(record["kind"] == "compressed" for record in records), "Unexpected diagnostic record kind")
    position = 0
    for index, record in enumerate(records):
        require(record["meta_block_index"] == index and record["decoded_start"] == position, "Decoded ranges are not contiguous")
        require(record["header_start"] <= record["compressed_header_start"] <= record["payload_start"] <= record["payload_end"], "Bit ranges are unordered")
        require(record["payload_end"] <= whole["wire_bytes"] * 8, "Payload range exceeds physical wire")
        stats = record["stats"]
        require(set(stats) == set(SUM_FIELDS) | set(MAX_FIELDS) | {"max_wire_distance"}, "Unexpected stats schema")
        produced = stats["lz77_copy_bytes"] + stats["static_dictionary_bytes"] + stats["shared_dictionary_bytes"] + sum(stats["literal_context_mode_bytes"])
        require(produced == record["decoded_end"] - position, "Per-meta decoded byte accounting differs")
        position = record["decoded_end"]
    require(position == whole["plain_bytes"], "Meta output does not cover plain")
    for field in SUM_FIELDS:
        values = [record["stats"][field] for record in records]
        aggregate = [sum(column) for column in zip(*values)] if isinstance(values[0], list) else sum(values)
        require(aggregate == summary[field], "Meta sum differs: " + field)
    for field in MAX_FIELDS:
        require(max(record["stats"][field] for record in records) == summary[field], "Meta max differs: " + field)
    copies = sum(summary[field] for field in ("implicit_distance_copy_count", "short_distance_copy_count", "direct_distance_copy_count", "regular_distance_copy_count"))
    require(copies == summary["lz77_copy_count"] + summary["static_dictionary_copy_count"] + summary["shared_dictionary_copy_count"], "Applied copy types differ")
    require(sum(summary["copy_length_log2_histogram"]) == summary["command_count"], "Command shape histogram differs")
    require(summary["command_count"] - copies == ignored_copies, "Ignored terminal-copy difference changed")
    return {"records": len(records), "commands": summary["command_count"], "applied_copies": copies,
            "ignored_copies": ignored_copies, "max_wire_distance": max(r["stats"]["max_wire_distance"] for r in records),
            "max_lz77_distance": summary["max_lz77_distance"]}


def validate_probe(probe, task, manifest, smoke=False):
    fixture = task["fixture"]
    require(probe["schema"] == "vort.decode-compare.v1" and probe["codec"] == "brotli", "Unexpected timed probe schema")
    require(probe["lifecycle"] == "cold" and probe["lifecycle_match"] == "matched-cold", "Wrong lifecycle")
    require(probe["vort_api"] == "brDecodeStreamInto" and probe["reference_api"] == "BrotliDecoderDecompress;one-shot-state-and-internal-heap-per-call", "Wrong APIs")
    for field in ("input_path", "encoded_input_path", "input_bytes", "encoded_bytes", "input_sha256", "encoded_sha256"):
        require(probe[field] == fixture[field], "Timed fixture differs: " + field)
    refs = manifest["references"]["brotli"]
    paths = [refs[role] for role in ("encoder", "decoder", "common")]
    require(probe["reference_paths"] == paths and probe["reference_version"] == refs["version"] == "1.2.0", "Reference differs")
    mapped = {p for p in probe["loaded_shared_library_paths"] if Path(p).name.startswith(("libbrotlienc.so", "libbrotlidec.so", "libbrotlicommon.so"))}
    require(mapped == set(paths), "Reference closure differs")
    require(probe["brotli_encoder_abi_version"] == probe["brotli_decoder_abi_version"] == 0x1002000, "Reference ABI differs")
    require(probe["alignment"] == {"guard_bytes": 64, "input_mod64": 0, "encoded_mod64": 0, "vort_output_mod64": 0, "reference_output_mod64": 0}, "Alignment differs")
    require(probe["exact_consumption"] == {"vort": False, "reference": False}, "Unrecorded exact consumption claimed")
    for field in ("every_iteration_count", "full_output_per_batch", "guards_per_batch", "input_unchanged_per_batch"):
        require(probe["validation"][field] is True, "Validation absent: " + field)
    require(probe["validation"]["exact_consumption_per_batch"] is False, "Exact consumption scope differs")
    config, host = manifest["config"], manifest["environment"]
    expected_provenance = {"executable_sha256": manifest["probe_sha256"], "optimize": "ReleaseFast", "zig_version": "0.16.0",
                           "target_arch": "x86_64", "target_os": "linux", "target_abi": "gnu", "target_cpu": config["target_cpu"],
                           "cpu_model": host["cpu_model"], "cpu_affinity": "15", "affinity_cpu_count": 1, "benchmark_threads": 1, "codec_thread_policy": "single"}
    for field, expected in expected_provenance.items():
        require(probe["provenance"][field] == expected, "Provenance differs: " + field)
    iterations, warmup = (1, 0) if smoke else (task["iterations"], 2)
    require(probe["iterations"] == iterations and probe["rounds"] == 2 and probe["warmup"] == warmup, "Effective batch policy differs")
    for field, first_id, count in (("warmup_pairs", 0, warmup), ("pairs", warmup, 2)):
        require(len(probe[field]) == count, "Incomplete raw batches")
        for index, pair in enumerate(probe[field]):
            pair_id = first_id + index
            require(pair["pair_id"] == pair_id and pair["first"] == ("vort" if pair_id % 2 == 0 else "reference"), "Batch order differs")
            require(pair["vort_mix"] == pair["reference_mix"] == iterations * (fixture["input_bytes"] + fixture["input_first_byte"]), "Batch output mix differs")
            require(all(type(pair[side + "_ns"]) is int and pair[side + "_ns"] > 0 for side in ("vort", "reference")), "Invalid raw duration")
    for side in ("vort", "reference"):
        require(statistics.median(pair[side + "_ns"] for pair in probe["pairs"]) == probe["summary"][side + "_median_ns"], "Median differs from timed batches")


def validate_screen(name, files, manifests, selected):
    events = json_data(files, name + "/events.json")
    require(len(events) == 24, "Expected three rows, four process pairs and 24 children")
    tasks = {task["fixture"]["key"]: task for task in manifests["baseline"]["tasks"]}
    result, cursor = {}, 0
    for _, stem, fixture_key, _ in ROWS:
        ratios = []
        task = tasks[fixture_key]
        require(task["fixture"] == selected[fixture_key], "Task fixture differs")
        key = stem + "_cold"
        for pair in range(4):
            medians = {}
            order = ("baseline", "candidate") if pair % 2 == 0 else ("candidate", "baseline")
            for label in order:
                path = name + "/" + key + "." + str(pair) + "." + label
                event = json_data(files, path + ".json")
                require(event == events[cursor], "Aggregate events differ from original per-child JSON")
                cursor += 1
                require(event["key"] == key and event["pair"] == pair and event["label"] == label, "Process pairing differs")
                require(event["probe"] == json_data(files, path + ".stdout.raw"), "Timed stdout bytes and event JSON differ")
                require(event["argv"][:3] == ["taskset", "-c", "15"] and event["argv"][3] == manifests[label]["probe"], "Wrong child command")
                require(not event["before"]["compilers"] and not event["after"]["compilers"], "Compiler observed during screen")
                validate_probe(event["probe"], task, manifests[label])
                medians[label] = statistics.median(sample["vort_ns"] for sample in event["probe"]["pairs"])
            ratios.append(medians["baseline"] / medians["candidate"])
        summary = json_data(files, name + "/" + key + ".summary.json")
        geomean = math.exp(statistics.mean(math.log(ratio) for ratio in ratios))
        require(ratios == summary["speed_ratios"] and math.isclose(geomean, summary["geomean"], rel_tol=0, abs_tol=1e-15), "Speed geomean differs from original raw Vort batches")
        result[fixture_key] = {"process_pair_speed_ratios": ratios, "candidate_over_baseline_throughput_geomean": geomean}
    return result


def verify(package, original_bytes=False, git_repo=None, external_fixtures=False):
    bindings = json.loads((package / "archive-bindings.json").read_bytes())
    require(bindings["schema"] == "vort.brotli.mozilla-distributions-archive.v1", "Wrong archive schema")
    archives = {}
    for name, record in bindings["archives"].items():
        require(sha((package / name).read_bytes()) == record["sha256"], "Archive SHA differs: " + name)
        files = unpack(package / name)
        require(len(files) == record["members"] and {member: sha(data) for member, data in files.items()} == record["member_sha256"], "Archive members differ: " + name)
        require({member: len(data) for member, data in files.items()} == record["member_bytes"], "Archive lengths differ")
        if original_bytes:
            for member, origin in record["original_paths"].items():
                if not origin.startswith("git:"):
                    require(Path(origin).read_bytes() == files[member], "Original byte copy differs: " + origin)
        archives[name] = files
    base = archives["baseline-source.tar.gz"]
    counts, meta, binaries = (archives[name] for name in ("counts.tar.gz", "meta-blocks.tar.gz", "probe-binaries.tar.gz"))
    freeze = json_data(counts, "counts-source-freeze.json")
    require(len(freeze["baseline_source"]["sha256"]) == 2044, "Counts source registry changed")
    check_sources(freeze["baseline_source"]["sha256"], base)
    tool = counts["counts/frozen-tool/payload_counts.zig"]
    require(sha(tool) == freeze["tool_sha256"], "Frozen counter tool differs")
    for phase in ("compile", "diagnostic"):
        before = json_data(counts, "counts/" + phase + "-source-sha-before.json")
        after = json_data(counts, "counts/" + phase + "-source-sha-after.json")
        require(before["baseline_source_sha256"] == after["baseline_source_sha256"] == freeze["baseline_source"]["sha256"], "Counter source drift recorded")
        require(before["tool"] == after["tool"] and after["tool"]["sha256"] == freeze["tool_sha256"], "Counter tool drift recorded")
        identity_matches(after["probe"], binaries["counts/payload-counts"])
        if phase == "diagnostic":
            require(before["probe"] == after["probe"], "Counter executable changed during diagnostic")
    for prefix in ("build", "parameter-tests"):
        receipt = json_data(counts, "counts/" + prefix + "-receipt.json")
        require(receipt["returncode"] == 0, "Counter compile/test failed")
        mode = "-OReleaseFast" if prefix == "build" else "-OReleaseSafe"
        require(receipt["argv"].count(mode) == 3 and receipt["argv"].count(freeze["target"]) == 3 and receipt["argv"].count(freeze["cpu"]) == 3, "Counter per-module build flags differ")
        for stream in ("stdout", "stderr"):
            identity_matches(receipt["raw_" + stream], counts["counts/" + prefix + "." + stream])
    selected = {fixture["key"]: fixture for fixture in json_data(counts, "counts/selected-fixtures-used.json")}
    require(len(selected) == 3, "Unexpected selected fixtures")
    meta_freeze = json_data(meta, "meta-blocks/source-freeze.json")
    require(len(meta_freeze["source"]["sha256"]) == 2047, "Meta source registry changed")
    require(source_digest(meta_freeze["source"]["sha256"]) == meta_freeze["source"]["digest"], "Meta source digest differs")
    overlay = {name.removeprefix("meta-blocks/source/"): data for name, data in meta.items() if name.startswith("meta-blocks/source/")}
    check_sources(meta_freeze["source"]["sha256"], base, overlay)
    require(sha(meta["meta_blocks_probe.zig"]) == meta_freeze["probe_source_sha256"], "Meta probe source changed")
    complete = json_data(meta, "meta-blocks/run-complete.json")
    require(complete["source_unchanged"] and complete["probe_unchanged"] and complete["fixtures"] == 3, "Meta source/probe stability absent")
    require(sha(binaries["meta/meta-blocks-probe"]) == complete["probe_sha256"], "Meta executable differs")
    result = {"aggregate_counts": {}, "semantic_screens": {}, "archives": len(archives), "archive_members": sum(map(len, archives.values()))}
    for count_stem, meta_stem, key, ignored in ROWS:
        whole = json_data(counts, "counts/" + count_stem + ".json")
        record = json_data(meta, "meta-blocks/" + meta_stem + ".json")
        fixture = selected[key]
        require(whole["schema"] == "vort.brotli.mozilla-payload-counts.v1" and record["schema"] == "vort.brotli.mozilla-meta-blocks.v1", "Diagnostic report schema differs")
        for field, fixture_field in (("wire_sha256", "encoded_sha256"), ("plain_sha256", "input_sha256"), ("wire_bytes", "encoded_bytes"), ("plain_bytes", "input_bytes")):
            require(whole[field] == record[field] == fixture[fixture_field], "Diagnostic fixture binding differs")
        require(whole["executable_sha256"] == sha(binaries["counts/payload-counts"]) and record["executable_sha256"] == complete["probe_sha256"], "Diagnostic executable differs")
        require(whole["summary"]["decoded_bytes"] == fixture["input_bytes"] and whole["summary"]["input_bytes"] == fixture["encoded_bytes"], "Whole-summary stream lengths differ")
        require(record["window_bits"] == whole["summary"]["window_bits"] and record["replay_history_bytes"] == min(fixture["input_bytes"], (1 << record["window_bits"]) - 16), "Diagnostic replay-window bound differs")
        require(whole["build"]["mode"] == record["build"]["mode"] == "ReleaseFast", "Diagnostic mode differs")
        require(whole["source"]["runtime_source_sha256"] is None, "Counter claims an invented runtime source identity")
        require(all(value is False for value in whole["measurement_scope"].values() if isinstance(value, bool)), "Counter scope changed")
        require(all(record["validation"].values()) and all(value for value in whole["validation"].values() if isinstance(value, bool)), "Diagnostic validation missing")
        require(whole["validation"]["guard_bytes_per_side"] == 64 and whole["validation"]["output_written"] == fixture["input_bytes"], "Guard/size validation differs")
        receipt = json_data(counts, "counts/" + count_stem + "-receipt.json")
        execution = json_data(meta, "meta-blocks/" + meta_stem + ".execution.json")
        require(receipt["returncode"] == execution["returncode"] == 0 and receipt["identities_unchanged"], "Diagnostic child failed or changed inputs")
        require(receipt["inputs_before"] == receipt["inputs_after"], "Diagnostic identities changed")
        require(execution["probe_sha256"] == complete["probe_sha256"] and execution["source_digest"] == meta_freeze["source"]["digest"], "Meta execution epoch differs")
        require(not execution["before"]["compilers"] and not execution["after"]["compilers"], "Compiler observed around instrumented diagnostic")
        for stream in ("stdout", "stderr"):
            identity_matches(receipt["raw_" + stream], counts["counts/" + count_stem + "." + stream])
            require(meta["meta-blocks/" + meta_stem + "." + stream + ".raw"] == b"", "Meta file-output child stream differs")
        result["aggregate_counts"][key] = validate_meta_counts(whole, record, ignored)
    for screen in bindings["screens"]:
        name = screen["name"]
        files, source = archives[screen["screen_archive"]], archives[screen["source_archive"]]
        manifests = {label: json_data(files, name + "/" + label + ".manifest.json") for label in ("baseline", "candidate")}
        for label, manifest in manifests.items():
            recorded_revision = bindings["base_revision"] if label == "baseline" else screen.get("candidate_revision", bindings["base_revision"])
            require(manifest["source"]["revision"] == recorded_revision, "Recorded screen revision changed")
            require(source_digest(manifest["source"]["sha256"]) == manifest["source"]["digest"], "Screen source digest differs")
            overlay = {} if label == "baseline" else {path.removeprefix(name + "/"): data for path, data in source.items() if path.startswith(name + "/")}
            check_sources(manifest["source"]["sha256"], base, overlay)
            require(sha(binaries[screen[label + "_binary"]]) == manifest["probe_sha256"], "Frozen screen executable differs")
        result["semantic_screens"][name] = validate_screen(name, files, manifests, selected)
    original = result["semantic_screens"]["original"]
    expected = (0.9904879980, 0.9929737832, 0.9604926771)
    require(all(round(original[row[2]]["candidate_over_baseline_throughput_geomean"], 10) == value for row, value in zip(ROWS, expected)), "Original negative screen changed")
    proof = archives["correctness-supplement.tar.gz"]
    helper = json_data(proof, "semantic-helper/validation-summary.json")
    identity_matches(helper["helper"], proof["semantic-helper/semantic_command.zig"])
    for mode in ("debug", "releasesafe"):
        receipt = json_data(proof, "semantic-helper/" + mode + "-receipt.json")
        require(receipt["returncode"] == 0 and receipt["source_unchanged"] and receipt["source_before"] == receipt["source_after"], "Semantic helper correctness failed")
        for stream in ("stdout", "stderr"):
            identity_matches(receipt["raw_" + stream], proof["semantic-helper/" + mode + "." + stream])
    oracle = json_data(proof, "actual-kernel/receipt.json")
    for run in oracle["runs"]:
        data = proof["actual-kernel/" + Path(run["log"]).name]
        require(run["returncode"] == 0 and run["tests_passed"] == 23 and sha(data) == run["log_sha256"] and len(data) == run["log_bytes"], "Actual kernel correctness receipt differs")
    for name, available in bindings["kernel_oracle_source_copies_available"].items():
        if available:
            require(sha(proof["actual-kernel/source/" + name]) == oracle["source_sha256_after_final_gates"][name], "Correctness source copy differs")
    weights = json_data(proof, "final-diagnostics/route-weights.json")
    for weight in weights:
        row = next(row for row in ROWS if row[2] == weight["fixture"])
        records = json_data(meta, "meta-blocks/" + row[1] + ".json")["records"]
        groups = {}
        for record in records:
            group = groups.setdefault(record["route"], {"blocks": 0, "decoded_bytes": 0, "commands": 0})
            group["blocks"] += 1
            group["decoded_bytes"] += record["decoded_end"] - record["decoded_start"]
            group["commands"] += record["stats"]["command_count"]
        decoded, commands = (sum(group[field] for group in groups.values()) for field in ("decoded_bytes", "commands"))
        for group in groups.values():
            group["decoded_share"] = group["decoded_bytes"] / decoded
            group["command_share"] = group["commands"] / commands
        require(groups == weight["groups"] and commands / decoded == weight["commands_per_decoded_byte"], "Route integer/share weights differ")
    result["route_weight_fixtures"] = len(weights)
    result["codegen"] = validate_codegen(json_data(proof, "final-diagnostics/codegen-audit.json"), binaries)
    wasi = json_data(proof, "final-diagnostics/diagnostic-wasi.stdout")
    require(wasi["exit_code"] == 0 and wasi["wasm_sha256"] == sha(proof["final-diagnostics/diagnostic-contracts.wasm"]), "WASI executable/result differs")
    require(b"All 23 tests passed." in proof["final-diagnostics/diagnostic-wasi.stderr"], "Missing actual WASI diagnostic contract completion")
    require(proof["final-diagnostics/diagnostic-contracts.wasm"][:8] == b"\0asm\x01\0\0\0", "Invalid WASM header")
    require(b"7/7 steps succeeded" in proof["final-diagnostics/main-diagnostics-wasm-gate.log"], "Missing public WASI gate")
    result["wasi_diagnostic_tests_passed"] = 23
    smoke = archives["brotli-smoke.tar.gz"]
    smoke_manifest = json_data(smoke, "smoke/manifest.json")
    shared = next(screen for screen in bindings["screens"] if screen["name"] == "shared-dispatch")
    shared_files = archives[shared["screen_archive"]]
    shared_manifest = json_data(shared_files, "shared-dispatch/candidate.manifest.json")
    require(smoke_manifest["source"] == shared_manifest["source"] and smoke_manifest["probe_sha256"] == shared_manifest["probe_sha256"], "Smoke and shared-dispatch identities differ")
    smoke_complete = json_data(smoke, "smoke/complete.json")
    require(smoke_complete["rows"] == 72 and all(smoke_complete[field] for field in ("valid", "source_unchanged", "probe_unchanged")), "Smoke is incomplete")
    smoke_tasks = [task for task in smoke_manifest["tasks"] if task["fixture"]["codec"] == "brotli"]
    require(len(smoke_tasks) == 72, "Smoke fixture set differs")
    for task in smoke_tasks:
        fixture = task["fixture"]
        stem = "smoke/brotli_" + fixture["name"] + "_" + fixture["size"] + "_" + str(fixture["level"]) + "_cold"
        record = json_data(smoke, stem + ".json")
        require(record["returncode"] == 0 and record["probe"] == json_data(smoke, stem + ".stdout.raw"), "Smoke raw report/returncode differs")
        require(smoke[stem + ".stderr.raw"] == b"", "Unexpected smoke stderr")
        arguments = record["argv"]
        for flag, value in (("--iterations", "1"), ("--rounds", "2"), ("--warmup", "0")):
            require(arguments[arguments.index(flag) + 1] == value, "Smoke effective argv differs")
        validate_probe(record["probe"], task, smoke_manifest, smoke=True)
    result["brotli_smoke"] = {"rows": 72, "calls_per_implementation": 2, "warmup_calls": 0, "scope": "correctness/executability only; no ranking or throughput ratchet"}
    reuse = json.loads((package / "reference-reuse.json").read_bytes())
    repo = package.parents[3]
    for name in ("modern_manifest", "modern_reference_reuse", "reference_libraries"):
        require(sha((repo / reuse[name]["path"]).read_bytes()) == reuse[name]["sha256"], "Prior reused package changed")
    prior = json.loads(gzip.decompress((repo / reuse["modern_manifest"]["path"]).read_bytes()))
    prior_fixtures = {fixture["key"]: fixture for fixture in prior["fixtures"]}
    require(reuse["selected_fixtures"] == list(selected.values()), "Selected reuse metadata differs")
    require(all(prior_fixtures[key] == fixture for key, fixture in selected.items()), "Prior frozen fixture differs")
    require(reuse["brotli_reference"] == prior["references"]["brotli"], "Prior reference metadata differs")
    with tarfile.open(repo / reuse["reference_libraries"]["path"], "r:gz") as bundle:
        for path, digest in reuse["brotli_reference"]["file_sha256"].items():
            require(sha(bundle.extractfile("brotli/" + Path(path).name).read()) == digest, "Reused Brotli SO differs")
    if external_fixtures:
        for fixture in selected.values():
            require(sha(Path(fixture["input_path"]).read_bytes()) == fixture["input_sha256"] and sha(Path(fixture["encoded_input_path"]).read_bytes()) == fixture["encoded_sha256"], "External fixture bytes differ")
    if git_repo:
        process = subprocess.Popen(["git", "cat-file", "--batch"], cwd=git_repo, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        for archive_name, files in archives.items():
            for member, origin in bindings["archives"][archive_name]["original_paths"].items():
                if not origin.startswith("git:"):
                    continue
                _, revision, path = origin.split(":", 2)
                process.stdin.write((revision + ":" + path + "\n").encode())
                process.stdin.flush()
                header = process.stdout.readline().split()
                require(len(header) == 3 and header[1] == b"blob", "Pinned Git blob missing")
                require(process.stdout.read(int(header[2])) == files[member] and process.stdout.read(1) == b"\n", "Pinned Git blob differs")
        process.stdin.close()
        require(process.wait() == 0, "Git validation failed")
    result["scope"] = "Offline archive/source/report/aggregate verification only; no codec execution, timing rerun, or production heap/leadership claim"
    result["original_byte_copies_checked"] = original_bytes
    result["pinned_git_blobs_checked"] = bool(git_repo)
    result["external_fixture_bytes_checked"] = external_fixtures
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=HERE)
    parser.add_argument("--original-bytes", action="store_true", help="also compare still-retained raw origins by bytes")
    parser.add_argument("--git-repo", type=Path, help="also compare baseline archive against pinned immutable Git blobs")
    parser.add_argument("--external-fixtures", action="store_true", help="hash original fixture payloads without decoding")
    parser.add_argument("--receipt", type=Path)
    options = parser.parse_args()
    result = verify(options.package.resolve(), options.original_bytes, options.git_repo, options.external_fixtures)
    data = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if options.receipt:
        options.receipt.write_text(data)
    print(data, end="")


if __name__ == "__main__":
    main()
