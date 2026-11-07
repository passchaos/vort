#!/usr/bin/env python3
"""Bounded public stable-output matrix with calibrated requested-heap controls."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


reference = module("_stable_output_driver_reference", HERE / "reference.py")
fixtures = module("_stable_output_driver_fixtures", HERE / "fixtures.py")


def require(ok, detail):
    if not ok:
        raise AssertionError(detail)


def artifact(path):
    path = Path(path)
    return {"path": str(path.resolve()), "size": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def case_for(fixture, api="limited", scenario="normal", name=None, **controls):
    config = {"api": api, "scenario": scenario, "format": fixture["format"],
              "dictionary_path": fixture.get("dictionary_path"),
              "input_chunks": [3, 1, 17], "output_quanta": [0, 1, 3, 257]}
    if fixture["payload"]["size"] > 65536:
        config["input_chunks"], config["output_quanta"] = [1, 13, 257], [0, 257, 4096]
    config.update(controls)
    return {"name": name or f"{fixture['name']}-{api}-{scenario}", "config": config,
            "wire_path": fixture["wire_path"], "payload_path": fixture["payload_path"],
            "fixture": fixture, "expect": "success"}


def cases_for(receipt, preflight):
    by_name = {case["name"]: case for case in receipt["cases"]}
    selected = [by_name["frozen-numbered-json"], by_name["numbered-json-unknown-crc-magicless"],
                by_name["numbered-json-known-crc-standard"], by_name["empty-crc-standard"]] if preflight else receipt["cases"]
    cases = [case_for(fixture, api) for fixture in selected for api in ("stable", "limited")]
    if preflight:
        cases += [case_for(by_name["concatenated-skippable-standard"], api) for api in ("stable", "limited")]
    base = by_name["frozen-numbered-json"]
    for name in ("numbered-json-known-crc-standard", "numbered-json-unknown-crc-standard"):
        cases.append(case_for(by_name[name], scenario="footer"))
    cases += [case_for(base, scenario="warm_owned"), case_for(base, scenario="next_stream"),
              case_for(base, scenario="crossing_32"), case_for(base, scenario="overlap")]
    cases[-1]["expect"] = "bind_refused"
    cases.append(case_for(base, scenario="overlap_setter"))
    dictionary = by_name["frozen-full-dictionary"]
    cases.append(case_for(dictionary, scenario="dictionary_retry", recover_dictionary=True))
    cases[-1]["dictionary_retry_required"] = True
    short = case_for(base, name="stable-short-destination", destination_size=base["payload"]["size"] - 1)
    short["expect"] = "refused"
    cases.append(short)
    for name, malformed in receipt["negative"].items():
        case = case_for(by_name["numbered-json-known-crc-standard"], name=name)
        case["wire_path"] = malformed["wire"]["path"]
        case["expect"] = "ChecksumMismatch" if name == "corrupt_checksum" else "TruncatedFrame"
        cases.append(case)
        ignored = case_for(by_name["numbered-json-known-crc-standard"], name=name + "-ignore-checksum", ignore_checksum=True)
        ignored["wire_path"] = malformed["wire"]["path"]
        ignored["expect"] = "success" if name == "corrupt_checksum" else "TruncatedFrame"
        cases.append(ignored)
    expected_mismatch = case_for(base, name="expected-output-count-mismatch", expected_output_len=base["payload"]["size"] - 1)
    expected_mismatch["expect"] = "SizeMismatch"
    cases.append(expected_mismatch)
    repeats = 2**32 + 1
    capped = case_for(base, scenario="crossing_32", name="crossing-32-output-limit",
                      max_output_len=base["payload"]["size"] * repeats + base["payload"]["size"] - 1)
    capped["expect"] = "OutputLimitExceeded"
    cases.append(capped)
    if not preflight:
        stream = by_name["concatenated-skippable-standard"]
        first_data = next(frame for frame in stream["frames"] if not frame["skippable"])
        first_payload = by_name["numbered-json-known-crc-standard"]["payload_path"]
        stopped = case_for(stream, name="stop-after-first-frame-with-suffix", stop_after_first_frame=True)
        stopped["payload_path"] = first_payload
        stopped["first_frame_expected_bytes"] = first_data["header"]["content_size"]
        cases.append(stopped)
        excess = case_for(base, scenario="excess", name="excess-after-first-frame", stop_after_first_frame=True)
        cases.append(excess)
    return cases


def invoke(root, label, executable, bits, case):
    name = label + "-" + case["name"]
    config_path, output_path = root / (name + ".config.json"), root / (name + ".output")
    output_path.unlink(missing_ok=True)
    config_path.write_text(json.dumps(case["config"], sort_keys=True) + "\n")
    command = [str(executable.resolve()), str(Path(case["wire_path"]).resolve()),
               str(Path(case["payload_path"]).resolve()), str(output_path), str(config_path)]
    with (root / (name + ".stderr.log")).open("wb") as stderr:
        process = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=stderr, timeout=120)
    require(process.returncode == 0, (name, process.returncode, stderr.name))
    report = json.loads(process.stdout)
    require(report["pointer_bits"] == bits and report["borrowed_input_and_dictionary_preserved"], (name, "target/borrowed fixture integrity"))
    state = report["state"]
    require(state["requested_after_deinit"] == 0, (name, "decoder allocations leaked"))
    require(state["caller_guard_verified"], (name, "caller destination guard changed"))
    if case["expect"] == "success":
        require(report["error"] is None, (name, report["error"]))
        payload = Path(case["payload_path"]).read_bytes()
        expected = payload * (2 if case["config"]["scenario"] in ("next_stream", "crossing_32") else 1)
        require(output_path.read_bytes() == expected, (name, "actual payload"))
        if case["config"]["api"] != "owned":
            require(state["stable_binding_succeeded"] and state["stable_capacities_zero"], (name, "stable mode allocated decoded scratch/history"))
        if case["config"]["scenario"] == "footer":
            require(state["footer_zero_quantum_input"] >= 4, (name, "full destination did not consume checksum with zero quantum"))
        if case["config"]["scenario"] == "warm_owned":
            require(state["warm_history_capacity"] > 0 or state["warm_scratch_capacity"] > 0, (name, "warm owned path did not retain output storage"))
            require(state["before_bind_history_capacity"] > 0 or state["before_bind_scratch_capacity"] > 0,
                    (name, "reset released output storage before stable binding"))
            require(state["after_bind_history_capacity"] == 0 and state["after_bind_scratch_capacity"] == 0 and
                    state["after_bind_requested_live"] < state["before_bind_requested_live"], (name, "binding stable did not release old allocations"))
        if case["config"]["scenario"] == "crossing_32":
            require(state["seeded_repeat_count"] > 0 and state["seeded_input"] > 2**32 and state["seeded_output"] > 2**32,
                    (name, "derived seed did not cross 32-bit counters"))
            require(state["final_snapshot"]["input_received"] == state["seeded_input"] + len(Path(case["wire_path"]).read_bytes()) and
                    state["final_snapshot"]["output_written"] == state["seeded_output"] + len(payload),
                    (name, "actual next frame lost seeded cumulative progress"))
            require(state["final_snapshot"]["data_frame_count"] == state["seeded_repeat_count"] + 1,
                    (name, "actual next frame lost seeded member count"))
        if case["config"]["scenario"] in ("crossing_32", "next_stream"):
            require(state["next_destination_distinct"] and state["old_destination_preserved"],
                    (name, "next stream did not switch to independent caller storage"))
        if case["config"]["scenario"] == "overlap_setter":
            require(state["prefix_setter_refusal"] is not None and
                    state["prefix_snapshot_before_refusal"] == state["prefix_snapshot_after_refusal"],
                    (name, "overlapping setter did not preserve prefix state and old output binding"))
        if case["config"]["scenario"] == "excess":
            require(state["excess_input_unconsumed"], (name, "stopped decoder consumed excess input"))
        if case["config"]["scenario"] == "normal" and not case["config"].get("stop_after_first_frame"):
            require(state["final_snapshot"]["data_frame_count"] == case["fixture"]["sequences"]["data_frames"],
                    (name, "automatic data-frame count"))
        if case.get("dictionary_retry_required"):
            require(state["dictionary_retry_count"] == 1, (name, "dictionary request/recovery not exercised"))
    else:
        require(report["error"] is not None, (name, "negative control accepted"))
        if case["expect"] == "bind_refused":
            require(not state["stable_binding_succeeded"], (name, "prefix overlap did not fail at binding"))
        elif case["expect"] != "refused":
            require(report["error"] == case["expect"], (name, case["expect"], report["error"]))
        if case["config"]["scenario"] == "crossing_32":
            payload = Path(case["payload_path"]).read_bytes()
            delta = state["final_snapshot"]["output_written"] - state["seeded_output"]
            accepted = state["final_snapshot"]["input_received"] - state["seeded_input"]
            require(state["next_destination_distinct"] and state["old_destination_preserved"] and
                    0 <= delta < len(payload) and 0 <= accepted <= len(Path(case["wire_path"]).read_bytes()),
                    (name, "limited model progress or distinct destination invalid"))
            require(output_path.read_bytes() == payload + payload[:delta], (name, "model partial output prefix"))
            require(state["final_snapshot"]["data_frame_count"] == state["seeded_repeat_count"],
                    (name, "incomplete limited frame incremented member count"))
    if output_path.is_file():
        actual = artifact(output_path)
        require(report["output_sha256"] == actual["sha256"] and report["output_bytes"] == actual["size"], (name, "artifact digest"))
    else:
        actual = None
    event = {"name": name, "command": command, "exit_code": process.returncode,
             "expect": case["expect"], "report": report, "output": actual,
             "fixture_sequences": case["fixture"]["sequences"], "fixture_wire": artifact(case["wire_path"])}
    (root / (name + ".result.json")).write_text(json.dumps(event, indent=2, sort_keys=True) + "\n")
    return event


def calibrate(root, label, executable, bits, receipt):
    fixture = next(case for case in receipt["cases"] if case["name"] == "frozen-numbered-json")
    stable = case_for(fixture, name="calibration-stable", input_chunks=[1], output_quanta=[1])
    owned = case_for(fixture, api="owned", name="calibration-owned", input_chunks=[1], output_quanta=[1])
    events = [invoke(root, label, executable, bits, case) for case in (stable, owned)]
    stable_peak, owned_peak = (event["report"]["state"]["requested_peak"] for event in events)
    owned_observation = events[1]["report"]["state"]
    require(owned_observation["growing_resize_refusals"] + owned_observation["growing_remap_refusals"] > 0,
            (label, "owned control did not exercise allocator relocation"))
    require(0 < stable_peak < owned_peak, (label, "actual requested peaks must distinguish stable and owned", stable_peak, owned_peak))
    limited_stable = case_for(fixture, name="calibrated-quota-stable", input_chunks=[1], output_quanta=[1], max_working_memory=stable_peak)
    limited_owned = case_for(fixture, api="owned", name="calibrated-quota-owned", input_chunks=[1], output_quanta=[1], max_working_memory=stable_peak)
    limited_owned["expect"] = "WorkingMemoryLimitExceeded"
    events += [invoke(root, label, executable, bits, case) for case in (limited_stable, limited_owned)]
    require(all(event["report"]["state"]["requested_peak"] <= stable_peak for event in events[2:]),
            (label, "actual requested allocations exceeded calibrated quota"))
    return events, {"target": label, "stable_requested_peak": stable_peak, "owned_requested_peak": owned_peak,
                    "same_decoder_quota": stable_peak, "stable_succeeded": True, "owned_error": "WorkingMemoryLimitExceeded",
                    "scope": "Same actual decoder requested-heap quota, forced allocator relocation; caller output excluded; no RSS comparison"}


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
    cases = cases_for(receipt, args.preflight)
    probes = [("native", args.probe_native, 64)] + ([("x86", args.probe_x86, 32)] if args.probe_x86 else [])
    events, calibration = [], []
    journal = root / "events.jsonl"
    with journal.open("w") as output:
        for label, executable, bits in probes:
            current, measured = calibrate(root, label, executable, bits, receipt)
            calibration.append(measured)
            for case in cases:
                event = invoke(root, label, executable, bits, case)
                current.append(event)
                print(json.dumps({"target": label, "case": case["name"], "error": event["report"]["error"], "status": "ok"}), flush=True)
            for event in current:
                output.write(json.dumps(event, sort_keys=True) + "\n")
            output.flush()
            events += current
    report = {"schema": "vort.zstd.stable_output.matrix.v1", "status": "ok", "preflight": args.preflight,
              "utc": datetime.now(timezone.utc).isoformat(), "actual_command": [sys.executable, *sys.argv],
              "probes": [{"label": label, "pointer_bits": bits, **artifact(path)} for label, path, bits in probes],
              "reference_receipt": artifact(receipt["receipt_path"]), "reference": library.provenance(),
              "calibration": calibration, "events": len(events), "events_path": str(journal), "events_sha256": artifact(journal)["sha256"],
              "source_provenance": [artifact(path) for path in sorted(HERE.glob("*.py"))] + [artifact(HERE / "probe.zig")] +
                                   [artifact(path) for path in sorted((HERE / "probe_helpers").glob("*.zig"))] +
                                   [artifact(path) for path in sorted((HERE / "reference").glob("*.py"))]}
    path = root / "report.json"
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": "ok", "report": str(path), "events": len(events), "calibration": calibration}), flush=True)


if __name__ == "__main__":
    main()
