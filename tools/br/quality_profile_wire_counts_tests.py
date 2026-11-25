"""Check physical emission counts independently of candidate selection history."""
import hashlib
import copy
import tempfile
import unittest
from pathlib import Path

from quality_profile_gate import validate


class WireCounts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "input"
        self.path.write_bytes(b"x" * 5000)

    def event(self, index, stage="wire", size=None, **changes):
        value = dict(id=index, parent_id=0, stage=stage, inclusive_ns=10, exclusive_ns=10,
                     wire_bytes=size, evaluated_wire_bytes=None, evaluation_event_id=None,
                     incumbent_bytes=None, candidate_event_id=None, incumbent_event_id=None,
                     accepted=None, gain_bytes=0, error_name="", origin="optimal",
                     config=dict(window_bits=16, large_window=False))
        value.update(changes)
        return value

    def report(self, extra=None):
        # Both earlier physical wires win at some point, then lose later.
        events = [self.event(0, "outer", parent_id=None, inclusive_ns=100, exclusive_ns=70),
                  self.event(1, size=10, origin="lazy"), self.event(2, size=9),
                  self.event(3, "selection", 9, inclusive_ns=0, exclusive_ns=0,
                             candidate_event_id=2, incumbent_event_id=1, incumbent_bytes=10,
                             accepted=True, gain_bytes=1), self.event(4, size=7),
                  self.event(5, "selection", 7, inclusive_ns=0, exclusive_ns=0,
                             candidate_event_id=4, incumbent_event_id=2, incumbent_bytes=9,
                             accepted=True, gain_bytes=2)]
        if extra is not None:
            events = [events[0]] + extra
        exclusive = {name: 0 for name in ("lazy_parse", "lazy_commands", "optimal_parse", "optimal_commands",
                                         "preferred_context", "split_planning", "wire", "evaluate",
                                         "distance_parameters", "selection", "other")}
        for event in events[1:]:
            exclusive.setdefault(event["stage"], 0)
            exclusive[event["stage"]] += event["exclusive_ns"]
        events[0]["exclusive_ns"] = 100 - sum(exclusive.values())
        profile = dict(error_name="", returned_wire_bytes=7, returned_wire_event_id=events[-1]["id"],
                       events=events, event_count=len(events), events_total=len(events), events_truncated=False,
                       timing_complete=True, wire_attempts=sum(e["stage"] == "wire" for e in events),
                       evaluation_attempts=sum(e["stage"] == "evaluate" for e in events),
                       wire_attempt_coverage_complete=True, outer_elapsed_ns=100,
                       exclusive_ns=exclusive, unaccounted_ns=100-sum(exclusive.values()))
        if extra is None:
            profile["returned_wire_event_id"] = 4
        return dict(schema="vort.brotli.q8-candidate-profile.v2", quality=8, mode="generic", window_bits=16,
                    rows=[dict(path=str(self.path), input_bytes=self.path.stat().st_size,
                               input_sha256=hashlib.sha256(self.path.read_bytes()).hexdigest(),
                               roundtrip_verified=True, wire_bytes=7, wire_sha256="a" * 64,
                               rounds=[dict(index=0, normal_first=True, wire_equal=True,
                                            normal_ns=90, profile_call_ns=110, profile=profile)])])

    def counts(self, report, wire_only=False):
        return validate(report, allow_truncated_context_details=wire_only)["rows"][0]["physical_wires"]

    def profile(self, report):
        return report["rows"][0]["rounds"][0]["profile"]

    def test_previous_winners_are_lost_materializations(self):
        report = self.report()
        result = self.counts(report)
        self.assertEqual(3, result["successful_wire_materializations"])
        self.assertEqual(2, result["lost_wire_materializations"])
        self.assertEqual(26, result["completed_wire_bytes_total"])
        self.assertEqual(dict(lazy=1, optimal=1), result["lost_wires_by_origin"])
        self.assertIsNone(validate(report)["rows"][0]["context_detail_coverage_complete"])

    def test_counted_candidates_are_not_physical_wires(self):
        events = [self.event(1, size=10),
                  self.event(2, "evaluate", evaluated_wire_bytes=7),
                  self.event(3, "selection", 7, inclusive_ns=0, exclusive_ns=0,
                             candidate_event_id=2, incumbent_event_id=1, incumbent_bytes=10,
                             accepted=True, gain_bytes=3),
                  self.event(4, size=7, evaluated_wire_bytes=7, evaluation_event_id=2)]
        result = self.counts(self.report(events))
        self.assertEqual(2, result["successful_wire_materializations"])
        self.assertEqual(1, result["lost_wire_materializations"])
        self.assertEqual(17, result["completed_wire_bytes_total"])

    def test_failed_attempt_does_not_count_as_completed_wire(self):
        result = self.counts(self.report([self.event(1, size=10),
                                         self.event(2, error_name="InvalidBlockPlan"), self.event(3, size=7)]))
        self.assertEqual(2, result["successful_wire_materializations"])
        self.assertEqual(1, result["failed_wire_attempts"])
        self.assertEqual(1, result["lost_wire_materializations"])

    def test_context_detail_truncation_keeps_complete_wire_count(self):
        report = self.context_report()
        with self.assertRaises(ValueError):
            self.counts(report)
        self.assertEqual(0, self.counts(report, wire_only=True)["lost_wire_materializations"])
        result = validate(report, allow_truncated_context_details=True)
        self.assertFalse(result["rows"][0]["context_detail_coverage_complete"])

    def context_report(self, count=9):
        contexts = [self.event(index, "context_proposals", variant=False, command_count=4,
                               inclusive_ns=1, exclusive_ns=1) for index in range(1, count + 1)]
        report = self.report(contexts + [self.event(count + 1, size=7)])
        details = [dict(event_id=event["id"], origin=event["origin"],
                        variant=False, command_count=4, profile={}) for event in contexts[:8]]
        self.profile(report).update(context_details=details, context_details_truncated=count > 8)
        return report

    def test_complete_context_details_keep_the_default_gate(self):
        report = self.context_report(8)
        result = validate(report)
        self.assertTrue(result["rows"][0]["context_detail_coverage_complete"])

    def test_wire_only_rejects_invalid_truncated_prefixes(self):
        mutations = [
            lambda p: p["context_details"].pop(),
            lambda p: p["context_details"].reverse(),
            lambda p: p["context_details"][0].update(event_id=9),
            lambda p: p["context_details"][0].update(event_id=2),
            lambda p: p["context_details"][0].update(event_id=True),
            lambda p: p["context_details"][0].update(command_count=5),
            lambda p: p.update(context_details_truncated=False),
        ]
        original = self.context_report()
        for index, mutation in enumerate(mutations):
            report = copy.deepcopy(original)
            mutation(self.profile(report))
            with self.subTest(mutation=index), self.assertRaises(ValueError):
                self.counts(report, wire_only=True)
        report = self.context_report(8)
        self.profile(report)["context_details_truncated"] = True
        with self.assertRaises(ValueError):
            self.counts(report, wire_only=True)
        report = self.report()
        self.profile(report).update(context_details=[], context_details_truncated=True)
        with self.assertRaises(ValueError):
            self.counts(report, wire_only=True)

    def test_incomplete_wire_coverage_has_no_exact_count(self):
        report = self.report()
        self.path.write_bytes(b"small dictionary auxiliary")
        report["rows"][0].update(input_bytes=self.path.stat().st_size,
                                 input_sha256=hashlib.sha256(self.path.read_bytes()).hexdigest())
        self.profile(report)["wire_attempt_coverage_complete"] = False
        result = self.counts(report)
        self.assertFalse(result["exact_lost_wire_count_available"])
        self.assertIsNone(result["lost_wire_materializations"])

    def test_unclassified_attempt_does_not_invent_a_count(self):
        result = self.counts(self.report([self.event(1, size=10), self.event(2), self.event(3, size=7)]))
        self.assertEqual(1, result["unclassified_wire_attempts"])
        self.assertFalse(result["exact_lost_wire_count_available"])
        self.assertIsNone(result["lost_wire_materializations"])

    def test_truncated_events_and_nonboolean_coverage_are_rejected(self):
        for changes in [dict(events_truncated=True), dict(wire_attempt_coverage_complete=1)]:
            report = self.report()
            self.profile(report).update(changes)
            with self.assertRaises(ValueError):
                self.counts(report)
            with self.assertRaises(ValueError):
                self.counts(report, wire_only=True)

    def test_invalid_wire_error_name_is_rejected(self):
        report = self.report([self.event(1, size=10), self.event(2, error_name=None), self.event(3, size=7)])
        with self.assertRaises(ValueError):
            self.counts(report)

    def test_wire_only_mode_does_not_accept_untyped_context_flags(self):
        report = self.report()
        self.profile(report).update(context_details=[], context_details_truncated=0)
        with self.assertRaises(ValueError):
            self.counts(report, wire_only=True)


if __name__ == "__main__":
    unittest.main()
