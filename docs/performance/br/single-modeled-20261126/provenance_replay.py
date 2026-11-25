"""Check reservation intervals, startup history, collector and code-test receipts."""
from datetime import datetime, timezone
from pathlib import Path
import re

from archive_io import load, require, sha


def reservation(primary, controls):
    receipt = load(primary, "reservation.json")
    start, end = receipt["quiet_start_unix"], receipt["quiet_end_unix"]
    require(receipt["initiated_unix"] <= start < end <= receipt["collector_resumed_unix"], "Reservation/resume ordering differs")
    require(receipt["parent_pid"] == 3374522 and receipt["primary"]["exit_code"] == receipt["analysis"]["exit_code"] == 0 and
            len(receipt["extra_stages"]) == 1 and receipt["extra_stages"][0]["exit_code"] == 0, "Reservation stage receipt differs")
    stage_primary, stage_controls = receipt["primary"], receipt["extra_stages"][0]
    require(start <= stage_primary["started_unix"] <= stage_primary["ended_unix"] <=
            stage_controls["started_unix"] <= stage_controls["ended_unix"] <=
            receipt["analysis"]["started_unix"] <= receipt["analysis"]["ended_unix"] <= end,
            "Reserved stage intervals overlap or escape the window")
    intervals = []
    for pair in load(primary, "run-manifest.json")["pairs"]:
        for variant in pair["order"]:
            stem = "runs/" + Path(pair["processes"][variant]["path"]).stem
            command = load(primary, stem + ".command.json")
            begin = command["started_unix"]
            finish = begin + command["elapsed_seconds"]
            require(stage_primary["started_unix"] <= begin < finish <= stage_primary["ended_unix"], "Primary process escapes stage")
            intervals.append({"phase": "primary", "report": stem + ".json", "started_unix": begin, "ended_unix": finish})
    for pair in load(primary, "control-manifest.json")["pairs"]:
        for variant in pair["order"]:
            stem = "timed/" + Path(pair["processes"][variant]["report"]).stem
            command = load(controls, stem + ".command.json")
            begin, finish = command["started_unix"], command["ended_unix"]
            require(stage_controls["started_unix"] <= begin < finish <= stage_controls["ended_unix"], "Control process escapes stage")
            intervals.append({"phase": "public_controls", "report": stem + ".json", "started_unix": begin, "ended_unix": finish})
    require(len(intervals) == 216 and all(start <= row["started_unix"] < row["ended_unix"] <= end for row in intervals),
            "Not all 216 process wall intervals are reserved")
    ordered = sorted(intervals, key=lambda row: row["started_unix"])
    require(all(a["ended_unix"] <= b["started_unix"] for a, b in zip(ordered, ordered[1:])), "Measured processes overlap")
    ready = load(primary, "pre-reservation-ready.json")
    for name, digest in ready["samplers"].items():
        require(sha(primary[name]) == digest, "Ready sampler hash differs: " + name)
    plan = load(primary, "control-plan.json")
    require(plan["created_unix"] < start, "Controls were not predeclared before timing")
    startup = load(primary, "startup-attempts/001-reservation.json")
    require("quiet_start_unix" not in startup and "primary" not in startup and "analysis" not in startup and
            "extra_stages" not in startup and startup["initiated_unix"] <= startup["collector_resumed_unix"] < start and
            b"Parent stop was not observed; sampling must not start" in primary["startup-attempts/001-driver.log"],
            "Untimed startup acknowledgement attempt misclassified")
    collector, completion = load(primary, "collector/final-manifest.json"), load(primary, "collector/completion-receipt.json")
    require(collector["complete"] and len(collector["completed"]) == completion["completed_entries"] == 216 and
            completion["original_collector_complete"] and completion["parent_reported_exit_code"] == 0 and
            sha(primary["collector/final-manifest.json"]) == completion["manifest_sha256"], "Collector completion receipt differs")
    utc = lambda value: datetime.fromtimestamp(value, timezone.utc).isoformat()
    return {"quiet_start_unix": start, "quiet_end_unix": end, "quiet_start_utc": utc(start), "quiet_end_utc": utc(end),
            "collector_resumed_unix": receipt["collector_resumed_unix"], "verified_process_wall_intervals": 216,
            "primary_processes": 180, "control_processes": 36, "all_intervals_inside_reservation": True,
            "no_measured_process_overlap": True, "startup_001_timed_processes": 0,
            "startup_001_scope": "SIGSTOP acknowledgement race before quiet_start; finally CONT recorded; no timed sample",
            "collector_original_completed_entries": 216, "collector_original_reported_exit_code": 0,
            "scope": "Recorded pidfd-targeted reservation and wall intervals, not independent host-wide scheduler tracing"}, intervals


def code_tests(tests, declared):
    receipt = load(tests, "validation-receipt.json")
    before = load(tests, "validation-source-before-platform-full.json")
    native = load(tests, "single-native-receipt.json")
    wasi = load(tests, "single-wasi-run.json")
    require(receipt["source_hashes"] == before["hashes"] == declared and receipt["source_before_after_unchanged"],
            "Actual22 source identity differs")
    require(set(receipt["observed_exit_codes"]) == {"native", "x86", "wasi_build", "wasi_run", "full_br"} and
            all(code == 0 for code in receipt["observed_exit_codes"].values()), "Actual22 terminal exits differ")
    for name, digest in receipt["logs"].items():
        require(sha(tests[name]) == digest, "Actual22 log hash differs: " + name)
    for name in ("single-native-safe.log", "single-x86-safe.log", "single-wasi-run.stderr"):
        text = tests[name].decode()
        matches = re.findall(r"^(\d+)/22 .*\.\.\.OK$", text, flags=re.MULTILINE)
        require(matches == [str(i) for i in range(1, 23)] and "All 22 tests passed." in text, "Actual22 test log differs")
    require(native["exit_code"] == 0 and native["passed_tests"] == receipt["native_tests"] ==
            receipt["x86_tests"] == receipt["wasi_tests"] == 22 and
            native["log_sha256"] == sha(tests["single-native-safe.log"]) and
            "after native completion" in native["source_snapshot_scope"], "Native snapshot limitation differs")
    require(wasi["exit_code"] == 0 and sha(tests["single-safe.wasm"]) == wasi["wasm_sha256"] and
            tests["single-safe.wasm"].startswith(b"\0asm"), "Actual WASI module identity differs")
    full = tests["full-br-single-safe.log"].decode()
    require("Build Summary: 5/5 steps succeeded; 1710/1711 tests passed (1 skipped)" in full and
            receipt["full_br_passed"] == 1710 and receipt["full_br_skipped"] == 1,
            "Full Brotli terminal summary differs")
    return {"native_tests_recorded": 22, "x86_tests_recorded": 22, "wasi_tests_recorded": 22,
            "full_br_tests_passed": 1710, "full_br_tests_skipped": 1, "full_br_steps_succeeded": 5,
            "all_recorded_terminal_exit_codes": receipt["observed_exit_codes"], "wasi_module_sha256": wasi["wasm_sha256"],
            "native_source_binding": "Source snapshot after native completion; instantaneous native source identity was not measured",
            "x86_wasi_full_source_binding": "Nine hashes measured before platform/full checks and unchanged after; match frozen primary v5",
            "old_base_identity_scope": "Raw base-identity.json is the v4 starting parent, not v5",
            "full_log_diagnostic_scope": "Original failed-command diagnostic text retained; recorded terminal 5/5 success authoritative",
            "scope": "Offline validation of actual logs, module bytes and receipts; no tests, WASM, codecs or builds executed"}
