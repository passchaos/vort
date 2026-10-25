#!/usr/bin/env python3
"""Exercise independent q8 report gates with malformed evidence."""
import copy
import hashlib
import tempfile
import unittest
from pathlib import Path
from quality_profile_gate import validate


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "input.bin"
        self.path.write_bytes(b"valid profile fixture")
        stages = {name: 0 for name in ("lazy_parse", "lazy_commands", "optimal_parse", "optimal_commands", "preferred_context", "split_planning", "wire", "distance_parameters", "selection", "other")}
        stages["wire"] = 40
        base = {"parent_id": None, "inclusive_ns": 0, "exclusive_ns": 0, "accepted": None,
                "incumbent_bytes": None, "wire_bytes": None, "gain_bytes": 0,
                "candidate_event_id": None, "incumbent_event_id": None,
                "config": {"window_bits": 16, "large_window": False}}
        outer = dict(base, id=0, stage="outer", inclusive_ns=100, exclusive_ns=60)
        wire = dict(base, id=1, parent_id=0, stage="wire", inclusive_ns=40, exclusive_ns=40, wire_bytes=7)
        profile = {"error_name": "", "returned_wire_bytes": 7, "returned_wire_event_id": 1,
                   "events": [outer, wire], "event_count": 2, "events_total": 2,
                   "events_truncated": False, "timing_complete": True,
                   "wire_attempts": 1, "wire_attempt_coverage_complete": True,
                   "outer_elapsed_ns": 100, "exclusive_ns": stages, "unaccounted_ns": 60}
        self.report = {"schema": "vort.brotli.q8-candidate-profile.v1", "quality": 8,
                       "mode": "generic", "window_bits": 16, "rows": [{
                           "path": str(self.path), "input_bytes": self.path.stat().st_size,
                           "input_sha256": hashlib.sha256(self.path.read_bytes()).hexdigest(),
                           "roundtrip_verified": True, "wire_bytes": 7, "wire_sha256": "a" * 64,
                           "rounds": [{"index": 0, "normal_first": True, "wire_equal": True,
                                       "normal_ns": 90, "profile_call_ns": 120, "profile": profile}]}]}

    def profile(self, report):
        return report["rows"][0]["rounds"][0]["profile"]

    def rejected(self, mutation):
        report = copy.deepcopy(self.report)
        mutation(report)
        with self.assertRaises(ValueError):
            validate(report)

    def test_valid(self):
        self.assertEqual(1, validate(self.report)["validated_runs"])

    def test_bad_parent_accounting(self):
        self.rejected(lambda r: self.profile(r)["events"][0].update(exclusive_ns=100))

    def test_bad_stage_totals(self):
        self.rejected(lambda r: self.profile(r)["exclusive_ns"].update(wire=30))

    def test_truncated_or_incomplete(self):
        self.rejected(lambda r: self.profile(r).update(events_truncated=True))
        self.rejected(lambda r: self.profile(r).update(timing_complete=False))

    def test_wrong_winner(self):
        self.rejected(lambda r: self.profile(r).update(returned_wire_event_id=0))

    def test_changed_input(self):
        self.path.write_bytes(b"changed profile fixture")
        with self.assertRaises(ValueError):
            validate(self.report)


if __name__ == "__main__":
    unittest.main()
