#!/usr/bin/env python3
"""Exercise rejection of incomplete, mismatched or fabricated sample evidence."""

from __future__ import annotations

import copy
import hashlib
from pathlib import Path
import tempfile
import unittest

from sample_gate import EvidenceError, validate


class SampleGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory(prefix="vort-sample-gate-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.input = self.root / "input.bin"
        self.input.write_bytes(b"independent evidence\n")
        self.reference = self.root / "reference.so"
        self.reference.write_bytes(b"file identity fixture")
        self.executable = self.root / "benchmark"
        self.executable.write_bytes(b"executable identity fixture")
        self.manifest = {"input_sets": [{
            "input_bytes": self.input.stat().st_size,
            "input_sha256": hashlib.sha256(self.input.read_bytes()).hexdigest(),
            "frozen_path": str(self.input),
        }]}

    def report(self, codec: str = "zstd") -> dict:
        reference = {
            "requested_path": str(self.reference),
            "canonical_file_path": str(self.reference),
            "file_sha256": hashlib.sha256(self.reference.read_bytes()).hexdigest(),
            "successful_open_argument": str(self.reference),
            "loaded_identity": None,
            "dependencies_verified": False,
            "version": "fixture-reference",
        }
        roles = ["zstd"] if codec == "zstd" else ["brotli_encoder", "brotli_decoder", "brotli_common"]
        times = [(30, 41), (10, 11), (20, 31), (10, 21), (40, 51)]
        if codec == "zstd":
            times = times[:4]
        if codec == "zstd":
            header = {"window_size": 1024, "content_size": self.input.stat().st_size,
                      "content_checksum": False, "dictionary_id": 0}
            settings = {
                "level": 3, "api": "level_policy", "requested_strategy": None,
                "requested_fast_acceleration": None, "requested_native_selection": None,
                "resolved_primary": {"content_checksum": False, "include_content_size": True,
                                     "window_log": None, "max_match_history_len": None,
                                     "max_total_working_memory": None, "selection": "auto",
                                     "block_size_max": 131072, "dictionary_id": 0,
                                     "match_search_budget": 0, "rep_beam_search": False,
                                     "strategy": "auto", "fast_acceleration": None, "hq": None,
                                     "control_profile_enabled": False, "memory_profile_enabled": False},
                "internal_candidate_settings": "public_auto_level_policy", "wire_header": header,
                "reference": {"api": "ZSTD_compress", "level": 3,
                              "internal_parameters": "library_default_level_preset", "wire_header": header},
            }
        else:
            settings = {"planned_quality": 8, "vort_api": "brEncodePlannedStreamWithOptionsAlloc",
                        "vort_level": "fast", "vort_mode": "generic", "vort_command_state_max_input_kib": 255,
                        "vort_command_state_override_requested": None, "vort_window_bits": None,
                        "vort_large_window": False, "vort_metadata_bytes": 0,
                        "vort_max_total_working_memory": None, "vort_memory_profile_enabled": False,
                        "vort_hq_enabled": False, "reference_quality": 8, "reference_lgwin": 22,
                        "reference_mode": 0}
        return {
            "schema": "vort.codec_encode_samples", "version": 1, "codec": codec,
            "provenance": {"optimize": "ReleaseFast", "benchmark_threads": 1,
                           "target_arch": "x86_64", "cpu_model": "fixture CPU",
                           "command": "fixture command", "zig_version": "0.16.0",
                           "executable_sha256": hashlib.sha256(self.executable.read_bytes()).hexdigest()},
            "references": [dict(reference, role=role) for role in roles],
            "rows": [{
                "case": "frozen", "input_bytes": self.input.stat().st_size,
                "input_sha256": self.manifest["input_sets"][0]["input_sha256"],
                "iterations": 2, "settings": settings,
                "wires": {"vort_bytes": 7, "reference_bytes": 9,
                          "vort_sha256": hashlib.sha256(b"vort wire fixture").hexdigest(),
                          "reference_sha256": hashlib.sha256(b"reference wire fixture").hexdigest()},
                "rounds": [{"index": i, "vort_first": i % 2 == 0, "vort_ns": v,
                            "reference_ns": r, "vort_mix": 14, "reference_mix": 18}
                           for i, (v, r) in enumerate(times)],
                "summary": {"vort_min_ns": 10, "reference_min_ns": 11,
                            "vort_median_ns": 15 if codec == "zstd" else 20,
                            "reference_median_ns": 26 if codec == "zstd" else 31},
            }],
        }

    def test_valid_odd_and_even_rounds(self) -> None:
        for codec in ("brotli", "zstd"):
            with self.subTest(codec=codec):
                result = validate(self.report(codec), self.manifest, executable=self.executable,
                                  require_explicit_references=True)
                self.assertEqual(result["rounds"], 5 if codec == "brotli" else 4)

    def test_rejects_missing_or_misreported_rounds(self) -> None:
        mutations = [
            lambda r: r["rows"][0]["rounds"].pop(),
            lambda r: r["rows"][0]["rounds"][1].update(index=0),
            lambda r: r["rows"][0]["rounds"][1].update(vort_first=True),
            lambda r: r["rows"][0]["rounds"][1].update(vort_mix=15),
            lambda r: r["rows"][0]["rounds"][1].update(vort_ns=True),
            lambda r: r["rows"][0]["rounds"][1].update(reference_ns=0),
            lambda r: r["rows"][0]["summary"].update(vort_min_ns=20),
            lambda r: r["rows"][0]["summary"].update(reference_median_ns=51),
            lambda r: r["rows"].append(copy.deepcopy(r["rows"][0])),
        ]
        for mutation in mutations:
            with self.subTest(mutation=mutations.index(mutation)):
                report = self.report("brotli")
                mutation(report)
                with self.assertRaises(EvidenceError):
                    validate(report, self.manifest)

    def test_rejects_changed_input_reference_and_executable(self) -> None:
        report = self.report()
        for path in (self.input, self.reference, self.executable):
            with self.subTest(path=path.name):
                original = path.read_bytes()
                path.write_bytes(original + b"changed")
                with self.assertRaises(EvidenceError):
                    validate(report, self.manifest, executable=self.executable)
                path.write_bytes(original)

    def test_rejects_unverified_dependency_claim(self) -> None:
        report = self.report()
        report["references"][0]["dependencies_verified"] = True
        with self.assertRaises(EvidenceError):
            validate(report, self.manifest)

    def test_rejects_missing_effective_policy(self) -> None:
        for key in ("resolved_primary", "wire_header", "reference"):
            with self.subTest(key=key), self.assertRaises(EvidenceError):
                report = self.report()
                del report["rows"][0]["settings"][key]
                validate(report, self.manifest)
        report = self.report()
        report["rows"][0]["settings"]["wire_header"]["content_checksum"] = "false"
        with self.assertRaises(EvidenceError):
            validate(report, self.manifest)

    def test_csv_minimum_rates_and_checksum(self) -> None:
        report = self.report()
        row = report["rows"][0]
        csv_row = {"case": "frozen", "level": "3", "rounds": "4", "checksum": "32", "reference_version": "fixture-reference",
                   "input_bytes": str(row["input_bytes"]), "input_sha256": row["input_sha256"],
                   "iterations": "2", **{key: str(value) for key, value in report["provenance"].items()}}
        for implementation, ns, size in (("vort", 10, 7), ("reference", 11, 9)):
            csv_row.update({f"{implementation}_ns": str(ns), f"{implementation}_bytes": str(size),
                            f"{implementation}_mib_s": f"{row['input_bytes'] * 2 * 1e9 / (1048576 * ns):.6f}"})
        validate(report, self.manifest, csv_rows=[csv_row])
        for field, value in (("checksum", "33"), ("vort_ns", "20"), ("vort_mib_s", "1.000000"),
                             ("input_sha256", "0" * 64), ("command", "different command"),
                             ("reference_version", "other-reference")):
            with self.subTest(field=field), self.assertRaises(EvidenceError):
                validate(report, self.manifest, csv_rows=[dict(csv_row, **{field: value})])


if __name__ == "__main__":
    unittest.main()
