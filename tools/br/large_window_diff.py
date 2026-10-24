#!/usr/bin/env python3
"""Versioned Large Window Brotli wire checks with explicit decoder opt-in."""
import argparse
import csv
import ctypes as C
from datetime import datetime, timezone
import json
from pathlib import Path
import random
import sys

sys.dont_write_bytecode = True
from hq_controls_diff import ROOT, Controls, Dictionary, Reference, bind, digest, probe_call, require

OLD_REVISION = "b20af85d2c2e110e4beae08ba691dfd39791ba11"


class LargeReference(Reference):
    def __init__(self, path):
        super().__init__(path)
        self.large_encode = bind(self.library, "blwr_encode", C.c_int, C.c_uint32, C.POINTER(Controls),
                                 C.POINTER(Dictionary), C.c_size_t, C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t,
                                 C.POINTER(C.c_size_t), C.POINTER(C.c_size_t))
        self.large_decode = bind(self.library, "blwr_decode", C.c_int, C.c_uint32, C.POINTER(Dictionary), C.c_size_t,
                                 C.c_void_p, C.c_size_t, C.c_void_p, C.c_size_t, C.POINTER(C.c_size_t),
                                 C.POINTER(C.c_size_t), C.POINTER(C.c_int))

    def encode(self, payload, config, dictionaries=()):
        require(self.supports(dictionaries) is None, self.supports(dictionaries))
        keep, descriptors = self.dictionaries(dictionaries)
        options = Controls(config.get("quality", 10), {"generic": 0, "text": 1, "font": 2}[config.get("mode", "generic")],
                           config.get("window_bits", 25), config.get("npostfix", 0), config.get("ndirect_high", 0), 0)
        capacity = len(payload) * 2 + 16384
        output = C.create_string_buffer(b"\xa5" * (capacity + 16))
        consumed, written = C.c_size_t(), C.c_size_t()
        status = self.large_encode(config.get("large_window", True), C.byref(options), descriptors, len(dictionaries),
                                   payload, len(payload), C.byref(output, 8), capacity, C.byref(consumed), C.byref(written))
        require(status == 0 and consumed.value == len(payload), ("reference Large Window encode", status, config))
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[capacity + 8:capacity + 16] == b"\xa5" * 8, "large encoder output guards")
        return output.raw[8:8 + written.value]

    def decode_result(self, wire, payload, dictionaries=(), allow=True):
        require(self.supports(dictionaries) is None, self.supports(dictionaries))
        keep, descriptors = self.dictionaries(dictionaries)
        capacity = len(payload) + 1
        output = C.create_string_buffer(b"\xa5" * (capacity + 16))
        consumed, written, error = C.c_size_t(), C.c_size_t(), C.c_int()
        status = self.large_decode(allow, descriptors, len(dictionaries), wire, len(wire), C.byref(output, 8), capacity,
                                   C.byref(consumed), C.byref(written), C.byref(error))
        require(output.raw[:8] == b"\xa5" * 8 and output.raw[capacity + 8:capacity + 16] == b"\xa5" * 8, "large decoder output guards")
        if status == 0:
            require(consumed.value == len(wire) and written.value == len(payload) and output.raw[8:8 + written.value] == payload,
                    "large reference stream decode bytes/progress")
        return {"status": status, "decoder_error": error.value, "input_read": consumed.value, "output_written": written.value}

    def verify(self, wire, payload, dictionaries=()):
        result = self.decode_result(wire, payload, dictionaries)
        require(result["status"] == 0, ("large reference decode", result))


def header(wire):
    require(wire, "empty Brotli wire")
    first = wire[0]
    if first & 1 == 0:
        return {"window_bits": 16, "large_window": False, "header_bits": 1}
    upper = (first >> 1) & 7
    if upper:
        return {"window_bits": 17 + upper, "large_window": False, "header_bits": 4}
    lower = (first >> 4) & 7
    if lower != 1:
        return {"window_bits": 17 if lower == 0 else 8 + lower, "large_window": False, "header_bits": 7}
    require(len(wire) >= 2 and first & 128 == 0, "invalid Large Window extension prefix")
    bits = wire[1] & 63
    require(10 <= bits <= 30, "invalid Large Window width")
    return {"window_bits": bits, "large_window": True, "header_bits": 14}


def first_distance_parameters(wire):
    """Read fields before entropy trees when each stream uses one block type."""
    bit = header(wire)["header_bits"]
    def take(count):
        nonlocal bit
        require(bit + count <= len(wire) * 8, "truncated compressed meta-block prefix")
        value = sum(((wire[(bit + index) // 8] >> ((bit + index) % 8)) & 1) << index for index in range(count))
        bit += count
        return value
    last = bool(take(1))
    if last and take(1):return None
    nibbles = take(2) + 4
    if nibbles == 7:return None
    take(nibbles * 4)
    if not last and take(1):return None
    for _ in range(3):
        if take(1):
            # Multiple types carry Huffman block-switch headers; tiny fixed
            # shape fixtures deliberately avoid this different parsing surface.
            return None
    return {"npostfix": take(2), "ndirect_high": take(4)}


def invoke(args, name, payload, config, expected_error=None):
    wire, report = probe_call(args.probe, args.output_dir, name, payload, config, expected_error)
    with (args.output_dir / "large-events.jsonl").open("a") as events:
        events.write(json.dumps({"name": name, "expected_error": expected_error, "report": report}) + "\n")
    return wire, report


def limits(args):
    rows = [{key: int(value) for key, value in row.items()} for row in csv.DictReader(args.limits_csv.open())]
    require(len(rows) == 64 and {(row["npostfix"], row["ndirect_high"]) for row in rows} == {(post, high) for post in range(4) for high in range(16)}, "64 reference shapes")
    source = json.loads(args.limits_json.read_text())
    require(rows == source["rows"], "reference CSV and source JSON values")
    (args.output_dir / "reference-limits.csv").write_bytes(args.limits_csv.read_bytes())
    (args.output_dir / "reference-limits.json").write_bytes(args.limits_json.read_bytes())
    return rows, {"csv_sha256": digest(args.limits_csv.read_bytes()), "json_sha256": digest(args.limits_json.read_bytes()),
                  "source": source["reference_source"], "source_sha256": source["reference_source_sha256"],
                  "semantics": {"large_wire": "wire distance alphabet, up to 1128 symbols; simple symbols use ceil(log2(size)) bits",
                                "large_active": "active safe distance alphabet, up to 544 symbols",
                                "large_max_distance": "per-shape safe reference maximum; distinct from frame-history window"}}


def baseline(args, references):
    path = args.output_dir / "large-window-baseline.json"
    if path.exists():
        data = json.loads(path.read_text());require(data["revision"] == OLD_REVISION, "old b20 baseline revision");return data
    require(args.legacy_probe and args.legacy_source, "legacy inputs required only for initial baseline freeze")
    configurations = [{"level": level} for level in ("fast", "balanced", "ratio")] + [{"quality": quality} for quality in (0, 10, 11)]
    configurations += [{"hq": True, "quality": 11, "window_bits": 24, "beam_width": 1, "iterations": 1, "api": api, "block_len": 256} for api in ("one_shot", "chunks", "incremental")]
    payload = b"standard null large window baseline ABCabc\n" * 3
    rows = []
    for index, config in enumerate(configurations):
        name = "baseline-" + str(index)
        wire, _ = probe_call(args.legacy_probe, args.output_dir, name, payload, config)
        require(not header(wire)["large_window"], "legacy standard baseline unexpectedly extended")
        for reference in references.values():reference.verify(wire, payload)
        rows.append({"name": name, "config": config, "input": name + ".input", "wire": name + ".wire", "input_sha256": digest(payload), "wire_sha256": digest(wire)})
    paths = [args.legacy_source / "tools/br/hq_controls_probe.zig", args.legacy_source / "src/br.zig", *sorted((args.legacy_source / "src/br").rglob("*.zig"))]
    data = {"schema": "vort-br-large-window-old-wire-v1", "revision": OLD_REVISION, "rows": rows,
            "probe_sha256": digest(args.legacy_probe.read_bytes()), "source_sha256": {str(path.relative_to(args.legacy_source)): digest(path.read_bytes()) for path in paths}}
    path.write_text(json.dumps(data, indent=2) + "\n");return data


def campaign(args, references, shapes, old):
    rows = []
    expected_shapes = {(row["npostfix"], row["ndirect_high"]): row for row in shapes}
    base = {"hq": True, "large_window": True, "quality": 10, "window_bits": 25, "search_depth": 16,
            "nice_len": 32, "beam_width": 1, "iterations": 1, "block_len": 256}
    def check(name, payload, config, dictionaries=()):
        if args.case and name not in args.case:return None
        wire, stats = invoke(args, name, payload, config)
        parsed = header(wire)
        require(parsed["large_window"] and parsed["window_bits"] == config["window_bits"] and parsed["header_bits"] == 14, "actual 14-bit extension identity")
        require(stats["resolved"]["format"] == "large_window" and stats["profile"]["effective"]["format"] == "large_window", "actual format resolver/profile")
        post, high = stats["resolved"]["npostfix"], stats["resolved"]["ndirect_high"]
        wire_parameters = first_distance_parameters(wire)
        if name.startswith("shape-"):
            require(wire_parameters == {"npostfix": post, "ndirect_high": high},
                    ("fixed shape fields on actual wire", wire_parameters, post, high))
        shape = expected_shapes[(post, high)]
        for key, column in (("wire_alphabet_size", "large_wire"), ("active_alphabet_size", "large_active"), ("shape_max_distance", "large_max_distance")):
            require(stats["resolved"][key] == shape[column], ("reference shape limit", key, stats["resolved"], shape))
        reference_results = []
        for label, reference in references.items():
            reason = reference.supports(dictionaries)
            if reason:
                reference_results.append({"reference": label, "status": "skipped", "reason": reason});continue
            reference.verify(wire, payload, dictionaries)
            strict = reference.decode_result(wire, payload, dictionaries, allow=False)
            require(strict["status"] != 0, "strict reference decoder accepted extension")
            reverse = reference.encode(payload, config, dictionaries)
            reverse_header = header(reverse)
            # Upstream may choose an ordinary header for standard-size windows.
            decoded, _ = invoke(args, name + "-" + label + "-reverse", reverse, {**config, "operation": "decode"})
            require(decoded == payload, "public decoder failed independent large-window reference")
            reference_results.append({"reference": label, "status": "ok", "direction": "bidirectional", "reference_header": reverse_header,
                                      "strict_decoder": strict, "dictionary_attached": bool(dictionaries)})
        invoke(args, name + "-strict", wire, {**config, "operation": "decode", "large_window": False}, "CorruptFrame")
        off, off_stats = invoke(args, name + "-profile-off", payload, {**config, "profile_enabled": False, "total_profile_enabled": False})
        require(off == wire and off_stats["resolved"] == stats["resolved"], "profile changed extension wire/resolution")
        rows.append({"name": name, "config": config, "input_bytes": len(payload), "wire_bytes": len(wire), "wire_sha256": digest(wire), "header": parsed,
                     "first_wire_distance_parameters": wire_parameters,
                     "probe": stats, "reference_results": reference_results})
        return wire
    payload = b"Large Window HQ ABCabcABCabc_xyz\n" * 3
    if not args.case:
        for row in old["rows"]:
            original = (args.output_dir / row["wire"]).read_bytes();data = (args.output_dir / row["input"]).read_bytes()
            require(digest(original) == row["wire_sha256"] and digest(data) == row["input_sha256"], "frozen standard wire hash")
            current, _ = invoke(args, "standard-" + row["name"], data, {**row["config"], "large_window": False})
            require(current == original, "large_window=false changed standard wire")
    for quality in (10, 11):
        for bits in range(10, 31):check("window-q" + str(quality) + "-" + str(bits), payload, {**base, "quality": quality, "window_bits": bits})
    for shape in shapes:
        check("shape-" + str(shape["npostfix"]) + "-" + str(shape["ndirect_high"]), payload,
              {**base, "npostfix": shape["npostfix"], "ndirect_high": shape["ndirect_high"]})
    for api in ("one_shot", "chunks", "incremental"):
        for bits in (10, 30):check("api-" + api + "-" + str(bits), payload * 3,
                                  {**base, "api": api, "quality": 11, "window_bits": bits, "input_chunk": 127, "output_chunk": 31})
    prefix = random.Random(0x1a46e).randbytes(256);prefix_path = args.output_dir / "large-raw.dictionary";prefix_path.write_bytes(prefix)
    check("raw", prefix[-64:] + b"!", {**base, "quality": 11, "raw_dictionary_paths": [str(prefix_path)]}, [(0, prefix)])
    check("empty", b"", base)
    if not args.case:
        wire, stats = invoke(args, "budget-measure", payload, base)
        total, workspace = stats["total_profile"]["peak_requested_bytes"], stats["profile"]["peak_working_memory"]
        for name, controls, error in (("budget-exact", {"max_total_working_memory": total}, None),
                                      ("budget-below", {"max_total_working_memory": total - 1}, "WorkingMemoryLimitExceeded"),
                                      ("workspace-below", {"max_working_memory": workspace - 1}, "WorkingMemoryLimitExceeded")):
            attempted, _ = invoke(args, name, payload, {**base, **controls}, error)
            if error is None:require(attempted == wire, "exact total cap changed wire")
        for name, controls in (("width", {"window_bits": 31}), ("hq", {"hq": False}), ("quality", {"quality": 9}), ("postfix", {"npostfix": 4})):
            invoke(args, "invalid-" + name, payload, {**base, **controls}, "InvalidBlockPlan")
    return rows


def far_artifact(args, references):
    if not args.far_artifact:return None
    metadata = json.loads(args.far_artifact.read_text())
    wire_path, input_path = Path(metadata["wire_path"]), Path(metadata["input_path"])
    wire, payload = wire_path.read_bytes(), input_path.read_bytes()
    require(digest(wire) == metadata["wire_sha256"] and digest(payload) == metadata["input_sha256"], "public far artifact hashes")
    require(header(wire)["large_window"] and metadata["emitted_max_distance"] > (1 << 24), "actual public far distance")
    for reference in references.values():reference.verify(wire, payload)
    return {"metadata_sha256": digest(args.far_artifact.read_bytes()), "wire_sha256": digest(wire), "input_sha256": digest(payload),
            "input_bytes": len(payload), "wire_bytes": len(wire), "header": header(wire), "emitted_max_distance": metadata["emitted_max_distance"],
            "scope": "consume existing public encoder artifact; reference create/set-large/stream decode only, no repeated large HQ encode"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ("reference", "system-reference", "output-dir"):parser.add_argument("--" + field, type=Path, required=True)
    for field in ("probe", "legacy-probe", "legacy-source", "far-artifact"):parser.add_argument("--" + field, type=Path)
    parser.add_argument("--limits-csv", type=Path, default=Path('/tmp/vort-large-window-audit/reference-limits.csv'))
    parser.add_argument("--limits-json", type=Path, default=Path('/tmp/vort-large-window-audit/reference-limits.json'))
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--case", action="append", help="named stage case; omit for the complete bounded campaign")
    args = parser.parse_args()
    for field in ("reference", "system_reference", "output_dir", "probe", "legacy_probe", "legacy_source", "far_artifact", "limits_csv", "limits_json"):
        if getattr(args, field):setattr(args, field, getattr(args, field).resolve())
    args.output_dir.mkdir(parents=True, exist_ok=True)
    if args.case:
        names = {"window-q" + str(quality) + "-" + str(bits) for quality in (10, 11) for bits in range(10, 31)}
        names |= {"shape-" + str(post) + "-" + str(high) for post in range(4) for high in range(16)}
        names |= {"api-" + api + "-" + str(bits) for api in ("one_shot", "chunks", "incremental") for bits in (10, 30)}
        names |= {"raw", "empty"}
        require(set(args.case) <= names, "unknown Large Window stage case")
    references = {"modern": LargeReference(args.reference), "system": LargeReference(args.system_reference)}
    shapes, provenance = limits(args)
    old = baseline(args, references)
    require(args.prepare_only or args.probe, "--probe required for actual public campaign")
    paths = [ROOT / "build.zig", *sorted((ROOT / "src").rglob("*")), ROOT / "tools/br/hq_controls_probe.zig", ROOT / "tools/br/hq_controls_reference.c",
             ROOT / "tools/br/hq_controls_diff.py", ROOT / "tools/br/large_window_reference.c", Path(__file__)]
    before = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    rows = [] if args.prepare_only else campaign(args, references, shapes, old)
    far = None if args.prepare_only else far_artifact(args, references)
    after = {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in paths if path.is_file()}
    if not args.case:require(before == after, "source changed during large-window campaign")
    report = {"schema": "vort-br-large-window-v1", "status": "prepared" if args.prepare_only else "ok", "utc": datetime.now(timezone.utc).isoformat(),
              "rows": rows, "far_artifact": far, "references": {name: reference.provenance() for name, reference in references.items()},
              "limits": provenance, "baseline_rows": len(old["rows"]), "baseline_manifest_sha256": digest((args.output_dir / "large-window-baseline.json").read_bytes()),
              "source_sha256": before, "source_after_sha256": after, "source_before_after_equal": before == after, "stage_cases": args.case,
              "probe_path": str(args.probe) if args.probe else None, "probe_sha256": digest(args.probe.read_bytes()) if args.probe else None,
              "scope": "wire correctness and opt-in format behavior; no throughput, ratio or preset-equivalence claim"}
    path = args.output_dir / "large-window-report.json";path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "rows": len(rows), "baseline_rows": len(old["rows"]), "report": str(path)}))


if __name__ == "__main__":main()
