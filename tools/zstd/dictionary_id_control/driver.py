#!/usr/bin/env python3
"""Bounded native/x86 public Dictionary_ID interoperability and control matrix.

Run --preflight first to exercise each encoder API with both flag values and
selector/output failures. The default adds dictionary sets, magicless frames,
known/unknown incremental streams, real/synchronous workers, multi-block data,
and copy-mode complete dictionary controls. Existing libzstd is the independent
producer, fullDict decoder, header/entropy oracle; no reference build is made.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import zlib

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


reference = module("_dict_id_reference_driver", HERE / "reference.py")
fixtures = module("_dict_id_fixtures_driver", HERE / "fixtures.py")
entropy_reference = module("_dict_id_entropy_reference_driver", HERE / "entropy_witness.py")
APIS = ("native_alloc", "native_append", "native_into", "reuse_alloc", "reuse_append",
        "reuse_into", "reuse_scratch", "level_alloc", "level_append", "level_into",
        "incremental", "incremental_parallel", "parallel_alloc", "parallel_append", "parallel_into",
        "seekable_alloc", "seekable_append", "seekable_into", "seekable_reuse_alloc",
        "seekable_reuse_append", "seekable_reuse_into", "seekable_reuse_scratch", "seekable_parallel")


def require(ok, detail):
    if not ok:
        raise AssertionError(detail)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def artifact(path):
    return {"path": str(Path(path).resolve()), "size": Path(path).stat().st_size, "sha256": sha(path)}


def frames(wire, format="standard"):
    """Walk actual frame/block sizes, including seek-table skippable trailers."""
    offset, result = 0, []
    while offset < len(wire):
        if format == "standard" and len(wire) - offset >= 8:
            magic = int.from_bytes(wire[offset:offset + 4], "little")
            if magic & 0xfffffff0 == 0x184d2a50:
                size = int.from_bytes(wire[offset + 4:offset + 8], "little")
                require(offset + 8 + size <= len(wire), "truncated skippable frame")
                offset += 8 + size
                continue
        start = offset
        header = reference.frame_header(wire[start:], format)
        offset += header["header_size"]
        while True:
            require(offset + 3 <= len(wire), "truncated block header")
            block = int.from_bytes(wire[offset:offset + 3], "little")
            offset += 3
            last, kind, size = block & 1, (block >> 1) & 3, block >> 3
            require(kind != 3, "reserved block type")
            offset += 1 if kind == 1 else size
            require(offset <= len(wire), "truncated block")
            if last:
                break
        offset += 4 if header["checksum"] else 0
        require(offset <= len(wire), "truncated checksum")
        data = wire[start:offset]
        result.append({"offset": start, "size": len(data), "header": header,
                       "blocks": reference.entropy_modes(data, format), "wire": data})
        if format == "magicless":
            require(offset == len(wire), "magicless probe must produce one frame")
    require(result, "no data frames")
    return result


def normalized_frame(data, format):
    """Remove just the actual dict ID field and clear its descriptor flag."""
    header = reference.frame_header(data, format)
    descriptor_offset = 4 if format == "standard" else 0
    id_offset = descriptor_offset + 1 + int(not header["single_segment"])
    value = bytearray(data)
    value[descriptor_offset] &= 0xfc
    del value[id_offset:id_offset + header["dictionary_id_size"]]
    return bytes(value)


def zip_archive(wire, payload, path):
    """Wrap a C-produced standard frame in ZIP method 93 for public readers."""
    name = b"dictionary-control.bin"
    crc = zlib.crc32(payload)
    local = struct.pack("<IHHHHHIIIHH", 0x04034b50, 63, 0, 93, 0, 0,
                        crc, len(wire), len(payload), len(name), 0) + name + wire
    central = struct.pack("<IHHHHHHIIIHHHHHII", 0x02014b50, 63, 63, 0, 93, 0, 0,
                          crc, len(wire), len(payload), len(name), 0, 0, 0, 0, 0, 0) + name
    end = struct.pack("<IHHHHIIH", 0x06054b50, 0, 0, 1, 1, len(central), len(local), 0)
    path.write_bytes(local + central + end)
    return path


def encoder_cases(receipt, root, preflight):
    dictionary = receipt["artifacts"]["dictionary"]["path"]
    payloads = dict(receipt["payloads"])
    large = root / "multi-block.payload"
    sample = Path(payloads["entropy-history"]["path"]).read_bytes()
    large.write_bytes((sample * 48)[:48 * 1024])
    payloads["multi-block"] = artifact(large)
    result = []
    for api_index, api in enumerate(APIS):
        seekable = api.startswith("seekable_")
        format = "magicless" if not seekable and api_index % 3 == 1 and not preflight else "standard"
        contexts = [("entropy-history", bool(api_index % 2), format, True, False, False, 3)]
        if not preflight:
            extras = {
                "native_alloc": [("entropy-history", True, "standard", True, False, True, 3)],
                "reuse_scratch": [("entropy-history", False, "magicless", True, False, True, 3)],
                "parallel_alloc": [("multi-block", False, "standard", True, False, False, 3),
                                   ("multi-block", False, "standard", True, True, False, 3)],
                "incremental": [("entropy-history", True, "magicless", False, False, False, 3)],
                "incremental_parallel": [("entropy-history", True, "standard", False, False, False, 3),
                                         ("entropy-history", False, "magicless", False, True, False, 3),
                                         ("multi-block", False, "standard", True, False, False, 3)],
                "seekable_alloc": [("multi-block", True, "standard", True, False, False, 3)],
                "level_alloc": [("history", True, "standard", True, False, False, level) for level in (-3, 0)],
            }
            contexts += extras.get(api, [])
        for index, (payload_name, use_set, format, known, sync, copy_mode, level) in enumerate(contexts):
            group = f"{api}-context{index}-{payload_name}"
            for flag in ((True, False) if preflight else (None, True, False)):
                config = {"operation": "encode", "api": api, "format": format,
                          "dictionary_path": dictionary, "use_dictionary_set": use_set,
                          "known_size": known, "synchronous": sync, "copy_mode": copy_mode,
                          "level": level, "block_size": 4096, "frame_size": 552}
                if flag is not None:
                    config["include_dictionary_id"] = flag
                result.append({"name": group + ("-default" if flag is None else f"-id{int(flag)}"),
                               "group": group, "flag": flag, "payload_name": payload_name,
                               "input_path": payloads[payload_name]["path"], "config": config,
                               "expect": "success"})
        for flag in (False,):
            config = {"operation": "encode", "api": api, "dictionary_path": dictionary,
                      "use_dictionary_set": True, "selector": 0, "include_dictionary_id": flag}
            result.append({"name": f"{api}-zero-selector-id{int(flag)}", "config": config,
                           "input_path": payloads["entropy-history"]["path"], "expect": "NeedDictionary"})
        if api.endswith("into"):
            config = {"operation": "encode", "api": api, "dictionary_path": dictionary,
                      "include_dictionary_id": False, "short_output": True}
            result.append({"name": api + "-short-output", "config": config,
                           "input_path": payloads["entropy-history"]["path"], "expect": "OutputTooSmall",
                           "guard": True})
        if seekable:
            config = {"operation": "encode", "api": api, "dictionary_path": dictionary,
                      "format": "magicless", "include_dictionary_id": False}
            result.append({"name": api + "-magicless-refusal", "config": config,
                           "input_path": payloads["entropy-history"]["path"], "expect": "InvalidBlockPlan"})
    return result


def consumer_cases(receipt, root, preflight):
    result = []
    artifacts = receipt["artifacts"]
    for fixture in receipt["cases"]:
        entropy = fixture["payload_name"] == "entropy-history"
        one_shot = not fixture["streaming"]
        standard = fixture["format"] == "standard"
        if preflight and not (entropy and (one_shot or (standard and not fixture["known_size"]))):
            continue
        api = "decode_incremental" if fixture["streaming"] else "decode_alloc"
        apis = [api]
        if entropy and one_shot and standard:
            apis += ["decode_incremental"]
        for api in apis:
            variants = [("full", artifacts["dictionary"]["path"], False, "success")]
            if api == apis[0] and (not fixture["include_id"] or (entropy and one_shot and standard)):
                variants += [("none", None, False, "refused")]
            if api == apis[0] and entropy and standard and (one_shot or not fixture["known_size"]):
                variants += [("wrong-history", artifacts["wrong_history_dictionary"]["path"], False, "changed")]
                if one_shot or not preflight:
                    variants += [("wrong-tables", artifacts["wrong_entropy_dictionary"]["path"], False, "changed")]
            if not preflight and entropy and one_shot and standard and api == apis[0]:
                variants += [("catalog", artifacts["dictionary"]["path"], True,
                              "success" if fixture["include_id"] else "refused")]
            for label, dictionary, catalog, expected in variants:
                result.append({"name": f"c-{fixture['name']}-{api}-{label}", "config": {
                    "operation": "decode", "api": api, "format": fixture["format"],
                    "dictionary_path": dictionary, "catalog_only": catalog,
                    "expected_output_len": fixture["payload"]["size"], "input_chunk": 3, "output_chunk": 7},
                    "input_path": fixture["wire_path"], "payload_path": fixture["payload_path"], "expect": expected})
        if standard and entropy and (one_shot or (not preflight and not fixture["known_size"])):
            payload = Path(fixture["payload_path"]).read_bytes()
            archive = zip_archive(Path(fixture["wire_path"]).read_bytes(), payload,
                                  root / ("c-" + fixture["name"] + ".zip"))
            for label, dictionary in (("full", artifacts["dictionary"]["path"]), ("none", None)):
                result.append({"name": f"c-{fixture['name']}-zip-reader-{label}", "config": {
                    "operation": "decode", "api": "zip_reader", "dictionary_path": dictionary,
                    "expected_output_len": len(payload), "input_chunk": 3, "output_chunk": 7},
                    "input_path": str(archive), "payload_path": fixture["payload_path"],
                    "expect": "success" if dictionary else "refused"})
    return result


def entropy_witness_cases(root, library, preflight):
    """Generate a fixed archived full-dictionary entropy dependency witness.

    The payload is independently decoded from the libzstd-produced archive.
    Literal-only selects an existing public encoder mode; its default match
    budget remains intact so the first generated sequence section uses the
    initial complete dictionary literal-length FSE table.
    """
    prepared = entropy_reference.prepare(root / "entropy-witness", library)
    dictionary_path, payload_path = prepared["dictionary_path"], prepared["payload_path"]
    provenance = {**prepared, "history": prepared["artifacts"]["history"],
                  "public_encoder": "encodeNativeFrameWithDictionaryAlloc",
                  "controls": {"selection": "literal_only", "content_checksum": False,
                               "match_search_budget": "public default"}}
    result = []
    for format in ("standard", "magicless"):
        group = "generated-entropy-witness-" + format
        for flag in ((True, False) if preflight else (None, True, False)):
            config = {"operation": "encode", "api": "native_alloc", "format": format,
                      "dictionary_path": str(dictionary_path), "literal_only": True, "checksum": False}
            if flag is not None:
                config["include_dictionary_id"] = flag
            result.append({"name": group + ("-default" if flag is None else f"-id{int(flag)}"),
                           "group": group, "flag": flag, "payload_name": "archived-entropy-witness",
                           "input_path": str(payload_path), "config": config, "expect": "success",
                           "entropy_witness": provenance})
    return result, provenance


def invoke(root, label, executable, bits, case, library, fixture_receipt):
    name = label + "-" + case["name"]
    output = root / (name + ".output")
    output.unlink(missing_ok=True)
    config_path = root / (name + ".config.json")
    config_path.write_text(json.dumps(case["config"], sort_keys=True) + "\n")
    command = [str(executable.resolve()), str(Path(case["input_path"]).resolve()),
               str(output.resolve()), str(config_path.resolve())]
    with (root / (name + ".stderr.log")).open("wb") as stderr:
        execution = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=stderr, timeout=120)
    require(execution.returncode == 0, (name, execution.returncode, stderr.name))
    report = json.loads(execution.stdout)
    require(report["pointer_bits"] == bits, (name, "pointer width"))
    require(report["state"]["borrowed_input_and_dictionary_preserved"], (name, "borrowed data"))
    expectation = case["expect"]
    payload = Path(case.get("payload_path", case["input_path"])).read_bytes()
    if expectation == "success":
        require(report["error"] is None and output.is_file(), (name, report["error"]))
    elif expectation == "changed":
        require(report["error"] is not None or output.read_bytes() != payload, (name, "negative dictionary had no effect"))
    elif expectation == "refused":
        require(report["error"] is not None, (name, "missing dictionary accepted"))
    else:
        require(report["error"] == expectation, (name, expectation, report["error"]))
    if case.get("guard"):
        require(report["state"]["caller_guards_verified"], (name, "short output changed destination"))
    validation = {}
    if report["error"] is None:
        require(report["output_bytes"] == output.stat().st_size and report["output_sha256"] == sha(output), (name, "actual artifact"))
        if case["config"]["operation"] == "decode":
            if expectation == "success":
                require(output.read_bytes() == payload, (name, "public consumer payload"))
            validation["equals_payload"] = output.read_bytes() == payload
        else:
            require(report["state"]["bound_verified"] and report["state"]["self_decode_verified"], (name, "bound/round trip"))
            dictionary = Path(case["config"]["dictionary_path"]).read_bytes()
            wire = output.read_bytes()
            format = case["config"]["format"]
            split = frames(wire, format)
            include_id = case["flag"] is not False
            expected_id = library.dictionary_id(dictionary) if include_id else 0
            for frame in split:
                require(frame["header"]["dictionary_id"] == expected_id, (name, "wire dictionary ID", frame["header"]))
                if not include_id:
                    require(frame["header"]["dictionary_id_flag"] == 0, (name, "dict field was not omitted"))
            decoded = library.decode(wire, dictionary, format=format, input_chunk_size=3)
            require(decoded == payload, (name, "independent fullDict decode"))
            validation = {"full_dictionary_decode": True, "decoded_sha256": hashlib.sha256(decoded).hexdigest(),
                          "data_frames": [{k: v for k, v in frame.items() if k != "wire"} for frame in split]}
            if case.get("entropy_witness"):
                first = split[0]["blocks"][0]
                require(first.get("sequence_count", 0) > 0 and
                        first.get("sequence_modes", {}).get("literal_length") == 3,
                        (name, "generated first sequence must reuse the initial full-dictionary LL table", first))
                # Clear only the ID field for this control so a tagged frame
                # cannot fail merely because RAW history has no dictionary ID.
                raw_input = normalized_frame(wire, format)
                control = entropy_reference.inspect_generated(raw_input, dictionary, library,
                                                              format=format, payload=payload)
                require(control["dictionary_entropy_used"] and not control["raw_history"]["accepted"],
                        (name, "same-history RAW-only control did not prove initial entropy dependency", control))
                require(control["raw_history"]["history_sha256"] == case["entropy_witness"]["history"]["sha256"],
                        (name, "RAW decoder history differs from complete dictionary history"))
                validation["generated_entropy_witness"] = {
                    "first_block": first, "initial_literal_length_table_required": True,
                    "full_dictionary_id": library.dictionary_id(dictionary),
                    "full_dictionary_decode_equals_payload": True,
                    "same_history_raw_only_refused": True, "raw_only_error": control["raw_history"]["error"],
                    "raw_dictionary_content_type": 1, "raw_input_dictionary_id": 0,
                    "raw_input_sha256": hashlib.sha256(raw_input).hexdigest(),
                    "raw_history": case["entropy_witness"]["history"],
                    "entropy_control": control,
                    "source": case["entropy_witness"]}
            api, config = case["config"]["api"], case["config"]
            if api.startswith("parallel_") or api == "incremental_parallel":
                profile = report["state"]["incremental_parallel_profile" if api == "incremental_parallel" else "parallel_profile"]
                if config.get("synchronous"):
                    require(profile["serial_fallback"] and profile["workers_started"] == 0,
                            (name, "synchronous public path spawned workers"))
                    validation["synchronous_path_verified"] = True
                elif case["payload_name"] == "multi-block":
                    require(profile["workers_started"] > 0, (name, "normal parallel path never started workers"))
                    validation["real_worker_path_verified"] = True
            if case["config"].get("copy_mode"):
                history = Path(fixture_receipt["artifacts"]["wrong_history_dictionary"]["path"]).read_bytes()
                try:
                    wrong = library.decode(wire, history, format=format)
                except reference.ZstdError:
                    wrong = None
                validation["same_id_changed_history_effective"] = wrong != payload
                require(wrong != payload, (name, "copy-mode did not use full dictionary history"))
                validation["dictionary_entropy_repeats"] = sum(
                    block.get("literal_type") == 3 or 3 in block.get("sequence_modes", {}).values()
                    for frame in split for block in frame["blocks"])
                tables = Path(fixture_receipt["artifacts"]["wrong_entropy_dictionary"]["path"]).read_bytes()
                try:
                    wrong_tables = library.decode(wire, tables, format=format)
                except reference.ZstdError:
                    wrong_tables = None
                validation["same_id_changed_entropy_effective"] = wrong_tables != payload
                if validation["dictionary_entropy_repeats"]:
                    require(wrong_tables != payload, (name, "dictionary entropy repeat used wrong tables"))
                if not include_id:
                    validation["without_dictionary_error"] = library.expect_error(wire, None, format=format)
    event = {"name": name, "case": case["name"], "target": label, "command": command,
             "exit_code": execution.returncode, "expect": expectation, "report": report, "validation": validation,
             "output": artifact(output) if output.is_file() else None}
    (root / (name + ".result.json")).write_text(json.dumps(event, indent=2, sort_keys=True) + "\n")
    return event


def comparisons(events, cases):
    by_name = {event["case"]: event for event in events}
    groups = {}
    for case in cases:
        if "group" in case:
            groups.setdefault(case["group"], {})[case["flag"]] = case
    results = []
    for name, group in groups.items():
        kept, omitted = (Path(by_name[group[flag]["name"]]["output"]["path"]).read_bytes()
                         for flag in (True, False))
        default_checked = None in group
        if default_checked:
            default = Path(by_name[group[None]["name"]]["output"]["path"]).read_bytes()
            require(default == kept, (name, "default true byte compatibility"))
        format = group[True]["config"]["format"]
        true_frames, false_frames = frames(kept, format), frames(omitted, format)
        require(len(true_frames) == len(false_frames), (name, "data frame count"))
        equal = all(normalized_frame(left["wire"], format) == normalized_frame(right["wire"], format)
                    for left, right in zip(true_frames, false_frames))
        if group[True]["config"].get("copy_mode") or group[True].get("entropy_witness"):
            require(equal, (name, "copy-mode flag changed bytes outside dictionary ID"))
        results.append({"group": name, "default_equals_true": True if default_checked else None, "dict_id_only_frame_change": equal,
                        "data_frames": len(true_frames), "true_bytes": len(kept), "false_bytes": len(omitted),
                        "seek_table_sizes_adjusted": name.startswith("seekable_")})
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=Path, required=True)
    parser.add_argument("--probe-x86", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--reference-zstd", type=Path)
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    root = args.output_dir.expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    library = reference.Library(args.reference_zstd)
    receipt = fixtures.generate(root / "reference", library)
    cases = encoder_cases(receipt, root, args.preflight) + consumer_cases(receipt, root, args.preflight)
    witnesses, witness_provenance = entropy_witness_cases(root, library, args.preflight)
    cases += witnesses
    probes = [("native", args.probe_native, 64)]
    if args.probe_x86:
        probes.append(("x86", args.probe_x86, 32))
    events, pairs = [], []
    journal = root / "events.jsonl"
    with journal.open("w") as stream:
        for label, executable, bits in probes:
            current = []
            for index, case in enumerate(cases):
                event = invoke(root, label, executable, bits, case, library, receipt)
                current.append(event)
                stream.write(json.dumps(event, sort_keys=True) + "\n")
                stream.flush()
                if index % 25 == 0 or index + 1 == len(cases):
                    print(json.dumps({"target": label, "completed": index + 1, "cases": len(cases), "case": case["name"]}), flush=True)
            events += current
            pairs += [{"target": label, **pair} for pair in comparisons(current, cases)]
    report = {"schema": "vort.zstd.dictionary_id_control.matrix.v1", "status": "ok",
              "utc": datetime.now(timezone.utc).isoformat(), "preflight": args.preflight,
              "actual_command": [sys.executable, *sys.argv], "cases_per_target": len(cases),
              "codec_list": list(fixtures.CODEC_LIST), "encoder_apis": list(APIS),
              "reference": library.provenance(), "fixtures_receipt": artifact(Path(receipt["receipt_path"])),
              "generated_entropy_witness_source": witness_provenance,
              "probes": [{"label": label, "pointer_bits": bits, **artifact(path)} for label, path, bits in probes],
              "sources": [artifact(path) for path in sorted(HERE.glob("*.py"))] +
                         [artifact(HERE / "probe.zig")] + [artifact(path) for path in sorted((HERE / "probe_helpers").glob("*.zig"))],
              "counters": {"executions": len(events), "successes": sum(e["report"]["error"] is None for e in events),
                           "refusals": sum(e["report"]["error"] is not None for e in events),
                           "default_byte_comparisons": sum(p["default_equals_true"] is True for p in pairs), "header_only_comparisons": len(pairs),
                           "generated_entropy_witnesses": sum("generated_entropy_witness" in e["validation"] for e in events),
                           "independent_full_dictionary_decodes": sum(e["validation"].get("full_dictionary_decode", False) for e in events)},
              "comparisons": pairs, "events_path": str(journal), "events_sha256": sha(journal)}
    path = root / "report.json"
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": "ok", "report": str(path), "counters": report["counters"]}), flush=True)


if __name__ == "__main__":
    main()
