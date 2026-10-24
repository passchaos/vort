#!/usr/bin/env python3
"""Positive and negative contracts for the Snappy reference benchmark gate."""

from __future__ import annotations

import unittest

import reference_bench_gate as gate


def rows(ratios: dict[str, float]) -> dict[str, dict[str, str]]:
    return {
        name: {"case": name, "vort_over_reference": str(ratio)}
        for name, ratio in ratios.items()
    }


class GateSmoke(unittest.TestCase):
    def test_accepts_no_loss_and_strong_aggregate_lead(self) -> None:
        by_case = rows({
            "tiny": 3.0,
            "text": 1.08,
            "structured": 1.09,
            "repetitive": 1.02,
            "incompressible": 1.8,
            "rle64k": 1.35,
        })
        copy_geomean, matrix_geomean, weakest = gate.validate_performance(by_case)
        self.assertGreaterEqual(copy_geomean, gate.MINIMUM_COPY_HEAVY_GEOMEAN)
        self.assertGreaterEqual(matrix_geomean, gate.MINIMUM_MATRIX_GEOMEAN)
        self.assertEqual("repetitive", weakest)

    def test_rejects_any_losing_case(self) -> None:
        by_case = rows({name: 1.5 for name in gate.EXPECTED_CASES})
        by_case["structured"]["vort_over_reference"] = "0.999"
        with self.assertRaisesRegex(AssertionError, "no longer leads structured"):
            gate.validate_performance(by_case)

    def test_rejects_weak_copy_aggregate(self) -> None:
        by_case = rows({name: 2.0 for name in gate.EXPECTED_CASES})
        for name in gate.COPY_HEAVY_CASES:
            by_case[name]["vort_over_reference"] = "1.01"
        with self.assertRaisesRegex(AssertionError, "copy-heavy geomean"):
            gate.validate_performance(by_case)

    def test_rejects_weak_complete_matrix(self) -> None:
        by_case = rows({name: 1.11 for name in gate.EXPECTED_CASES})
        with self.assertRaisesRegex(AssertionError, "matrix geomean"):
            gate.validate_performance(by_case)


if __name__ == "__main__":
    unittest.main()
