#!/usr/bin/env python3
"""Audit completed reserved developer-host window and immutable gate targets."""
import gzip
import hashlib
import json
import math
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(payloads, screens, stage_binding, stage_verifier):
    load = lambda name: json.loads(payloads[name])
    reservation = load("reservation.json")
    settings, correction = load("settings.json"), load("label-correction.json")
    require(reservation["campaign_exit_code"] == reservation["analysis_exit_code"] == 0,
            "Quiet campaign/analysis not complete")
    start, end = reservation["quiet_start_unix"], reservation["quiet_end_unix"]
    require(start <= end <= reservation["collector_resumed_unix"], "Quiet end/collector restore interval differs")
    require(correction["unix_time"] < start and settings["comparison_scope"] == correction["new"],
            "Historical label correction not completed before sampling")
    require(hashlib.sha256(payloads["settings.json"]).hexdigest() == correction["settings_after_sha256"],
            "Corrected quiet settings hash differs")
    before = dict(settings)
    before["comparison_scope"] = correction["old"]
    require(hashlib.sha256((json.dumps(before, indent=2) + "\n").encode()).hexdigest()
            == correction["settings_before_sha256"], "Label-only settings correction differs")
    stage_settings = json.loads(screens["s4-compact/settings.json"])
    for key in ("variants", "primary_options", "target", "cpu", "sampling_cpu", "codec_threads",
                "rounds", "weak_rows_additional_rounds", "initial_iterations", "timing_scope", "sampler_order"):
        require(settings[key] == stage_settings[key], "Quiet S4 source/config/order changed: " + key)
    require(payloads["probe.zig"] == screens["common/probe.zig"]
            and payloads["provenance.zig"] == screens["common/provenance.zig"]
            and payloads["analyze.py"] == screens["s4-compact/analyze.py"]
            and payloads["build-results.json"] == screens["s4-compact/build-results.json"],
            "Quiet common harness/build identity differs from S4")

    # Shared S4 bytes were checked against actual quiet copies before packing.
    # Alias only immutable source/ELF/reference/input payloads; preserve every
    # original quiet report, argv and wall timestamp unchanged.
    combined = {name: value for name, value in screens.items() if name.startswith("common/")}
    combined.update({"quiet/" + name: value for name, value in payloads.items()})
    combined["quiet/candidate.elf.gz"] = screens["s4-compact/candidate.elf.gz"]
    combined["quiet/candidate-source-sha256.json"] = screens["s4-compact/candidate-source-sha256.json"]
    for name, value in screens.items():
        if name.startswith("s4-compact/source/"):
            combined["quiet/" + name[len("s4-compact/"):]] = value
    validated = stage_verifier(combined, "quiet", stage_binding)
    manifest = load("run-manifest.json")
    intervals = []
    for pair in manifest["pairs"]:
        ordered = {}
        for variant, record in pair["processes"].items():
            name = "runs/" + Path(record["path"]).with_suffix(".command.json").name
            command = load(name)
            a = command["started_unix"]
            duration = command["elapsed_seconds"]
            b = a + duration
            require(all(math.isfinite(value) for value in (a, duration, b)) and duration >= 0,
                    "Invalid quiet process wall interval")
            require(command["exit_code"] == 0 and start <= a <= b <= end,
                    "Quiet timed process lies outside reservation")
            require(command["command"][:3] == ["taskset", "-c", "2"], "Quiet argv CPU differs")
            argv = command["command"]
            require(Path(argv[3]).name == variant and len(argv[4:]) % 2 == 0,
                    "Quiet argv executable/shape differs")
            arguments = dict(zip(argv[4::2], argv[5::2]))
            require(set(arguments) == {"--input", "--output", "--source-revision", "--iterations", "--window"},
                    "Quiet argv option set differs")
            require(arguments["--source-revision"] == settings["variants"][variant]
                    and arguments["--iterations"] == "1" and arguments["--window"] == "16"
                    and Path(arguments["--input"]).name == pair["case"] + ".65536.plain"
                    and Path(arguments["--output"]).name == Path(record["path"]).name,
                    "Quiet argv source/input/output/lifecycle differs")
            ordered[variant] = (a, b)
            intervals.append({"case": pair["case"], "round": pair["round"], "variant": variant,
                              "started_unix": a, "ended_unix": b, "elapsed_seconds": duration, "exit_code": 0})
        first, second = pair["order"]
        require(ordered[first][1] <= ordered[second][0], "Quiet actual process order/overlap differs")
    require(len(intervals) == 180 and validated["verified_pairs"] == 90, "Quiet wall interval coverage differs")
    summary = validated["full_summary"]
    matrix = summary["matrix"][0]
    time_ratio = matrix["paired_geomean_ns_current_over_old"]
    time_ci = matrix["paired_round_block_bootstrap_95pct_ci"]
    speed = 1 / time_ratio
    speed_ci = [1 / time_ci[1], 1 / time_ci[0]]
    nci = next(row for row in summary["rows"] if row["case"] == "nci")
    nci_speed = 1 / nci["paired_geomean_ns_current_over_old"]
    worst = max(summary["rows"], key=lambda row: row["paired_geomean_ns_current_over_old"])
    control_min = 1 / worst["paired_geomean_ns_current_over_old"]
    checks = {"overall_throughput_at_least_3pct": speed >= 1.03,
              "overall_ci_excludes_parity": speed_ci[0] > 1,
              "control_throughput_at_least_0_98": control_min >= 0.98,
              "weak_nci_throughput_at_least_20pct": nci_speed >= 1.20,
              "wire_size_identity": matrix["geomean_encoded_bytes_current_over_old"] == 1}
    allowed = all(checks.values())
    return {"schema": "vort.modeled-search.reserved-quiet.v1", "full_summary": summary,
            "source_and_common_harness_same_as_s4": True,
            "reservation": reservation, "label_correction": correction,
            "wall_intervals": intervals, "all180_wall_intervals_within_quiet_window": True,
            "collector_restored_at_or_after_quiet_end": True,
            "observed_overall_throughput_ratio": speed, "observed_overall_throughput_ratio_ci": speed_ci,
            "observed_weak_nci_throughput_ratio": nci_speed,
            "minimum_control_throughput_ratio": control_min, "minimum_control_case": worst["case"],
            "gate_targets": {"overall_throughput": 1.03, "controls": 0.98, "weak_nci": 1.20},
            "gate_checks": checks, "failed_checks": [name for name, passed in checks.items() if not passed],
            "merge_allowed": allowed, "acceptance": "accepted" if allowed else "rejected",
            "inherited_raw_statistics_scope": summary["statistics_scope"],
            "actual_scope": "Completed temporary reservation of the same developer host, not an industry ranking or permanent dedicated-host claim. Original inherited analyzer text still says non-quiet; immutable reservation/argv/wall/restore records identify this window. Initial-wire-only full hashes; timed outputs length/mix."}
