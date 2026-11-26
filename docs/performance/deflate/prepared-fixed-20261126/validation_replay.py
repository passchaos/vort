"""Replay final full/TERM/source-check and WASI module identities from packages."""
import re

from package_io import json_documents, load, require, sha


def verify(data):
    terminal, command = load(data, "final-full-exit.json"), load(data, "final-full.command.json")
    require(terminal["exit_code"] == 0 and terminal["status"] == "completed" and terminal["session_id"] == command["session_id"] == 46721 and
            terminal["argv"] == command["argv"] and terminal["cwd"] == command["cwd"], "Final actual full command/terminal differs")
    require(sha(data["final-full.stdout"]) == terminal["stdout_sha256"] and sha(data["final-full.stderr"]) == terminal["stderr_sha256"],
            "Final full output hash differs")
    summary = terminal["summary"]
    require(summary == {"steps_succeeded": 428, "steps_total": 428, "tests_passed": 6121, "tests_total": 6123, "tests_skipped": 2},
            "Actual final full counts differ")
    log = data["final-full.stderr"].decode() + data["final-full.stdout"].decode()
    require("428/428 steps succeeded" in log and "6121/6123 tests passed" in log, "Final full terminal log differs")
    interrupted = load(data, "first-full-interrupted.json")
    require(interrupted["session_id"] == 89296 and interrupted["signal"] == "SIGTERM" and interrupted["claimed_pass"] is False,
            "First interrupted full attempt misclassified")
    recheck = load(data, "final-source-recheck.json")
    require(recheck["matches_frozen_source"] and recheck["source_count"] == 2214 and not recheck["missing"] and
            not recheck["unexpected"] and not recheck["changed"] and sha(data["final-source.json"]) == recheck["manifest_file_sha256"],
            "Final source2214 freeze recheck differs")
    documents = json_documents(data["latest-wasi.stdout"])
    modules = [module for document in documents for module in document["results"]]
    require([module["label"] for module in modules] == ["budget", "matcher", "codec"] and
            all(document["status"] == "ok" and document["pointer_bits"] == 32 for document in documents), "Latest WASI order/schema differs")
    mapping = load(data, "wasm-map.json")
    for module in modules:
        content = data[mapping[module["wasm_path"]]]
        require(module["exit_code"] == 0 and sha(content) == module["wasm_sha256"] and len(content) == module["wasm_bytes"] and
                content.startswith(b"\0asm"), "Latest actual WASI module identity differs")
    counts = [int(value) for value in re.findall(r"All (\d+) tests passed\.", data["latest-wasi.stderr"].decode())]
    require(counts == [11, 7, 29], "Latest actual WASI stderr counts differ")
    return {"full_session": 46721, "full_exit_code": 0, "full_counts": summary,
            "full_prepared_native_ReleaseSafe_counts_recorded": terminal["prepared_native_ReleaseSafe_counts"],
            "latest_wasi_execution_order": [11, 7, 29], "latest_wasi_module_hashes": {module["label"]: module["wasm_sha256"] for module in modules},
            "first_full_interrupted_session": 89296, "first_full_signal": "SIGTERM",
            "scope": "Actual same-session full terminal and stdout/stderr hashes; old focused epoch kept separate. Latest direct native tests are Debug; latest WASI and prepared full targets ReleaseSafe, while full per-target build modes remain in original log."}
