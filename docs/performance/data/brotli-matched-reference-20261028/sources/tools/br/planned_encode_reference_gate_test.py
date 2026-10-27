"""Reference metadata must describe actual windows; old CSV remains readable."""
import unittest

from planned_encode_bench_gate import (
    COLUMNS, LEGACY_COLUMNS, validate_columns, validate_reference_parameters,
)


class ReferenceParameters(unittest.TestCase):
    def row(self, **changes):
        value = dict(quality="8", planned_quality="8", planned_mode="generic",
                     reference_lgwin="16", reference_mode="0",
                     vort_wire_window_bits="16", reference_wire_window_bits="16",
                     parameters_match="true")
        value.update(changes)
        return value

    def test_old_and_current_columns(self):
        validate_columns(LEGACY_COLUMNS)
        validate_columns(COLUMNS)
        validate_reference_parameters(dict(quality="3", planned_quality="", planned_mode="generic"))
        with self.assertRaises(AssertionError):
            validate_columns(COLUMNS[:-1])

    def test_matches_actual_quality_mode_and_window(self):
        validate_reference_parameters(self.row())
        for changes in [dict(reference_wire_window_bits="18"), dict(quality="1"),
                        dict(reference_mode="1"), dict(planned_quality="")]:
            with self.assertRaises(AssertionError):
                validate_reference_parameters(self.row(**changes))
            validate_reference_parameters(self.row(**changes, parameters_match="false"))

    def test_low_quality_adjusted_window_is_not_matched(self):
        row = self.row(quality="0", planned_quality="0", reference_wire_window_bits="18", parameters_match="false")
        validate_reference_parameters(row)
        row["parameters_match"] = "true"
        with self.assertRaises(AssertionError):
            validate_reference_parameters(row)

    def test_invalid_or_incomplete_parameters(self):
        for changes in [dict(reference_lgwin="9"), dict(reference_lgwin="25"),
                        dict(reference_mode="3"), dict(vort_wire_window_bits="9"),
                        dict(reference_wire_window_bits="25"), dict(parameters_match="1")]:
            with self.assertRaises(AssertionError):
                validate_reference_parameters(self.row(**changes))
        partial = self.row()
        del partial["reference_mode"]
        with self.assertRaises(AssertionError):
            validate_reference_parameters(partial)


if __name__ == "__main__":
    unittest.main()
