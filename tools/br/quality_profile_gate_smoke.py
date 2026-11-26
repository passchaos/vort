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

    def evaluation_report(self):
        report = copy.deepcopy(self.report)
        report["schema"] = "vort.brotli.q8-candidate-profile.v2"
        profile = self.profile(report)
        profile["exclusive_ns"].update(wire=60, evaluate=20)
        profile.update(evaluation_attempts=1, wire_attempts=2, event_count=5,
                       events_total=5, returned_wire_event_id=4, unaccounted_ns=20)
        for event in profile["events"]:
            event.update(evaluated_wire_bytes=None, evaluation_event_id=None, error_name="")
        profile["events"][0]["exclusive_ns"] = 20
        profile["events"][1]["wire_bytes"] = 9
        base = profile["events"][1]
        evaluation = dict(base, id=2, stage="evaluate", wire_bytes=None,
                          evaluated_wire_bytes=7, inclusive_ns=20, exclusive_ns=20)
        selection = dict(base, id=3, stage="selection", inclusive_ns=0, exclusive_ns=0,
                         wire_bytes=7, incumbent_bytes=9, accepted=True, gain_bytes=2,
                         candidate_event_id=2, incumbent_event_id=1)
        emission = dict(base, id=4, wire_bytes=7, evaluated_wire_bytes=7,
                        evaluation_event_id=2, inclusive_ns=20, exclusive_ns=20)
        profile["events"].extend([evaluation, selection, emission])
        return report

    def test_evaluation_selection_and_real_emission(self):
        result = validate(self.evaluation_report())
        self.assertEqual(1, result["rows"][0]["evaluation_attempts"])
        self.assertEqual(2, result["rows"][0]["wire_attempts"])
        # A v2 full-wire-only report remains valid with zero evaluations.
        report = copy.deepcopy(self.report)
        report["schema"] = "vort.brotli.q8-candidate-profile.v2"
        profile = self.profile(report)
        profile["evaluation_attempts"] = 0
        profile["exclusive_ns"]["evaluate"] = 0
        for event in profile["events"]:
            event.update(evaluated_wire_bytes=None, evaluation_event_id=None)
        validate(report)

    def test_evaluation_rejects_masquerading_or_bad_accounting(self):
        changes = [
            lambda p: p["events"][2].update(wire_bytes=7),
            lambda p: p["events"][2].update(evaluation_event_id=1),
            lambda p: p["events"][2].update(evaluated_wire_bytes=None),
            lambda p: p.update(evaluation_attempts=2),
            lambda p: p.update(evaluation_attempts=True),
            lambda p: p["exclusive_ns"].pop("evaluate"),
        ]
        for mutation in changes:
            report = self.evaluation_report()
            mutation(self.profile(report))
            with self.subTest(mutation=changes.index(mutation)), self.assertRaises(ValueError):
                validate(report)

    def test_evaluation_rejects_wrong_selection_or_emission_link(self):
        changes = [
            lambda p: p["events"][3].update(candidate_event_id=0),
            lambda p: p["events"][3].update(candidate_event_id=4),
            lambda p: p["events"][3].update(candidate_event_id=True),
            lambda p: p["events"][3].update(wire_bytes=8, gain_bytes=1),
            lambda p: p["events"][4].update(evaluation_event_id=1),
            lambda p: p["events"][4].update(evaluated_wire_bytes=8),
            lambda p: p.update(returned_wire_event_id=2),
            lambda p: p["events"][2].update(error_name="InvalidBlockPlan"),
        ]
        for mutation in changes:
            report = self.evaluation_report()
            mutation(self.profile(report))
            with self.subTest(mutation=changes.index(mutation)), self.assertRaises(ValueError):
                validate(report)

    def test_evaluation_ties_keep_incumbent(self):
        report = self.evaluation_report()
        selection = self.profile(report)["events"][3]
        selection.update(incumbent_bytes=7, incumbent_event_id=2, accepted=False, gain_bytes=0)
        validate(report)
        selection["accepted"] = True
        with self.assertRaises(ValueError):
            validate(report)

    def test_returned_winner_id_rejects_boolean(self):
        self.rejected(lambda r: self.profile(r).update(returned_wire_event_id=True))

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
        report = self.restored_context_report()
        self.assertNotIn("proposal_reuses", self.profile(report)["context_details"][0]["profile"])
        self.assertEqual(1, validate(report)["validated_runs"])

    def reused_context_report(self):
        report = self.restored_context_report()
        # Match a present analysis above the literal-count threshold.
        self.path.write_bytes(b"a" * 256)
        row = report["rows"][0]
        row.update(input_bytes=256, input_sha256=hashlib.sha256(self.path.read_bytes()).hexdigest())
        stats = self.profile(report)["context_details"][0]["profile"]

        def zero(value):
            if isinstance(value, dict):
                return {key: zero(nested) for key, nested in value.items()}
            if isinstance(value, list):
                return [zero(nested) for nested in value]
            return 0

        stats.update({key: zero(value) for key, value in stats.items()})
        stats.update(input_bytes=256, literal_count=128, active_symbols=1,
                     proposal_reuses=1, analysis_ns=10, proposal_lookup_ns=5,
                     total_ns=15, suffix_tree_count=2, suffix_mode=1,
                     suffix_savings_bits=64)
        return report

    def test_complete_proposal_hit_retains_shape_without_scoring(self):
        self.assertEqual(1, validate(self.reused_context_report())["validated_runs"])

    def test_proposal_hit_rejects_work_in_scalars_and_nested_counters(self):
        for field in ("tree_score_calls", "cluster_rounds", "suffix_payload_reuses", "baseline_ns",
                      "tree_score_scope_counts", "tree_score_mode_counts"):
            report = self.reused_context_report()
            stats = self.profile(report)["context_details"][0]["profile"]
            if field == "tree_score_scope_counts":
                stats[field][2]["requests"] = 1
            elif field == "tree_score_mode_counts":
                stats[field][0][2]["requests"] = 1
            else:
                stats[field] = 1
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "proposal reuse performed work"):
                validate(report)

    def test_proposal_miss_still_requires_baseline_scoring(self):
        report = self.restored_context_report()
        stats = self.profile(report)["context_details"][0]["profile"]
        stats.update(proposal_reuses=0, tree_score_uncached_calls=2, tree_score_calls=2)
        stats["tree_score_uncached_scope_calls"][0] = 0
        with self.assertRaisesRegex(ValueError, "uncached baseline calls"):
            validate(report)

    def test_proposal_reuse_count_is_one_integer_call(self):
        for value in (2, -1, True, "1"):
            report = self.reused_context_report()
            self.profile(report)["context_details"][0]["profile"]["proposal_reuses"] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate(report)

    def test_proposal_hit_requires_explicit_work_counters(self):
        for field in ("tree_score_calls", "tree_score_scope_counts", "tree_score_uncached_calls"):
            report = self.reused_context_report()
            del self.profile(report)["context_details"][0]["profile"][field]
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "proposal reuse missing work counters"):
                validate(report)

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
