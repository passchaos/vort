#!/usr/bin/env python3
"""Brotli Large Window cross-block history QA, without timing or compilation.

Uses public probe output, independently identified input/wire files, and the
installed or explicitly supplied libbrotli decoder for complete plaintext.
Exact far-token counts are deliberately not inferred from total copy counts.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys

sys.dont_write_bytecode = True
from metadata_diff import Reference, Bits, window

ROOT = Path(__file__).resolve().parents[2]
QUALITIES = (2, 3, 4, 8, 10, 11)
MODES = [("q" + str(quality), "fast", quality) for quality in QUALITIES] + [
    ("legacy-fast", "fast", None), ("legacy-balanced", "balanced", None), ("legacy-ratio", "ratio", None)]
APIS = ("chunks", "reusable", "incremental")
ALL_APIS = APIS + ("one_shot",)
WIDTHS = (17, 25, 30)
BLOCKS = (4096, 32768, 65536)
SEED = 0x6A91BE31
SUFFIX = 258


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def identity(path):
    path = Path(path)
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": digest(data)}


def random_bytes(length, seed=SEED):
    data = bytearray()
    for _ in range(length):
        seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF
        data.append(seed >> 24)
    return bytes(data)


def fixture(prefix):
    history = random_bytes(prefix)
    repeat = history[:SUFFIX]
    require(len(repeat) == SUFFIX and history.find(repeat, 1) == -1, "unique exact earlier-block source")
    return history + repeat


def config(api, level, quality, width, block, prefix, large=True, event="none"):
    return {"api": api, "level": level, "quality": quality, "window_bits": width, "large_window": large,
            "block_len": block, "input_chunk": block, "prefix_len": prefix, "event": event,
            "exercise_new_stream": api in ("reusable", "incremental"), "max_total_working_memory": None}


def cases():
    for name, level, quality in MODES:
        for api in APIS:
            for width in WIDTHS:
                for block in BLOCKS:
                    yield f"far70000-{name}-{api}-w{width}-b{block}", "far70000", config(api, level, quality, width, block, 70000), "actual-far"
    for name, level, quality in MODES:
        for api in APIS:
            for prefix in (131056, 131057):
                yield f"window17-{prefix}-{name}-{api}", f"far{prefix}", config(api, level, quality, 17, 32768, prefix), "window-boundary" if prefix == 131056 else "expired-source"
        for event in ("flush", "metadata"):
            for width in WIDTHS:
                yield f"event-{event}-{name}-w{width}", "far70000", config("incremental", level, quality, width, 32768, 70000, event=event), "actual-far-event"
        for api in APIS:
            yield f"standard16-{name}-{api}", "far70000", config(api, level, quality, 16, 32768, 70000, large=False), "standard-control"
            yield f"tiny30-{name}-{api}", "tiny", config(api, level, quality, 30, 4096, 0), "tiny-memory"
    for quality in (0, 1):
        for api in APIS:
            for width in WIDTHS:
                yield f"blocklocal-q{quality}-{api}-w{width}", "far70000", config(api, "fast", quality, width, 32768, 70000), "block-local-control"
    for name, level, quality in MODES:
        for width in WIDTHS:
            c = config("one_shot", level, quality, width, 0, 70000)
            c["input_chunk"] = 4096  # Config carrier only; one-shot receives the complete input.
            yield f"far70000-{name}-one_shot-w{width}", "far70000", c, "actual-far-one-shot"


def source_identity():
    paths = [ROOT / "src/br.zig", ROOT / "src/core.zig", ROOT / "src/huffman.zig",
             ROOT / "tools/br/large_history_probe.zig", Path(__file__).resolve(), ROOT / "tools/br/metadata_diff.py"]
    paths += sorted((ROOT / "src/br").rglob("*.zig"))
    rows = [{"path": str(path.relative_to(ROOT)), "sha256": digest(path.read_bytes())} for path in paths]
    return {"sha256": digest(json.dumps(rows, sort_keys=True).encode()), "files": rows}


def far_evidence(row, c, payload, scope):
    summary = row["summary"]
    maximum = summary["max_lz77_distance"]
    advertised = (1 << c["window_bits"]) - 16
    require(maximum <= advertised and row["far_copy_count_lower_bound"] == int(maximum >= 65536) and
            row["far_copy_count_exact"] is None, "actual distance/format/count scope")
    evidence = {"actual_max_lz77_distance": maximum, "all_lz77_copy_count": summary["lz77_copy_count"],
                "actual_far_copy_count_lower_bound": int(maximum >= 65536), "actual_far_copy_count_exact": None,
                "token_observation": "public full-wire decoder summary; independent reference decoder verifies complete plaintext",
                "window_max_distance": advertised, "block_len": c["block_len"] if c["api"] in APIS else None,
                "far_implies_earlier_block": c["api"] in APIS and maximum >= 65536 and 0 < c["block_len"] <= 65536}
    if scope in ("actual-far", "actual-far-event", "window-boundary", "actual-far-one-shot"):
        require(maximum == c["prefix_len"] and maximum >= 65536 and summary["lz77_copy_count"] > 0,
                ("missing actual specified far-distance token", c, maximum))
        # Every decoded position before prefix_len is strictly less than this
        # distance. Thus this observed maximum can occur only in the suffix.
        # At any suffix position its source is within [0, SUFFIX), wholly in
        # the earlier random prefix. Stream routes additionally bound blocks.
        require(payload[c["prefix_len"]:] == payload[:SUFFIX] and len(payload) == c["prefix_len"] + SUFFIX,
                "deterministic far-token positional witness")
        evidence.update({"copy_position_lower_bound": c["prefix_len"], "copy_position_upper_bound_exclusive": len(payload),
                         "source_position_lower_bound": 0, "source_position_upper_bound_exclusive": SUFFIX,
                         "source_wholly_before_prefix_end": SUFFIX <= c["prefix_len"],
                         "position_proof": "decoded position >= observed distance; the entire preceding prefix is shorter than that distance"})
        if c["api"] == "one_shot":
            evidence["scope_note"] = "one-shot physical distance and earlier input source; API selects meta-blocks and cross-block provenance is not claimed"
    elif scope == "expired-source":
        require(c["prefix_len"] == advertised + 1 and maximum <= advertised, "expired source cannot emit out-of-window distance")
        evidence.update({"requested_copy_distance": c["prefix_len"], "expired_source_position": 0,
                         "expired_source_omitted_by_actual_distance": maximum < c["prefix_len"]})
    elif scope == "standard-control":
        require(maximum <= 65520 and not summary["large_window"], "standard window bounded distance")
    elif scope == "block-local-control":
        require(row["maximum_observed_history_len"] == 0, "q0/q1 retained earlier meta-block history")
        evidence["scope_note"] = "q0/q1 retain no earlier-block history; block-local copies remain allowed"
    return evidence


def verify_checkpoints(row, c, payload, scope):
    frames = []
    suffix = payload[-min(SUFFIX, len(payload)):]
    for point in row["checkpoints"]:
        reset = point["stage"] in ("next_stream_initial", "reset", "reusable_independent_frame_complete")
        source = suffix if reset else payload
        committed, retained = point["committed_input"], point["history_len"]
        require(0 <= retained <= committed <= len(source) and point["history_matches_committed_tail"] and
                point["history_source_start"] == committed - retained and
                point["history_sha256"] == digest(source[committed - retained:committed]) and
                point["history_capacity"] >= retained, ("diagnostic history tail", point))
        require(retained <= (1 << c["window_bits"]) - 16, "retained actual history exceeds window")
        if point["stage"] == "next_stream_initial":
            require(point["history_len"] == 0 and point["stream_input"] == 0, "new stream resets logical history")
        if point["stage"] == "event_acknowledged":
            require(point["committed_input"] == c["prefix_len"] and point["history_len"] >= c["prefix_len"],
                    "flush/metadata lost preceding full actual history")
        if scope == "expired-source" and point["stage"] == "prefix_admitted":
            # Bytes still buffered are not yet part of codec history. After
            # final publication every window17 retained tail starts above zero.
            point["source_zero_already_expired"] = point["history_source_start"] > 0
        frames.append(point)
    if scope == "expired-source" and c["api"] != "chunks":
        end = next((point for point in frames if point["stage"] in ("first", "reusable_first_complete")), None)
        if end and end["history_len"]:
            require(end["history_source_start"] > 0, "window17 failed to expire first source byte")
    if scope == "tiny-memory":
        require(row["maximum_observed_history_capacity"] < 1024 * 1024 and
                row["memory_profile"]["peak_requested_bytes"] < 128 * 1024 * 1024,
                "tiny window30 encoder allocated advertised one-GiB history")
    return frames


def self_check(reference):
    rows = list(cases())
    require(len(rows) == 450 and len({row[0] for row in rows}) == 450 and
            sum(row[2]["api"] == "one_shot" for row in rows) == 27, "deterministic history case matrix")
    require(all(row[2]["event"] == "none" and row[2]["block_len"] == 0 and not row[2]["exercise_new_stream"]
                for row in rows if row[2]["api"] == "one_shot"), "one-shot controls omit streaming-only settings")
    for prefix in (70000, 131056, 131057):
        payload = fixture(prefix)
        require(len(payload) == prefix + SUFFIX and payload[prefix:] == payload[:SUFFIX], "far input witness")
        for large in (False, True):
            wire = reference.encode(payload, b"", large=large)
            result = reference.decode(wire, payload, allow_large=large)
            require(result["complete_contents_verified"], "reference far fixture complete self-decode")
    return {"cases": len(rows), "streaming_cases": 423, "one_shot_cases": 27,
            "fixture_lengths": [70000 + SUFFIX, 131056 + SUFFIX, 131057 + SUFFIX],
            "seed": SEED, "repeat_bytes": SUFFIX}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--source-epoch", default="unspecified", help="parent-supplied source commit/freeze identity")
    parser.add_argument("--reference-encoder", type=Path)
    parser.add_argument("--reference-decoder", type=Path)
    parser.add_argument("--reference-common", type=Path)
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    reference = Reference(args.reference_encoder, args.reference_decoder, args.reference_common)
    checked = self_check(reference)
    if args.self_check:
        print(json.dumps({"self_check": "passed", "matrix": checked, "reference": reference.identity()}))
        return
    require(args.probe and args.directory, "--probe and --directory are required")
    probe, directory = args.probe.resolve(), args.directory.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    sources = source_identity()
    inputs = {"far70000": fixture(70000), "far131056": fixture(131056), "far131057": fixture(131057),
              "tiny": b"Large Window 30 bounded actual history.\x00\xff" * 3}
    for name, payload in inputs.items():
        (directory / (name + ".input")).write_bytes(payload)
    commands, results, failures = [], [], []
    for name, fixture_name, c, scope in cases():
        payload = inputs[fixture_name]
        input_path, config_path, wire_path = directory / (fixture_name + ".input"), directory / (name + ".json"), directory / (name + ".br")
        config_path.write_text(json.dumps(c, indent=2) + "\n")
        command = [str(probe), str(input_path), str(wire_path), str(config_path)]
        process = subprocess.run(command, capture_output=True, check=False, timeout=120)
        stdout_path, stderr_path = directory / (name + ".stdout"), directory / (name + ".stderr")
        stdout_path.write_bytes(process.stdout)
        stderr_path.write_bytes(process.stderr)
        commands.append({"command": command, "exit_code": process.returncode, "stdout": identity(stdout_path), "stderr": identity(stderr_path)})
        entry = {"name": name, "scope": scope, "settings": c, "input": identity(input_path), "config": identity(config_path)}
        try:
            require(process.returncode == 0, (name, "probe failed", process.returncode, process.stderr.decode(errors="replace")))
            row = json.loads(process.stdout)
            entry["probe"] = row
            require(row["error"] is None and row["config"] == c, (name, "probe route/settings/error", row))
            wire = wire_path.read_bytes()
            require(row["input_bytes"] == len(payload) and row["input_sha256"] == digest(payload) and
                    row["wire_bytes"] == len(wire) and row["wire_sha256"] == digest(wire) and
                    row["wire_bytes"] <= row["encoded_bound"] and row["self_decode_verified"] and row["borrowed_input_verified"],
                    (name, "probe input/wire identity"))
            header = window(Bits(wire))
            require(header["window_bits"] == c["window_bits"] and header["large_window"] == c["large_window"] and
                    row["summary"]["window_bits"] == c["window_bits"] and row["summary"]["large_window"] == c["large_window"],
                    (name, "wire format identity"))
            external = reference.decode(wire, payload, allow_large=c["large_window"])
            require(external["complete_contents_verified"], (name, "independent complete plaintext", external))
            entry.update({"wire": identity(wire_path), "wire_prefix": header, "reference_decode": external,
                          "actual_token_evidence": far_evidence(row, c, payload, scope),
                          "history_checkpoints": verify_checkpoints(row, c, payload, scope)})
            require(row["memory_profile"]["available"] and row["memory_profile"]["peak_requested_bytes"] >= row["memory_profile"]["live_requested_bytes"],
                    "requested-byte instrumentation")
            if c["api"] == "incremental":
                progress = row["progress"]
                require(progress["input_read"] == len(payload) and progress["output_written"] == len(wire) and
                        progress["zero_input_offers"] > 0 and progress["zero_output_offers"] > 0 and progress["caller_guards_verified"],
                        (name, "streaming progress/guards"))
                if c["event"] != "none":
                    require(progress["event_acknowledged"], (name, "event acknowledgement"))
                    require(row["summary"]["metadata_meta_block_count"] == int(c["event"] == "metadata"), "metadata event wire count")
            if c["exercise_new_stream"]:
                suffix = payload[-min(SUFFIX, len(payload)):]
                reset_path = Path(str(wire_path) + ".reset.br")
                reset = reset_path.read_bytes()
                reset_decode = reference.decode(reset, suffix, allow_large=c["large_window"])
                require(row["new_stream_matches_fresh_wire"] and row["reset_wire_bytes"] == len(reset) and
                        row["reset_wire_sha256"] == digest(reset) and row["reset_input_sha256"] == digest(suffix) and
                        reset_decode["complete_contents_verified"] and row["reset_summary"]["max_lz77_distance"] <= len(suffix),
                        (name, "independent continued encoder frame"))
                entry["reset"] = {"wire": identity(reset_path), "reference_decode": reset_decode,
                                  "matches_fresh_wire": True, "source_scope": "new independent frame has only its own suffix payload"}
            entry["status"] = "passed"
        except (AssertionError, json.JSONDecodeError, OSError) as error:
            entry["status"], entry["failure"] = "failed", str(error)
            failures.append({"name": name, "failure": str(error)})
        results.append(entry)
    source_after = source_identity()
    source_preserved = source_after == sources
    counts = {"cases": len(results), "passed": sum(row["status"] == "passed" for row in results), "failed": len(failures),
              "actual_far_cases": sum(row["scope"].startswith("actual-far") and row["status"] == "passed" for row in results),
              "actual_far_streaming_cases": sum(row["scope"] in ("actual-far", "actual-far-event") and row["status"] == "passed" for row in results),
              "one_shot_cases": sum(row["settings"]["api"] == "one_shot" for row in results),
              "one_shot_passed": sum(row["settings"]["api"] == "one_shot" and row["status"] == "passed" for row in results),
              "streaming_cases": sum(row["settings"]["api"] in APIS for row in results),
              "window_boundary_cases": sum(row["scope"] == "window-boundary" and row["status"] == "passed" for row in results),
              "independently_decoded_new_frames": sum("reset" in row for row in results)}
    report = {"schema": "vort.br.large-history-differential.v1", "created_utc": datetime.now(timezone.utc).isoformat(),
              "source_epoch": args.source_epoch, "source": sources, "source_after_sha256": source_after["sha256"],
              "sources_preserved": source_preserved, "probe": identity(probe), "python": platform.python_version(),
              "host": {"platform": platform.platform(), "machine": platform.machine()}, "reference": reference.identity(),
              "fixtures": [{"name": name, "seed": SEED if name != "tiny" else None, "file": identity(directory / (name + ".input")),
                            "prefix_len": len(payload) - SUFFIX if name != "tiny" else 0, "repeated_bytes": SUFFIX if name != "tiny" else 0}
                           for name, payload in inputs.items()],
              "matrix": {"quality_presets": list(QUALITIES), "legacy_levels": ["fast", "balanced", "ratio"],
                         "apis": list(ALL_APIS), "streaming_apis": list(APIS), "large_window_bits": list(WIDTHS), "block_input_chunks": list(BLOCKS),
                         "one_shot_scope": "27 complete-input routes: nine quality/legacy modes by three windows; no caller-selected meta-block size",
                         "q0_q1_controls": [0, 1], "window17_boundary": [131056, 131057], "metadata_flush_preserve_history": True},
              "evidence_scope": "actual full-wire summary maximum distance plus deterministic source-position bounds and independent full plaintext; exact far copy count is not claimed; history tail/capacity checkpoints are internal diagnostics",
              "measurement_scope": "actual bytes, requested-memory counters, functional progress; no throughput or timing measurement",
              "counts": counts, "failures": failures, "results": results, "commands": commands}
    path = args.report or directory / "differential.json"
    path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(path), **counts, "sources_preserved": source_preserved}))
    require(not failures and source_preserved, ("Large Window history gate failed", failures, source_preserved))


if __name__ == "__main__":
    main()
