#!/usr/bin/env python3
"""Functional incremental single-frame Zstd interoperability; never builds or times.

Also provides the read-only 92-wire regression gate for the shared one-shot
codec. Every subprocess command and both output streams are preserved.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import subprocess
import sys

sys.dont_write_bytecode = True
from magicless_diff import Reference, inspect, digest, identity, deterministic
from parallel_frame_diff import fixtures as previous_fixtures, sequence_count

ROOT = Path(__file__).resolve().parents[2]
LIBRARY_SHA = "c76f4c4457df67a5e0c7bb6bb4f58b9857cf4f2cdd7925bfb9345daac4e6b83e"
HEADER_SHA = "17d279cd45a6881e87eb1801e08d2d29be200ff47811a1ff3168947cad2029bd"
STRATEGIES = ("fast", "double_fast", "greedy", "lazy", "optimal", "lazy2", "btlazy2", "btopt", "btultra", "btultra2")


def require(value, context):
    if not value:
        raise AssertionError(context)


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def bound(row):
    path = Path(row["path"])
    if not path.is_absolute():
        path = ROOT / path
    body = path.read_bytes()
    require(len(body) == row["bytes"] and digest(body) == row["sha256"], ("bound artifact", row))
    return body


def sources(directory):
    paths = [ROOT / "build.zig", ROOT / "build.zig.zon"]
    paths += [ROOT / "src" / (name + ".zig") for name in
              ("zstd", "core", "checksum", "dictionary", "huffman", "lz77", "bitstream", "zstd_huffman_x2_object")]
    paths += [path for folder in ("zstd", "checksum", "dictionary", "io")
              for path in sorted((ROOT / "src" / folder).rglob("*.zig"))]
    paths += [ROOT / "tools/zstd" / name for name in
              ("incremental_parallel_probe.zig", "incremental_parallel_diff.py", "parallel_frame_probe.zig",
               "parallel_frame_diff.py", "magicless_diff.py")]
    paths += sorted((ROOT / "tools/zstd/incremental_parallel_probe").rglob("*.zig"))
    rows = []
    for path in sorted(set(paths)):
        if not path.exists():
            continue
        name = path.relative_to(ROOT)
        row = identity(path)
        row["path"] = str(name)
        rows.append(row)
        if directory is not None:
            destination = directory / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(path.read_bytes())
    probe_files = [row for row in rows if row["path"] == "tools/zstd/incremental_parallel_probe.zig" or
                   row["path"].startswith("tools/zstd/incremental_parallel_probe/")]
    return {"files": rows, "sha256": digest(json.dumps(rows, sort_keys=True).encode()),
            "probe_source_files": probe_files, "probe_source_digest": digest(json.dumps(probe_files, sort_keys=True).encode()),
            "scope": "Explicit source scan at runtime; not compiler-extracted dependencies or a retroactive compile snapshot."}


def xxh64(data):
    """Independent scalar XXH64, seed zero, for actual frame checksum trailers."""
    mask = (1 << 64) - 1
    p1, p2, p3, p4, p5 = 11400714785074694791, 14029467366897019727, 1609587929392839161, 9650029242287828579, 2870177450012600261
    def rot(x, n):
        return ((x << n) | (x >> (64 - n))) & mask
    def round_(v, word):
        return rot((v + word * p2) & mask, 31) * p1 & mask
    offset = 0
    if len(data) >= 32:
        lanes = [(p1 + p2) & mask, p2, 0, -p1 & mask]
        while offset + 32 <= len(data):
            for i in range(4):
                lanes[i] = round_(lanes[i], int.from_bytes(data[offset + i * 8:offset + i * 8 + 8], "little"))
            offset += 32
        h = sum(rot(v, n) for v, n in zip(lanes, (1, 7, 12, 18))) & mask
        for v in lanes:
            h = ((h ^ round_(0, v)) * p1 + p4) & mask
    else:
        h = p5
    h = (h + len(data)) & mask
    while offset + 8 <= len(data):
        h = (rot(h ^ round_(0, int.from_bytes(data[offset:offset + 8], "little")), 27) * p1 + p4) & mask
        offset += 8
    if offset + 4 <= len(data):
        h = (rot(h ^ (int.from_bytes(data[offset:offset + 4], "little") * p1 & mask), 23) * p2 + p3) & mask
        offset += 4
    for byte in data[offset:]:
        h = rot(h ^ (byte * p5 & mask), 11) * p1 & mask
    h ^= h >> 33
    h = h * p2 & mask
    h ^= h >> 29
    h = h * p3 & mask
    return h ^ (h >> 32)


class Campaign:
    def __init__(self, args, reference):
        self.args, self.reference = args, reference
        self.directory = args.directory.resolve()
        require(not self.directory.exists() or not any(self.directory.iterdir()), "new/empty evidence directory required")
        self.directory.mkdir(parents=True, exist_ok=True)
        self.commands, self.results = [], []
        self.before = sources(self.directory / "sources-before")
        self.probe = args.probe.resolve()
        self.probe_identity = identity(self.probe)

    def call(self, name, c, input_path, output_path, probe=None):
        config = self.directory / (name + ".config.json")
        write_json(config, c)
        command = [str(probe or self.probe), str(input_path), str(output_path), str(config)]
        record = {"argv": command, "config": identity(config)}
        try:
            process = subprocess.run(command, capture_output=True, check=False, timeout=self.args.timeout)
            stdout, stderr = process.stdout, process.stderr
            record["exit_code"] = process.returncode
        except subprocess.TimeoutExpired as err:
            stdout, stderr = err.stdout or b"", err.stderr or b""
            record["exit_code"], record["timeout"] = None, self.args.timeout
        for kind, body in (("stdout", stdout), ("stderr", stderr)):
            path = self.directory / (name + "." + kind)
            path.write_bytes(body)
            record[kind] = identity(path)
        self.commands.append(record)
        require(record["exit_code"] == 0, (name, "probe terminal status", record))
        return json.loads(stdout)

    def finish(self, mode, checks):
        after = sources(self.directory / "sources-after")
        failures = [row for row in self.results if row["status"] != "passed"]
        unchanged = self.before == after
        result = {"schema": "vort.zstd.incremental-parallel-campaign.v1", "created_utc": datetime.now(timezone.utc).isoformat(),
                  "mode": mode, "source_epoch": self.args.source_epoch, "probe": self.probe_identity,
                  "reference": self.reference.describe(), "platform": platform.uname()._asdict(),
                  "source_before": self.before, "source_after": after, "sources_preserved": unchanged,
                  "counts": {"cases": len(self.results), "passed": len(self.results) - len(failures), "failed": len(failures)},
                  "partition": {"complete_stream_successes": sum(row["status"] == "passed" and not row.get("settings", {}).get("expected_error") for row in self.results),
                                "expected_terminal_rejections": sum(row["status"] == "passed" and bool(row.get("settings", {}).get("expected_error")) for row in self.results),
                                "unexpected_failures": len(failures)},
                  "checks": checks, "commands": self.commands, "results": self.results,
                  "scope": "Functional external protocol checks only; actual scheduling observations, no timing, throughput, RSS, or reference worker-count claim."}
        write_json(self.args.report or self.directory / "differential.json", result)
        write_json(self.directory / "artifact-manifest.json", {"files": [identity(path) for path in sorted(self.directory.rglob("*")) if path.is_file()]})
        print(json.dumps({"counts": result["counts"], "checks": checks, "sources_preserved": unchanged,
                          "report": str(self.args.report or self.directory / "differential.json")}))
        return 1 if failures or not unchanged else 0


def inspect_frame(reference, wire, payload, c, dictionary, dictionary_id, pledged):
    parsed = inspect(wire, c["format"])
    require(parsed["frame_count"] == 1 and not parsed["skippable_frames"], "one physical frame per completed data interval")
    frame = parsed["frames"][0]
    require(frame["start_byte"] == 0 and frame["end_byte"] == len(wire), "exact frame bytes")
    require(sum(block["final"] for block in frame["blocks"]) == 1, "one terminal block")
    require(frame["content_size"] == (pledged if c["content_size"] else None), "actual unknown/exact FCS")
    require(frame["dictionary_id"] == dictionary_id and frame["checksum"] == c["checksum"], "actual dictionary ID/checksum flag")
    if c["checksum"]:
        require(frame["checksum_value"] == xxh64(payload) & 0xFFFFFFFF, "whole plaintext checksum once")
    counts = [sequence_count(wire[b["start_byte"] + 3:b["end_byte"]]) if b["kind"] == "compressed" else 0 for b in frame["blocks"]]
    decoded = reference.decode(wire, payload, c["format"], dictionary)
    require(decoded["complete_contents_verified"] and decoded["input_read"] == len(wire), "libzstd full plaintext/exact consumption")
    return {"envelope": parsed, "physical_sequence_counts": counts, "max_physical_sequence_count": max(counts, default=0), "reference_decode": decoded}


def legacy_gate(campaign):
    report_path = campaign.args.legacy_wire_gate.resolve()
    old = json.loads(report_path.read_text())
    rows = [row for row in old["results"] if row["scope"] != "native-mt-to-target" and row["probe"]["error"] is None]
    require(len(rows) == 92, "all 92 complete saved one-shot outputs required")
    for row in rows:
        entry = {"name": row["name"], "scope": "legacy-92-wire", "old_input": row["input"], "old_wire": row["wire"], "settings": row["settings"]}
        try:
            payload, saved = bound(row["input"]), bound(row["wire"])
            input_copy = campaign.directory / (row["name"] + ".input")
            wire_copy = campaign.directory / (row["name"] + ".saved.zst")
            input_copy.write_bytes(payload)
            wire_copy.write_bytes(saved)
            entry["preserved_input"], entry["preserved_saved_wire"] = identity(input_copy), identity(wire_copy)
            c = row["settings"]
            path = campaign.directory / (row["name"] + ".new.zst")
            result = campaign.call(row["name"], c, Path(row["input"]["path"]), path)
            require(result["error"] is None and result["self_decode_verified"], "current public one-shot success")
            wire = path.read_bytes()
            require(wire == saved, (row["name"], "saved complete wire equality", digest(saved), digest(wire)))
            dictionary = Path(c["dictionary_path"]).read_bytes() if c.get("dictionary_path") else b""
            if dictionary:
                dictionary_copy = campaign.directory / ("dictionary-" + digest(dictionary) + ".bin")
                dictionary_copy.write_bytes(dictionary)
                entry["preserved_dictionary"] = identity(dictionary_copy)
            checked = inspect_frame(campaign.reference, wire, payload, c, dictionary, row["probe"]["dictionary_id"], len(payload))
            entry.update(status="passed", probe=result, new_wire=identity(path), saved_wire_equal=True, independent_frame=checked)
        except Exception as err:
            entry.update(status="failed", diagnostic=repr(err))
        campaign.results.append(entry)
    return campaign.finish("legacy-saved-92-wire-gate", {"required_complete_wire_pairs": 92, "old_report": identity(report_path),
                           "old_probe": old["probe"], "old_source": old["source"], "old_artifacts_modified": False,
                           "scope": "Current build of unchanged old public probe against saved configs/input/wire; no rerun of the old executable."})


def fixtures(reference):
    previous = previous_fixtures()
    unit = deterministic(8192, 0x19562626)
    full = bytearray(reference.dictionary())
    # Dictionary_ID is independent of trained entropy/content. Keep an actual
    # full standard dictionary with ID 77 so raw metadata-only frames can also
    # be decoded by the unmodified reference dictionary-ID checks.
    full[4:8] = (77).to_bytes(4, "little")
    dictionaries = {"raw": deterministic(8192, 0xD1C71026), "full": bytes(full), "metadata": bytes(full)}
    payloads = {"empty": b"", "tiny": b"incremental\x00\xff", "structured": previous["structured"], "mixed": previous["mixed"],
                "seal": unit, "credit": unit + unit + b"!", "partial": deterministic(1555),
                "history": previous["far-history"], "large-sequences": previous["large-sequences"],
                "dict-raw": dictionaries["raw"][-1024:] * 12,
                "dict-raw-short": dictionaries["raw"][-64:],
                "dict-full": b'{"id":7,"service":"magicless","message":"dictionary format interoperability"}\n' * 120}
    for length in (262144, 1048576, 4194304):
        payloads["long-" + str(length)] = (unit * (1 + length // len(unit)))[:length]
    return payloads, dictionaries


def matrix():
    for format_ in ("standard", "magicless"):
        for selection in ("auto", "raw_or_rle", "literal_only", "fast_compressed"):
            for fixture in ("empty", "tiny", "structured", "mixed"):
                yield fixture, {"format": format_, "selection": selection}, "tiny-owned-io"
        for strategy in STRATEGIES:
            for known in (False, True):
                yield "tiny", {"format": format_, "strategy": strategy, "content_size": known}, "explicit-strategy"
        for strategy in ("btopt", "btultra", "btultra2"):
            yield "structured", {"format": format_, "strategy": strategy,
                                 "hq": {"parse_mode": "whole_block", "match_lengths": "complete"}}, "whole-complete-hq"
        yield "structured", {"format": format_, "strategy": "btopt", "hq": {"max_price_evaluations": 0},
                             "scenario": "sticky", "expected_error": "SearchLimitExceeded"}, "runtime-codec-sticky"
        yield "structured", {"format": format_, "rep_beam_search": True}, "legacy-beam-controls"
        for kind in ("raw", "full"):
            for use_set in (False, True):
                yield "dict-" + kind, {"format": format_, "dictionary_kind": kind, "use_dictionary_set": use_set,
                                       "dictionary_id": 77 if kind == "full" else 0, "strategy": "fast",
                                       **({"expected_error": "NeedDictionary"} if kind == "raw" and use_set else {})}, "dictionary"
        yield "dict-raw", {"format": format_, "dictionary_kind": "raw", "dictionary_id": 0, "strategy": "fast"}, "raw-id-zero"
        yield "tiny", {"format": format_, "dictionary_kind": "metadata", "dictionary_id": 77, "selection": "raw_or_rle"}, "metadata-dictionary"
        yield "tiny", {"format": format_, "dictionary_kind": "metadata", "dictionary_id": 77, "selection": "raw_or_rle", "content_size": True,
                       "scenario": "concat", "frames": 2}, "exact-metadata-next-frame"
        for kind, use_set in (("raw", False), ("full", False), ("full", True)):
            yield "dict-" + kind, {"format": format_, "dictionary_kind": kind, "use_dictionary_set": use_set,
                                   "dictionary_id": 0 if kind == "raw" else 77, "strategy": "fast", "content_size": True,
                                   "scenario": "concat", "frames": 2}, "exact-preset-next-frame"
        for selection in ("auto", "raw_or_rle", "literal_only", "fast_compressed"):
            yield "dict-raw-short", {"format": format_, "dictionary_kind": "raw", "dictionary_id": 0,
                                     "content_size": True, "selection": selection, "block_size": 32, "job_size": 32}, "single-segment-dictionary-window"
        for known in (False, True):
            yield "seal", {"format": format_, "scenario": "seal", "content_size": known, "selection": "raw_or_rle", "input_chunks": [8192]}, "unsealed-full-job"
        yield "seal", {"format": format_, "scenario": "pledge_lookahead", "content_size": True,
                       "selection": "raw_or_rle", "input_chunks": [8192]}, "invalid-pledge-lookahead"
        yield "seal", {"format": format_, "scenario": "input_lookahead", "max_input_len": 8192,
                       "selection": "raw_or_rle", "input_chunks": [8192]}, "invalid-input-limit-lookahead"
        yield "credit", {"format": format_, "scenario": "credit", "selection": "raw_or_rle", "max_inflight_jobs": 1,
                          "max_inflight_bytes": 8192, "input_chunks": [8192], "record_every": 32}, "last-byte-credit"
        yield "partial", {"format": format_, "scenario": "partial_credit", "max_inflight_bytes": 777,
                           "input_chunks": [777], "selection": "raw_or_rle"}, "recoverable-partial-credit"
        yield "structured", {"format": format_, "scenario": "flush", "flush_offsets": [31, 257]}, "explicit-flush-boundaries"
        yield "structured", {"format": format_, "scenario": "flush", "flush_offsets": [None]}, "empty-final-after-flush"
        yield "credit", {"format": format_, "scenario": "move", "input_chunks": [8192], "strategy": "fast"}, "active-value-move"
        yield "tiny", {"format": format_, "scenario": "reset"}, "reset-reuse"
        yield "tiny", {"format": format_, "scenario": "concat", "frames": 3}, "next-frame-counters"
        yield "structured", {"format": format_, "scenario": "pending_retry", "max_pending_output_len": 8,
                              "selection": "raw_or_rle", "input_chunks": [8192]}, "front-cap-retry"
        yield "tiny", {"format": format_, "max_input_len": 2, "expected_error": "OutputLimitExceeded"}, "stream-input-refusal"
        yield "tiny", {"format": format_, "max_output_len": 2, "expected_error": "OutputLimitExceeded"}, "stream-output-refusal"
        yield "tiny", {"format": format_, "max_input_len": 2, "scenario": "input_retry"}, "stream-input-raise-retry"
        yield "tiny", {"format": format_, "max_output_len": 2, "scenario": "output_retry"}, "stream-output-raise-retry"
        yield "credit", {"format": format_, "max_job_count": 1, "scenario": "jobs_retry"}, "job-count-raise-retry"
        yield "tiny", {"format": format_, "content_size": True, "pledge_delta": 1, "expected_error": "SizeMismatch"}, "short-pledge"
        yield "tiny", {"format": format_, "content_size": True, "pledge_delta": -1, "expected_error": "SizeMismatch"}, "long-pledge"
        for size in (262144, 1048576, 4194304):
            yield "long-" + str(size), {"format": format_, "strategy": "fast", "input_chunks": [8192], "output_chunks": [4096],
                                       "record_every": 32, "window_log": 15, "max_match_history_len": 32768}, "actual-bounded-history"
        yield "history", {"format": format_, "strategy": "fast", "window_log": 17, "max_match_history_len": 131072,
                           "input_chunks": [8192], "output_chunks": [257]}, "full-window-history"
        yield "large-sequences", {"format": format_, "strategy": "fast", "block_size": 8192, "job_size": 8192,
                                  "window_log": 15, "max_match_history_len": 32768, "input_chunks": [8192], "output_chunks": [257]}, "large-sequence-reemission"
    yield "tiny", {"scenario": "skippable", "frames": 2}, "standard-skippable-concat"
    yield "tiny", {"format": "magicless", "scenario": "skippable", "frames": 2, "expected_error": "InvalidBlockPlan"}, "magicless-skippable-refusal"
    yield "tiny", {"scenario": "concat", "frames": 2, "max_input_len": 15, "expected_error": "OutputLimitExceeded"}, "cumulative-input-across-frames"
    yield "tiny", {"scenario": "skippable", "frames": 2, "max_output_len": 32, "expected_error": "OutputLimitExceeded"}, "skippable-output-quota"
    yield "credit", {"scenario": "flush", "flush_offsets": [8192], "max_job_count": 2, "expected_error": "OutputLimitExceeded"}, "partial-empty-job-limit"
    yield "tiny", {"scenario": "flush", "flush_offsets": [None], "max_job_count": 1, "expected_error": "OutputLimitExceeded"}, "empty-final-job-limit"
    yield "tiny", {"max_working_memory": 0, "expected_error": "WorkingMemoryLimitExceeded", "scenario": "sticky"}, "heap-sticky"
    yield "mixed", {"max_working_memory": 1024 * 1024, "expected_error": "WorkingMemoryLimitExceeded", "scenario": "sticky"}, "runtime-heap-sticky"
    for field, value in (("worker_count", 0), ("worker_count", 65), ("job_size", 0), ("max_inflight_jobs", 0), ("max_inflight_bytes", 0)):
        yield "tiny", {field: value, "expected_error": "InvalidBlockPlan"}, "invalid-options"


def defaults(overrides, payload):
    c = {"scenario": "normal", "format": "standard", "selection": "auto", "strategy": "auto", "checksum": True,
         "content_size": False, "block_size": 4096, "job_size": 8192, "worker_count": 3, "max_inflight_jobs": 4,
         "max_inflight_bytes": 32768, "max_working_memory": 256 * 1024 * 1024, "window_log": 15,
         "max_match_history_len": 32768, "input_chunks": [1, 7, 31, 257, 8192], "output_chunks": [0, 1, 3, 257],
         "record_every": 1, "frames": 1, **overrides}
    if c.get("flush_offsets") == [None]:
        c["flush_offsets"] = [len(payload)]
    return c


def protocol_checks(row, c):
    checks = row["invariants"]
    for field in ("progress_accounting", "caller_guards", "accepted_prefix_poison", "profile_bounds"):
        require(checks[field], ("public protocol invariant", field))
    if row["initialized"]:
        require(checks["header_gate"], "header complete before input ownership/worker startup")
    expected = c.get("expected_error")
    require(row["error"] == expected, ("exact expected terminal error", expected, row["error"]))
    if expected and (row.get("final_snapshot") or {}).get("parallel", {}).get("failed"):
        require(checks["sticky_zero_progress"], "sticky failure repeat has zero accepted/delivered progress")
    required = {"seal": "full_job_wait", "credit": "last_byte_credit", "partial_credit": "partial_credit_recovery",
                "pending_retry": "front_retry_no_reencode", "move": "active_move", "reset": "reset_reuse",
                "input_retry": "stream_limit_recovery", "output_retry": "stream_limit_recovery", "jobs_retry": "stream_limit_recovery",
                "pledge_lookahead": "invalid_offer_did_not_seal", "input_lookahead": "invalid_offer_did_not_seal"}
    if c["scenario"] in required and expected is None:
        require(checks[required[c["scenario"]]], ("scenario invariant", c["scenario"]))


def incremental(campaign):
    payloads, dictionaries = fixtures(campaign.reference)
    for kind, data in dictionaries.items():
        (campaign.directory / ("dictionary-" + kind + ".bin")).write_bytes(data)
    for name, data in payloads.items():
        (campaign.directory / (name + ".input")).write_bytes(data)
    peak, sequence_peak, history_rows = 0, 0, {}
    for index, (fixture, overrides, scope) in enumerate(matrix()):
        name = f"stream-{index:03d}-{fixture}-{scope}"
        if campaign.args.case_filter and campaign.args.case_filter not in name:
            continue
        payload = payloads[fixture]
        c = defaults(overrides, payload)
        kind = c.get("dictionary_kind", "none")
        dictionary = dictionaries.get(kind, b"")
        if dictionary:
            c["dictionary_path"] = str(campaign.directory / ("dictionary-" + kind + ".bin"))
        entry = {"name": name, "scope": scope, "settings": c, "input": identity(campaign.directory / (fixture + ".input"))}
        try:
            output = campaign.directory / (name + ".zst")
            row = campaign.call(name, c, campaign.directory / (fixture + ".input"), output)
            entry["probe"] = row
            protocol_checks(row, c)
            require(row["borrowed_input_and_dictionary_preserved"], "borrowed dictionary/input lifetime")
            if scope == "runtime-heap-sticky":
                require(row["initialized"] and row["final_snapshot"]["parallel"]["failed"] and row["invariants"]["sticky_zero_progress"],
                        "real post-initialization heap failure and repeatable zero progress")
            if scope == "runtime-codec-sticky":
                require(row["initialized"] and row["final_snapshot"]["parallel"]["failed"] and row["invariants"]["sticky_zero_progress"] and
                        row["control_profile"]["price_limit_refusals"] > 0, "real worker codec refusal and sticky zero progress")
            peak = max(peak, row["observed_peak_active_workers"])
            checked = []
            wire = output.read_bytes()
            entry["wire"] = identity(output)
            for interval in row["frames"]:
                start, size = interval["wire_start"], interval["wire_bytes"]
                plaintext = payload[interval["input_start"]:interval["input_start"] + interval["input_bytes"]]
                result = inspect_frame(campaign.reference, wire[start:start + size], plaintext, c, dictionary,
                                       row["dictionary_id"], interval["pledged_input_len"])
                checked.append(result)
                sequence_peak = max(sequence_peak, result["max_physical_sequence_count"])
            entry["independent_frames"] = checked
            if c.get("expected_error") is None:
                require(checked and row["self_decode_verified"], "complete successful public frame decode")
                stream = inspect(wire, c["format"])
                require(stream["frame_count"] == len(row["frames"]) and len(stream["skippable_frames"]) == len(row["skippable"]),
                        "complete physical data/skippable frame count")
                for physical, interval in zip(stream["frames"], row["frames"]):
                    require(physical["start_byte"] == interval["wire_start"] and physical["serialized_bytes"] == interval["wire_bytes"],
                            "reported frame interval matches independent physical extent")
                whole_plaintext = b"".join(payload[f["input_start"]:f["input_start"] + f["input_bytes"]] for f in row["frames"])
                entry["whole_stream_reference_decode"] = campaign.reference.decode(wire, whole_plaintext, c["format"], dictionary)
                require(entry["whole_stream_reference_decode"]["complete_contents_verified"], "whole stream complete plaintext/exact consumption")
                for control in ("worker1", "failing_io"):
                    path = Path(str(output) + "." + control + ".zst")
                    require(path.read_bytes() == wire, ("same explicit job/flush geometry wire", control))
                    entry[control + "_wire"] = identity(path)
                for control in row["same_geometry_controls"]:
                    require(control is not None and control["failure"] is None and control["wire_equal"], "successful same-geometry control")
                    p = control["snapshot"]["parallel"]["profile"]
                    require(p["serial_fallback"] and p["workers_started"] == 0 and p["peak_active_workers"] == 0,
                            "real synchronous control with zero actual OS workers")
                    require(p["configured_workers"] == (1 if control["name"] == "worker1" else c["worker_count"]),
                            "failing-Io preserves caller worker setting")
                if scope == "large-sequence-reemission":
                    require(max(result["max_physical_sequence_count"] for result in checked) >= 1248, "actual large Sequence_Count regression")
                if scope == "full-window-history":
                    require(row["control_emitted"]["history_sequences"] > 0 and row["control_emitted"]["max_distance"] > 65535, "actual full-window wire history distance")
                if scope == "actual-bounded-history":
                    history_rows.setdefault(c["format"], []).append((len(payload), row["final_snapshot"]["parallel"]))
                if scope in ("dictionary", "raw-id-zero", "exact-preset-next-frame"):
                    require(row["control_emitted"]["dictionary_sequences"] > 0, "actual emitted preset-dictionary references")
                if c["scenario"] in ("seal", "pledge_lookahead", "input_lookahead"):
                    require(len(checked) == 1 and checked[0]["envelope"]["frames"][0]["blocks"][-1]["block_size_field"] != 0,
                            "finish seals the full job without an extra empty final block")
                if c["scenario"] == "flush" and c["flush_offsets"] and c["flush_offsets"][-1] == len(payload):
                    require(checked[-1]["envelope"]["frames"][0]["blocks"][-1]["block_size_field"] == 0,
                            "finish after end flush has exactly one empty final block")
            entry["status"] = "passed"
        except Exception as err:
            entry.update(status="failed", diagnostic=repr(err))
        campaign.results.append(entry)
    memory_checks = []
    for format_, rows in history_rows.items():
        rows.sort()
        if len(rows) != 3:
            continue
        memory = {"format": format_, "lengths": [n for n, _ in rows], "snapshots": [q for _, q in rows]}
        try:
            for length, q in rows:
                require(q["history_window_len"] == 32768 and q["logical_history_bytes"] <= q["history_window_len"], "actual rolling history bounded by configured H")
                require(q["logical_history_end"] == length and q["logical_history_bytes"] == min(length, q["history_window_len"]),
                        "actual accepted rolling history extent")
                require(q["retained_history_capacity"] >= q["logical_history_bytes"], "observed capacity covers actual retained history; no capacity=H assumption")
                require(q["profile"]["accepted_input_bytes"] == length, "real long input was accepted")
            for field in ("retained_input_capacity", "retained_job_output_capacity", "retained_history_capacity", "retained_front_capacity"):
                require(len({q[field] for _, q in rows}) == 1, ("retained capacity stable across real increasing input", format_, field))
            peaks = [q["profile"]["peak_requested_bytes"] for _, q in rows]
            require(max(peaks) <= min(peaks) + 131072, ("real requested heap remains bounded across input lengths", peaks))
            memory["stable_retained_capacities"] = True
        except Exception as err:
            memory["diagnostic"] = repr(err)
            campaign.results.append({"name": "bounded-history-" + format_, "scope": "actual-long-input-memory", "status": "failed", "diagnostic": repr(err)})
        memory_checks.append(memory)
    parallel_supported = any(row.get("probe", {}).get("target_supports_parallel") for row in campaign.results)
    worker_gate = peak > 1 or not parallel_supported or bool(campaign.args.case_filter)
    observed_strategies = sorted({row["settings"]["strategy"] for row in campaign.results if row["status"] == "passed" and
                                  row.get("settings", {}).get("strategy") in STRATEGIES})
    checks = {"matrix_explicit_strategies": list(STRATEGIES), "observed_explicit_strategies": observed_strategies,
              "campaign_scope": "filtered diagnostic subset" if campaign.args.case_filter else "complete matrix",
              "worker_overlap_required": parallel_supported and not bool(campaign.args.case_filter), "observed_peak_active_workers": peak,
              "campaign_actual_worker_overlap_passed": worker_gate, "max_independent_sequence_count": sequence_peak,
              "actual_long_input_memory_checks": memory_checks, "same_geometry_controls": "worker1 and std.Io.failing, same job/flush boundaries; no unconditional legacy serial wire claim"}
    if not worker_gate:
        campaign.results.append({"name": "campaign-worker-overlap", "scope": "actual-worker-observation", "status": "failed", "diagnostic": "No public observation of >1 actually active worker across complete campaign"})
    return campaign.finish("incremental-public-protocol", checks)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--source-epoch", default="unspecified")
    parser.add_argument("--reference", type=Path, default=Path("/home/passchaos/Work/zstd/lib/libzstd.so.1.6.0"))
    parser.add_argument("--reference-header", type=Path, default=Path("/home/passchaos/Work/zstd/lib/zstd.h"))
    parser.add_argument("--legacy-wire-gate", type=Path, help="saved native-final differential.json; --probe is a NEW build of old unchanged public probe")
    parser.add_argument("--case-filter")
    parser.add_argument("--timeout", type=int, default=240)
    args = parser.parse_args()
    require(identity(args.reference)["sha256"] == LIBRARY_SHA and identity(args.reference_header)["sha256"] == HEADER_SHA, "fixed libzstd 1.6.0/header identity")
    reference = Reference(args.reference, args.reference_header)
    require(reference.version == "1.6.0", "fixed reference version")
    require(xxh64(b"") == 0xEF46DB3751D8E999 and xxh64(b"abc") == 0x44BC2CF5AD770999, "independent XXH64 known answers")
    campaign = Campaign(args, reference)
    return legacy_gate(campaign) if args.legacy_wire_gate else incremental(campaign)


if __name__ == "__main__":
    raise SystemExit(main())
