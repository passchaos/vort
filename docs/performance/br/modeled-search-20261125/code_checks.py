#!/usr/bin/env python3
"""Audit retained code-test outputs/source identities; never run tests/WASM."""
import hashlib
import json
import re


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(payloads):
    identity = json.loads(payloads["final/source-snapshot-identity.json"])
    for path, expected in identity["source_sha256"].items():
        require(hashlib.sha256(payloads["source/" + path]).hexdigest() == expected, "Final code-test source differs")
    x86 = payloads["final/modeled-pair-x86-final.log"].decode()
    wasi_stderr = payloads["final/modeled-pair-wasi-final-run.stderr"].decode()
    wasi = json.loads(payloads["final/modeled-pair-wasi-final-run.json"])
    require("All 14 tests passed." in x86 and len(re.findall(r"^\d+/14 .*\.\.\.OK$", x86, re.M)) == 14, "x86 test log incomplete")
    require("All 14 tests passed." in wasi_stderr and len(re.findall(r"^\d+/14 .*\.\.\.OK$", wasi_stderr, re.M)) == 14, "WASI test log incomplete")
    require(wasi["exit_code"] == 0 and hashlib.sha256(payloads["final/modeled-pair-final.wasm"]).hexdigest() == wasi["wasm_sha256"], "WASI result/module binding differs")
    full = payloads["final/full-br-paired-safe.log"].decode()
    require("Build Summary: 5/5 steps succeeded; 1710/1711 tests passed (1 skipped)" in full and "test-br success" in full, "Full Brotli terminal result differs")
    native_raw = payloads["final/modeled-pair-native-final.log"].decode()
    native_tool = json.loads(payloads["final/modeled-pair-native-final-tool-receipt.json"])
    require(native_tool["test_result"]["exit_code"] == 0
            and native_tool["test_result"]["output"] == native_raw,
            "Recovered native stdout/exit receipt differs")
    require("All 14 tests passed." in native_raw
            and len(re.findall(r"^\d+/14 .*\.\.\.OK$", native_raw, re.M)) == 14,
            "Recovered native fourteen-test stdout incomplete")
    native = {"passed_tests": 14, "exit_code": 0,
              "shell_command": native_tool["shell_command"],
              "command_recorded_at": native_tool["command_recorded_at"],
              "completion_observed_at": native_tool["completion_observed_at"],
              "exec_session_id": native_tool["exec_session_id"],
              "source_identity_scope": native_tool["source_identity_scope"],
              "evidence_kind": native_tool["evidence_kind"]}
    return {
        "native": native,
        "x86_passed": 14, "wasi_passed": 14,
        "wasi_sha256": wasi["wasm_sha256"],
        "full_br_passed": 1710, "full_br_skipped": 1,
        "full_br_raw_failed_command_text_retained": "failed command:" in full,
        "code_source_snapshot": identity,
        "scope": "Original test outputs/receipts and archive-time mother source snapshot. All frozen performance stage sources remain separate. No test, ELF, WASM, build or Git execution during this audit.",
    }
