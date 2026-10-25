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

    def context_report(self):
        report = copy.deepcopy(self.report)
        p = self.profile(report)
        p["exclusive_ns"]["context_proposals"] = 20
        p["unaccounted_ns"] = 40
        p["events"][0]["exclusive_ns"] = 40
        p["events"].append(dict(p["events"][1], id=2, stage="context_proposals", inclusive_ns=20,
                                exclusive_ns=20, origin="lazy", variant=False, command_count=1, error_name=""))
        p["event_count"] = p["events_total"] = 3
        zero = dict(requests=0, hits=0, misses=0, cold_misses=0, conflict_misses=0, cross_scope_hits=0, cross_mode_hits=0)
        baseline = dict(zero, requests=1, misses=1, cold_misses=1)
        p["context_details_truncated"] = False
        p["context_details"] = [dict(event_id=2, origin="lazy", variant=False, command_count=1,
                                      profile=dict(tree_score_scope_counts=[baseline, zero, zero],
                                                   tree_score_mode_counts=[[zero, zero, zero] for _ in range(4)],
                                                   tree_score_cache_hits=0, tree_score_cache_misses=1,
                                                   tree_score_calls=1))]
        return report

    def test_context_detail(self):
        self.assertEqual(1, validate(self.context_report())["validated_runs"])

    def test_wrong_context_attribution(self):
        report = self.context_report()
        self.profile(report)["context_details"][0]["event_id"] = 1
        with self.assertRaises(ValueError):
            validate(report)

    def test_wrong_score_conservation(self):
        report = self.context_report()
        self.profile(report)["context_details"][0]["profile"]["tree_score_calls"] = 0
        with self.assertRaises(ValueError):
            validate(report)

    def test_duplicate_context_detail(self):
        report = self.context_report()
        p = self.profile(report)
        p["events"].append(dict(p["events"][-1], id=3, inclusive_ns=0, exclusive_ns=0))
        p["event_count"] = p["events_total"] = 4
        p["context_details"].append(copy.deepcopy(p["context_details"][0]))
        with self.assertRaises(ValueError):
            validate(report)

    def test_wrong_mode_score_conservation(self):
        report = self.context_report()
        p = self.profile(report)["context_details"][0]["profile"]
        p["tree_score_mode_counts"] = copy.deepcopy(p["tree_score_mode_counts"])
        p["tree_score_mode_counts"][0][1]["hits"] = 1
        with self.assertRaises(ValueError):
            validate(report)

    def restored_context_report(self):
        report = self.context_report()
        stats = self.profile(report)["context_details"][0]["profile"]
        stats["tree_score_scope_counts"][0] = dict(stats["tree_score_scope_counts"][1])
        stats.update(tree_score_cache_misses=0, tree_score_uncached_calls=3,
                     tree_score_uncached_scope_calls=[1, 2, 0],
                     tree_score_uncached_mode_calls=[[0, 2, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]],
                     tree_score_calls=3, literal_count=128, suffix_payload_scores=1)
        return report

    def test_restored_uncached_counts(self):
        self.assertEqual(1, validate(self.restored_context_report())["validated_runs"])

    def test_wrong_uncached_counts(self):
        report = self.restored_context_report()
        self.profile(report)["context_details"][0]["profile"]["tree_score_uncached_calls"] = 2
        with self.assertRaises(ValueError):
            validate(report)

    def test_wrong_uncached_mode(self):
        report = self.restored_context_report()
        self.profile(report)["context_details"][0]["profile"]["tree_score_uncached_mode_calls"][0][1] = 1
        with self.assertRaises(ValueError):
            validate(report)


if __name__ == "__main__":
    unittest.main()
