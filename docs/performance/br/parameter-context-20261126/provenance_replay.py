"""Offline reservation/collector and actual V6 code-test receipt verification."""
from datetime import datetime, timezone
from pathlib import Path
import re

from archive_io import load, require, sha


def reservation(primary, controls, profile):
    receipt = load(primary, "reservation.json")
    start, end = receipt["quiet_start_unix"], receipt["quiet_end_unix"]
    require(receipt["original_collector_complete"] and receipt["initiated_unix"] <= start < end and
            "collector_resumed_unix" not in receipt and "parent_command" not in receipt,
            "Collector-complete reservation branch misclassified")
    first, second, analysis = receipt["primary"], receipt["extra_stages"][0], receipt["analysis"]
    require(len(receipt["extra_stages"]) == 1 and all(row["exit_code"] == 0 for row in (first, second, analysis)) and
            start <= first["started_unix"] < first["ended_unix"] <= second["started_unix"] < second["ended_unix"] <=
            analysis["started_unix"] < analysis["ended_unix"] <= end, "Reservation stages differ")
    require(first == load(primary, "campaign.command.json") and second == load(primary, "public-controls.command.json") and
            analysis == load(primary, "analysis.command.json"), "Separate stage receipts differ")
    intervals = []
    for pair in load(primary, "run-manifest.json")["pairs"]:
        for variant in pair["order"]:
            stem = "runs/" + Path(pair["processes"][variant]["path"]).stem
            command = load(primary, stem + ".command.json")
            begin, finish = command["started_unix"], command["started_unix"] + command["elapsed_seconds"]
            require(first["started_unix"] <= begin < finish <= first["ended_unix"], "Primary process escapes reserved stage")
            intervals.append({"phase": "primary", "report": stem + ".json", "started_unix": begin, "ended_unix": finish})
    for pair in load(primary, "control-manifest.json")["pairs"]:
        for variant in pair["order"]:
            stem = "timed/" + Path(pair["processes"][variant]["report"]).stem
            command = load(controls, stem + ".command.json")
            begin, finish = command["started_unix"], command["ended_unix"]
            require(second["started_unix"] <= begin < finish <= second["ended_unix"], "Control process escapes reserved stage")
            intervals.append({"phase": "public_controls", "report": stem + ".json", "started_unix": begin, "ended_unix": finish})
    require(len(intervals) == 216 and all(start <= row["started_unix"] < row["ended_unix"] <= end for row in intervals),
            "Measured process interval coverage differs")
    ordered = sorted(intervals, key=lambda row: row["started_unix"])
    require(all(a["ended_unix"] <= b["started_unix"] for a, b in zip(ordered, ordered[1:])), "Measured processes overlap")
    completed = load(primary, "collector/completion-receipt.json")
    collector = load(primary, "collector/final-manifest.json")
    require(collector["complete"] and len(collector["completed"]) == completed["collector_completed_entries"] == 216 and
            sha(primary["collector/final-manifest.json"]) == receipt["original_manifest_sha256"] == completed["collector_manifest_sha256"] and
            completed["parent_reported_original_collector_exit_code"] == completed["parent_reported_formal_exit_code"] == 0 and
            completed["parent_reported_formal_session"] == 35962, "Original collector/formal completion receipt differs")
    require(datetime.fromisoformat(load(controls, "identity-after.json")["utc"]).timestamp() < start and
            datetime.fromisoformat(load(profile, "identity-after.json")["utc"]).timestamp() < start,
            "Prepared control/profile validation does not precede formal timing")
    utc = lambda value: datetime.fromtimestamp(value, timezone.utc).isoformat()
    return {"quiet_start_unix": start, "quiet_end_unix": end, "quiet_start_utc": utc(start), "quiet_end_utc": utc(end),
            "reservation_branch": "collector-complete", "original_processes_signaled": False,
            "verified_process_wall_intervals": 216, "all_intervals_inside_reservation": True, "no_measured_process_overlap": True,
            "primary_processes": 180, "control_processes": 36, "original_collector_completed_entries": 216,
            "formal_parent_reported_session": 35962, "formal_parent_reported_exit_code": 0,
            "scope": "Recorded reserved development-host process intervals after original collector terminal completion; no stop/resume. Host-wide scheduler activity not independently traced."}, intervals


def code_tests(tests, primary, declared):
    receipt = load(tests, "validation-receipt.json")
    require(receipt["source_sha256"] == declared and receipt["source_after_matches_saved_before_build"], "V6 test source6 differs")
    require(all(code == 0 for code in receipt["observed_exit_codes"].values()), "V6 observed test exits differ")
    prefix_binding = load(tests, "preflight-log-binding.json")
    require(prefix_binding["receipt_expected_sha256"] == sha(tests["preflight-receipt-prefix.log"]) ==
            receipt["logs"]["preflight.log"] and prefix_binding["matching_final_log_prefix_bytes"] ==
            len(tests["preflight-receipt-prefix.log"]) and prefix_binding["final_log_sha256"] == sha(primary["preflight.log"]),
            "Progress snapshot prefix/full-byte binding differs")
    for name, digest in receipt["logs"].items():
        data = tests.get(name, primary.get(name))
        if name == "preflight.log":
            prefix = tests["preflight-receipt-prefix.log"]
            require(data.startswith(prefix) and sha(prefix) == digest, "Recorded progress-log prefix differs")
            continue
        require(data is not None and sha(data) == digest, "Actual V6 log hash differs")
    for name, count in (("cache-real-safe.log", 22), ("cache-fixture-safe.log", 10),
                        ("context-x86-fixture.log", 10), ("context-wasi-fixture-run.stderr", 10)):
        text = tests[name].decode()
        numbers = re.findall(r"^(\d+)/" + str(count) + r" .*\.\.\.OK$", text, flags=re.MULTILINE)
        require(numbers == [str(i) for i in range(1, count + 1)] and f"All {count} tests passed." in text, "Actual V6 focused test log differs")
    wasi = load(tests, "context-wasi-fixture-run.json")
    require(wasi["exit_code"] == 0 and tests["context-fixture.wasm"].startswith(b"\0asm") and
            sha(tests["context-fixture.wasm"]) == wasi["wasm_sha256"], "Actual V6 WASI module differs")
    require("Build Summary: 5/5 steps succeeded; 1715/1716 tests passed (1 skipped)" in tests["context-full-safe.log"].decode() and
            receipt["full_br_passed"] == 1715 and receipt["full_br_skip"] == 1 and receipt["native_real_with_imports"] == 22 and
            receipt["native_fixture"] == receipt["x86_fixture"] == receipt["wasi_fixture"] == 10, "Actual V6 full test receipt differs")
    return {"native_real_tests_with_imports": 22, "native_fixture_tests": 10, "x86_fixture_tests": 10, "wasi_fixture_tests": 10,
            "full_br_tests_passed": 1715, "full_br_tests_skipped": 1, "full_br_steps_succeeded": 5,
            "recorded_terminal_exit_codes": receipt["observed_exit_codes"], "wasi_module_sha256": wasi["wasm_sha256"],
            "progress_log_snapshot_binding": {"matches_complete_final_log": sha(primary["preflight.log"]) == receipt["logs"]["preflight.log"],
                "matching_prefix_bytes": len(tests["preflight-receipt-prefix.log"]),
                "snapshot_prefix_sha256": sha(tests["preflight-receipt-prefix.log"]),
                "final_full_log_sha256": sha(primary["preflight.log"]),
                "recorded_scope": "In-progress preflight stdout snapshot",
                "scope": "Root recorded this27-byte digest while preflight was still running, before the done line. It binds the exact prefix; later complete stdout is separately archive-hashed, not a failed actual test log."},
            "source_binding_limit": "SourceRoot/native source snapshot was obtained after native execution. Frozen source2193/source6 and later unchanged-source receipts are verified; instantaneous native compile/run identity was not measured.",
            "base_identity_scope": "Raw base-identity.json is the starting e083 source state, not the modified V6 source snapshot",
            "full_log_scope": "Original failed-command diagnostic retained; terminal 5/5 success1715/1skip recorded",
            "scope": "Offline hash/log/receipt verification only; no test, WASM, codec or build executed"}
