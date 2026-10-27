"""General evidence acceptance and the optional auxiliary size requirement."""
import unittest

from planned_encode_bench_gate import COLUMNS, LEGACY_COLUMNS, validate_columns
from planned_encode_path_gate import validate_rows


class PathGateTests(unittest.TestCase):
    def row(self, *, current=True):
        row = dict(case="file0_dickens", input_bytes="65536", quality="8",
                   planned_quality="8", planned_mode="generic", vort_bytes="24723",
                   lazy_bytes="26337", ratio_bytes="25194", reference_bytes="25165",
                   iterations="1", vort_ns="100", lazy_ns="100", ratio_ns="100",
                   reference_ns="100", checksum="100")
        if current:
            row.update(reference_lgwin="16", reference_mode="0", vort_wire_window_bits="16",
                       reference_wire_window_bits="16", parameters_match="true")
        return row

    def test_valid_larger_auxiliary_ratio_passes_general_gate(self):
        for current in (False, True):
            with self.subTest(current=current):
                validate_columns(COLUMNS if current else LEGACY_COLUMNS)
                validate_rows([self.row(current=current)])

    def test_explicit_size_requirement_rejects_larger_auxiliary_ratio(self):
        for current in (False, True):
            with self.subTest(current=current), self.assertRaises(AssertionError):
                validate_rows([self.row(current=current)], require_ratio_no_worse_than_reference=True)

    def test_explicit_size_requirement_accepts_equal_and_smaller(self):
        for size in ("25165", "25164"):
            row = self.row()
            row["ratio_bytes"] = size
            validate_rows([row], require_ratio_no_worse_than_reference=True)

    def test_general_gate_preserves_internal_ratio_and_evidence_checks(self):
        for changes in (dict(ratio_bytes="26338"), dict(reference_bytes="0"),
                        dict(case="json"), dict(parameters_match="false")):
            row = self.row()
            row.update(changes)
            with self.subTest(changes=changes), self.assertRaises(AssertionError):
                validate_rows([row])
        with self.assertRaises(AssertionError):
            validate_rows([])

    def test_primary_size_does_not_control_auxiliary_performance_requirement(self):
        row = self.row()
        row.update(vort_bytes="30000", ratio_bytes="25164")
        validate_rows([row])
        validate_rows([row], require_ratio_no_worse_than_reference=True)


if __name__ == "__main__":
    unittest.main()
