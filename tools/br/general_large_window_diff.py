#!/usr/bin/env python3
"""Small ordinary Brotli Large Window API and versioned-reference checks."""
import argparse
import ctypes as C
from datetime import datetime, timezone
import json
from pathlib import Path
import random
import sys

sys.dont_write_bytecode = True
from hq_controls_diff import ROOT, Controls, Reference, digest, probe_call, require
from large_window_diff import LargeReference, header

OLD_REVISION = "fa35a843cd74f59ce5d0f3ef04bad6d07ef3146d"


class ExperimentalReference(LargeReference):
    def supports(self, dictionaries):
        if self.raw_dictionaries:
            return None
        return super().supports(dictionaries)

    def provenance(self):
        result = super().provenance()
        result["serialized_dictionary_public_api"] = True
        result["BROTLI_EXPERIMENTAL"] = True
        result["scope"] = "separate same-source 1.2.0 experimental build, serialized singleton only"
        return result


def samples(directory):
    text = (b"ordinary Brotli window ABCabcABCabc_xyz\n" * 4)[:128]
    base = {"large_window": True, "window_bits": 25, "block_len": 256, "input_chunk": 31, "output_chunk": 17}
    cases = []
    for quality in range(12):
        for bits in (16, 24, 25, 30):
            cases.append({"name": "quality-" + str(quality) + "-window-" + str(bits), "payload": text,
                          "config": {**base, "quality": quality, "window_bits": bits}, "dictionaries": []})
    for api in ("one_shot", "chunks", "reusable", "incremental"):
        for level in ("fast", "balanced", "ratio"):
            cases.append({"name": "legacy-" + level + "-" + api, "payload": text,
                          "config": {**base, "level": level, "api": api}, "dictionaries": []})
        cases.append({"name": "stored-" + api, "payload": text, "config": {**base, "codec": "stored", "api": api, "window_bits": 30}, "dictionaries": []})
    for mode in ("text", "font"):
        cases.append({"name": "mode-" + mode, "payload": text, "config": {**base, "quality": 5, "mode": mode}, "dictionaries": []})
    for quality in (0, 1, 5, 11):
        cases.append({"name": "standard10-q" + str(quality), "payload": text,
                      "config": {**base, "quality": quality, "window_bits": 10, "large_window": False}, "dictionaries": []})
    prefix = random.Random(0xfa35a843).randbytes(256)
    path = directory / "general-prefix.dictionary"
    if path.exists():require(path.read_bytes() == prefix, "frozen RAW prefix changed")
    else:path.write_bytes(prefix)
    cases.append({"name": "raw-prefix", "payload": prefix[-64:] + b"!", "config": {**base, "quality": 11, "dictionary_paths": [str(path)]}, "dictionaries": [(0, prefix)]})
    for codec in ("planned", "stored"):
        cases.append({"name": "empty-" + codec, "payload": b"", "config": {**base, "codec": codec, "quality": 0 if codec == "planned" else None}, "dictionaries": []})
        cases.append({"name": "metadata-flush-" + codec, "payload": text * 3,
                      "config": {**base, "codec": codec, "api": "incremental", "quality": 1 if codec == "planned" else None,
                                 "metadata": "first metadata", "flush_at": 128, "stream_metadata": "middle metadata"}, "dictionaries": []})
    return cases


def invoke(probe, directory, name, payload, config, expected_error=None):
    wire, stats = probe_call(probe, directory, name, payload, config, expected_error)
    with (directory / "general-events.jsonl").open("a") as events:
        events.write(json.dumps({"name": name, "expected_error": expected_error, "report": stats}) + "\n")
    return wire, stats


def baseline(args, references):
    path = args.output_dir / "general-baseline.json"
    if path.exists():
        value = json.loads(path.read_text());require(value["revision"] == OLD_REVISION, "fa35a843 baseline revision");return value
    require(args.legacy_probe and args.legacy_source, "legacy probe/source required only for initial baseline freeze")
    payload = b"old standard general Brotli window\n" * 3
    configs = [{"level": level} for level in ("fast", "balanced", "ratio")] + [{"quality": quality, "window_bits": 16} for quality in (0, 1, 5, 11)]
    configs += [{"codec": "stored"}, {"quality": 5, "api": "reusable"}, {"quality": 1, "api": "incremental", "block_len": 256}]
    rows = []
    for index, config in enumerate(configs):
        name = "baseline-" + str(index)
        wire, _ = invoke(args.legacy_probe, args.output_dir, name, payload, config)
        require(not header(wire)["large_window"], "old standard baseline extension identity")
        for reference in references.values():reference.verify(wire, payload)
        rows.append({"name": name, "config": config, "input": name + ".input", "wire": name + ".wire", "input_sha256": digest(payload), "wire_sha256": digest(wire)})
    files = [args.legacy_source / "src/root.zig", args.legacy_source / "src/br.zig", args.legacy_source / "general_large_window_probe.zig", *sorted((args.legacy_source / "src/br").rglob("*.zig"))]
    value = {"schema": "vort-br-general-window-standard-baseline-v1", "revision": OLD_REVISION, "rows": rows,
             "probe_sha256": digest(args.legacy_probe.read_bytes()), "source_sha256": {str(file.relative_to(args.legacy_source)): digest(file.read_bytes()) for file in files}}
    path.write_text(json.dumps(value, indent=2) + "\n");return value


def reference_prepare(references):
    rows = []
    payload = b"independent reference window semantics\n" * 3
    for name, reference in references.items():
        for quality in (0, 1, 5, 11):
            for bits in (16, 25, 30):
                config = {"quality": quality, "window_bits": bits, "large_window": True}
                wire = reference.encode(payload, config)
                reference.verify(wire, payload)
                rows.append({"reference": name, "quality": quality, "requested_window": bits, "actual_header": header(wire), "wire_sha256": digest(wire)})
    return rows


def serialized_result(reference, wire, payload, serialized):
    """Check actual attachment even when old public documentation rejects type 1."""
    if not reference.raw_dictionaries:
        return {"status": "skipped", "reason": "system Brotli 1.0.9 lacks shared dictionary attach API"}
    storage, descriptors = reference.dictionaries([(1, serialized)])
    output = C.create_string_buffer(b"\xa5" * (len(payload) + 18))
    consumed, written, error = C.c_size_t(), C.c_size_t(), C.c_int()
    status = reference.large_decode(True, descriptors, 1, wire, len(wire), C.byref(output, 8), len(payload) + 1,
                                    C.byref(consumed), C.byref(written), C.byref(error))
    require(output.raw[:8] == b"\xa5" * 8 and output.raw[len(payload) + 9:len(payload) + 17] == b"\xa5" * 8, "serialized decoder output guards")
    if status == 3:
        return {"status": "skipped", "reason": "the pinned Brotli 1.2.0 build rejected SERIALIZED in its actual AttachDictionary call; its non-experimental common library accepts RAW only, before payload parsing", "attach_failure_status": status}
    require(status == 0 and consumed.value == len(wire) and written.value == len(payload) and output.raw[8:8 + written.value] == payload,
            ("actual serialized dictionary reference decode", status, error.value))
    return {"status": "ok", "direction": "vort-to-reference", "input_read": consumed.value, "output_written": written.value, "dictionary_type": "serialized"}


def campaign(args, cases, references, old, experimental):
    rows = []
    if not args.case:
        for row in old["rows"]:
            wire, _ = invoke(args.probe, args.output_dir, "regression-" + row["name"], (args.output_dir / row["input"]).read_bytes(), row["config"])
            expected = (args.output_dir / row["wire"]).read_bytes()
            require(digest(expected) == row["wire_sha256"] and wire == expected, "large_window=false changed original standard wire")
    for case in cases:
        name, payload, config = case["name"], case["payload"], case["config"]
        if args.case and name not in args.case:continue
        wire, stats = invoke(args.probe, args.output_dir, name, payload, config)
        actual = header(wire);summary = stats["summary"]
        require(actual["large_window"] == config.get("large_window", False) and actual["window_bits"] == config["window_bits"], "Vort actual header did not honor requested format/window")
        require(summary["large_window"] == actual["large_window"] and summary["window_bits"] == actual["window_bits"] and summary["decoded_bytes"] == len(payload), "public semantic stream summary")
        if config.get("stream_metadata"):
            require(summary["metadata_bytes"] == len(config["metadata"]) + len(config["stream_metadata"]) and summary["metadata_meta_block_count"] >= 2, "metadata/flush stream semantics")
        off, _ = invoke(args.probe, args.output_dir, name + "-profile-off", payload, {**config, "total_profile_enabled": False})
        require(off == wire, "total instrumentation changed ordinary wire")
        results = []
        for layer, reference in references.items():
            reason = reference.supports(case["dictionaries"])
            if reason:results.append({"layer": layer, "status": "skipped", "reason": reason});continue
            reference.verify(wire, payload, case["dictionaries"])
            strict = reference.decode_result(wire, payload, case["dictionaries"], allow=False)
            require((strict["status"] != 0) == actual["large_window"], "reference strict format acceptance")
            reference_config = {"quality": config.get("quality") if config.get("quality") is not None else 5, "window_bits": config["window_bits"], "large_window": config["large_window"], "mode": config.get("mode", "generic")}
            independent = reference.encode(payload, reference_config, case["dictionaries"])
            decoded, _ = invoke(args.probe, args.output_dir, name + "-reverse-" + layer, independent, {**config, "operation": "decode"})
            require(decoded == payload, "public decoder failed independent reference bytes")
            results.append({"layer": layer, "status": "ok", "direction": "bidirectional", "reference_requested": reference_config,
                            "reference_actual_header": header(independent), "strict_decoder": strict,
                            "header_scope": "reference q0/q1 may force window>=18 and an ordinary header; only Vort wire must match the Vort request"})
        if actual["large_window"]:
            invoke(args.probe, args.output_dir, name + "-strict", wire, {**config, "operation": "decode", "large_window": False}, "CorruptFrame")
        rows.append({"name": name, "input_bytes": len(payload), "wire_bytes": len(wire), "wire_sha256": digest(wire), "config": config,
                     "actual_header": actual, "probe": stats, "reference_results": results})
    if not args.case or "serialized" in args.case:
        fixture = args.output_dir / "general-serialized.dictionary"
        serialized, _ = invoke(args.probe, args.output_dir, "make-serialized", b"prepare RAW prefix", {"operation": "make_serialized_dictionary"})
        require(len(serialized) == 70, "original 70-byte serialized singleton fixture")
        fixture.write_bytes(serialized)
        payload = b"wordtestwordtest"
        config = {"quality": 11, "large_window": True, "window_bits": 25, "serialized_dictionary_path": str(fixture)}
        wire, stats = invoke(args.probe, args.output_dir, "serialized", payload, config)
        require(header(wire) == {"window_bits": 25, "large_window": True, "header_bits": 14}, "serialized Vort format identity")
        require(stats["summary"]["uses_shared_dictionary"] and stats["summary"]["shared_dictionary_copy_count"] > 0,
                "serialized fixture did not actually reference its dictionary")
        unprofiled, _ = invoke(args.probe, args.output_dir, "serialized-profile-off", payload, {**config, "total_profile_enabled": False})
        require(unprofiled == wire, "serialized total profile changed wire")
        decoded, _ = invoke(args.probe, args.output_dir, "serialized-own-decode", wire, {**config, "operation": "decode"})
        require(decoded == payload, "own serialized descriptor decode")
        results = [{"layer": layer, **serialized_result(reference, wire, payload, serialized)} for layer, reference in references.items()]
        if experimental:
            experimental.verify(wire, payload, [(1, serialized)])
            reverse = experimental.encode(payload, config, [(1, serialized)])
            decoded, _ = invoke(args.probe, args.output_dir, "serialized-experimental-reverse", reverse, {**config, "operation": "decode"})
            require(decoded == payload, "experimental serialized reference reverse bytes")
            results.append({"layer": "experimental-1.2.0", "status": "ok", "direction": "bidirectional", "dictionary_type": "serialized", "reference_actual_header": header(reverse), "reference_wire_sha256": digest(reverse)})
        rows.append({"name": "serialized", "input_bytes": len(payload), "wire_bytes": len(wire), "dictionary_sha256": digest(serialized), "probe": stats,
                     "reference_results": results})
    if not args.case:
        config = {"quality": 5, "window_bits": 25, "large_window": True}
        payload = cases[0]["payload"]
        wire, stats = invoke(args.probe, args.output_dir, "total-measure", payload, config)
        peak = stats["total_profile"]["peak_requested_bytes"]
        require(peak > 0 and stats["total_profile"]["live_requested_bytes"] == 0, "ordinary planned total heap profile")
        exact, _ = invoke(args.probe, args.output_dir, "total-exact", payload, {**config, "max_total_working_memory": peak})
        require(exact == wire, "exact total budget changed ordinary wire")
        for name, cap in (("total-below", peak - 1), ("total-zero", 0)):
            _, failed = invoke(args.probe, args.output_dir, name, payload, {**config, "max_total_working_memory": cap}, "WorkingMemoryLimitExceeded")
            require(failed["total_profile"]["live_requested_bytes"] == 0, "ordinary failed encode retained heap")
        for name, overrides in (("window", {"window_bits": 31}), ("quality", {"quality": 12})):
            invoke(args.probe, args.output_dir, "invalid-" + name, payload, {**config, **overrides}, "InvalidBlockPlan")
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ("reference", "system-reference", "output-dir"):parser.add_argument("--" + field, type=Path, required=True)
    for field in ("probe", "legacy-probe", "legacy-source"):parser.add_argument("--" + field, type=Path)
    parser.add_argument("--experimental-reference", type=Path)
    parser.add_argument("--prepare-only", action="store_true");parser.add_argument("--case", action="append")
    args = parser.parse_args()
    for field in ("reference", "system_reference", "output_dir", "probe", "legacy_probe", "legacy_source", "experimental_reference"):
        if getattr(args, field):setattr(args, field, getattr(args, field).resolve())
    args.output_dir.mkdir(parents=True, exist_ok=True)
    references = {"modern": LargeReference(args.reference), "system": LargeReference(args.system_reference)}
    experimental = ExperimentalReference(args.experimental_reference) if args.experimental_reference else None
    cases = samples(args.output_dir)
    if args.case:require(set(args.case) <= {case["name"] for case in cases} | {"serialized"}, "unknown general-window stage case")
    old = baseline(args, references)
    ref_preparation = reference_prepare(references)
    require(args.prepare_only or args.probe, "public probe needed for ordinary Large Window campaign")
    paths = [ROOT / "build.zig", *sorted((ROOT / "src").rglob("*")), ROOT / "tools/br/general_large_window_probe.zig", Path(__file__)]
    before = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    rows = [] if args.prepare_only else campaign(args, cases, references, old, experimental)
    after = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    if not args.case:require(before == after, "source changed during general-window final campaign")
    report = {"schema": "vort-br-general-large-window-v1", "status": "prepared" if args.prepare_only else "ok", "utc": datetime.now(timezone.utc).isoformat(),
              "rows": rows, "references": {layer: reference.provenance() for layer, reference in references.items()}, "reference_preparation": ref_preparation,
              "experimental_serialized_reference": experimental.provenance() if experimental else None,
              "baseline_rows": len(old["rows"]), "baseline_manifest_sha256": digest((args.output_dir / "general-baseline.json").read_bytes()),
              "probe_path": str(args.probe) if args.probe else None, "probe_sha256": digest(args.probe.read_bytes()) if args.probe else None,
              "source_sha256": before, "source_after_sha256": after, "source_before_after_equal": before == after, "stage_cases": args.case,
              "scope": "ordinary parser header/summary and versioned byte correctness; no HQ work, ratio or performance claim"}
    path = args.output_dir / "general-large-window-report.json";path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "rows": len(rows), "baseline_rows": len(old["rows"]), "report": str(path)}))


if __name__ == "__main__":main()
