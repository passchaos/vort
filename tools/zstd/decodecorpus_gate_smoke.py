#!/usr/bin/env python3
"""Fast self-contained tests for the Zstd decodecorpus gate driver."""

from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True


SCRIPT = Path(__file__).with_name("decodecorpus_gate.py")
SPEC = importlib.util.spec_from_file_location("decodecorpus_gate", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
gate = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = gate
SPEC.loader.exec_module(gate)


GENERATOR = """#!/usr/bin/env python3
import pathlib
import sys

count = int(next(arg[2:] for arg in sys.argv[1:] if arg.startswith('-n')))
root = pathlib.Path(next(arg[2:] for arg in sys.argv[1:] if arg.startswith('-p')))
if '--block-type=2' in sys.argv:
    required = {'--max-block-size-log=4', '--max-content-size-log=13'}
    if not required.issubset(sys.argv):
        raise SystemExit(f'missing compressed stress arguments: {sys.argv!r}')
root.mkdir(parents=True, exist_ok=True)
for index in range(count):
    stem = f'z{index:06d}'
    (root / stem).write_bytes(b'plain')
    (root / f'{stem}.zst').write_bytes(b'frame')
if any(arg.startswith('--use-dict=') for arg in sys.argv[1:]):
    (root / 'dictionary').write_bytes(b'dictionary')
"""

PROBE = """#!/usr/bin/env python3
import sys

count = int(sys.argv[sys.argv.index('--decodecorpus-count') + 1])
prior = int(sys.argv[sys.argv.index('--prior-mode-mask') + 1], 0)
mode = (1 << 64) - 1 if count == 500 else (0xa if '--decodecorpus-dictionary' in sys.argv else 0x5)
combined = prior | mode
print(
    f'zstd_compat_probe checked={count} unsupported=0 decodecorpus_cases={count} '
    f'decodecorpus_incremental_cases={count} decodecorpus_block_stream_cases={count // 2} '
    f'decodecorpus_max_compressed_buffered=131104 '
    f'decodecorpus_max_compressed_capacity=131104 '
    f'decodecorpus_streamed_literal_blocks=3 '
    f'decodecorpus_streamed_sequence_blocks=7 '
    f'decodecorpus_max_block_stream_decoded_buffered=0 '
    f'decodecorpus_max_block_stream_decoded_capacity=0 '
    f'decodecorpus_max_sequence_count=5 '
    f'decodecorpus_max_block_count=3 '
    f'decodecorpus_sequence_count_tiers=0x1 '
    f'decodecorpus_sequence_mode_combinations={mode.bit_count()} '
    f'decodecorpus_sequence_mode_mask={mode:#x} '
    f'decodecorpus_combined_mode_combinations={combined.bit_count()} '
    f'decodecorpus_combined_mode_mask={combined:#x} '
    f'sequence_mode_mask=0xffffffffffffffff combined_mode_mask=0xffffffffffffffff',
    file=sys.stderr,
)
"""

BAD_PROBE = """#!/usr/bin/env python3
print('missing structured summary')
"""


def write_executable(path: Path, source: str) -> None:
    path.write_text(source, encoding="utf-8")
    path.chmod(0o755)


class DecodeCorpusGateTests(unittest.TestCase):
    def test_parse_summary_rejects_unstructured_output(self) -> None:
        with self.assertRaisesRegex(ValueError, "did not emit"):
            gate.parse_summary("noise only")

    def test_explicit_missing_generator_is_rejected(self) -> None:
        with self.assertRaisesRegex(FileNotFoundError, "is not executable"):
            gate.resolve_decodecorpus("/definitely/missing/vort-decodecorpus")

    def test_duplicate_campaign_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "duplicate campaign"):
            gate.select_campaigns(["plain-17", "plain-17"])

    def test_stress_campaigns_pin_generator_arguments(self) -> None:
        rle = gate.CAMPAIGNS_BY_NAME["rle-content-32452843"]
        self.assertEqual(
            rle.generator_args,
            ("--content-size", "--block-type=1", "--max-content-size-log=20"),
        )
        self.assertFalse(rle.require_block_stream)
        self.assertEqual(rle.expected_mode_mask, 0)
        self.assertEqual(rle.min_max_block_count, 2)

        raw = gate.CAMPAIGNS_BY_NAME["raw-8b-49979693"]
        self.assertEqual(
            raw.generator_args,
            ("--block-type=0", "--max-block-size-log=3", "--max-content-size-log=14"),
        )
        self.assertFalse(raw.require_block_stream)
        self.assertEqual(raw.expected_mode_mask, 0)
        self.assertEqual(raw.min_max_block_count, 2)

        compressed = gate.CAMPAIGNS_BY_NAME["compressed-16b-67867979"]
        self.assertEqual(
            compressed.generator_args,
            ("--block-type=2", "--max-block-size-log=4", "--max-content-size-log=13"),
        )
        self.assertFalse(compressed.require_block_stream)
        self.assertEqual(compressed.expected_mode_mask, gate.COMPLETE_MODE_MASK)
        self.assertEqual(compressed.min_max_block_count, 2)

    def test_full_suite_requires_complete_mode_coverage(self) -> None:
        gate.validate_final_coverage((gate.CAMPAIGNS[0],), 0)
        gate.validate_final_coverage(gate.CAMPAIGNS, gate.COMPLETE_MODE_MASK)
        with self.assertRaisesRegex(RuntimeError, "63/64"):
            gate.validate_final_coverage(gate.CAMPAIGNS, gate.COMPLETE_MODE_MASK ^ 1)

    def test_gate_rejects_missing_block_stream_coverage(self) -> None:
        fields = {
            "decodecorpus_cases": "200",
            "decodecorpus_incremental_cases": "200",
            "decodecorpus_block_stream_cases": "0",
            "decodecorpus_max_compressed_buffered": "64",
            "decodecorpus_max_compressed_capacity": "64",
            "decodecorpus_streamed_literal_blocks": "1",
            "decodecorpus_streamed_sequence_blocks": "1",
            "decodecorpus_max_block_stream_decoded_buffered": "0",
            "decodecorpus_max_block_stream_decoded_capacity": "0",
            "decodecorpus_max_sequence_count": "1",
            "decodecorpus_max_block_count": "2",
            "decodecorpus_sequence_count_tiers": "0x1",
            "decodecorpus_sequence_mode_combinations": "2",
            "decodecorpus_sequence_mode_mask": "0x5",
            "decodecorpus_combined_mode_combinations": "2",
            "decodecorpus_combined_mode_mask": "0x5",
            "unsupported": "0",
            "sequence_mode_mask": "0x5",
            "combined_mode_mask": "0x5",
        }
        with self.assertRaisesRegex(RuntimeError, "did not exercise bounded block streaming"):
            gate.validate_campaign_summary(fields, gate.CAMPAIGNS[0], 0)

    def test_gate_rejects_decoded_scratch_during_block_streaming(self) -> None:
        fields = {
            "decodecorpus_cases": "200",
            "decodecorpus_incremental_cases": "200",
            "decodecorpus_block_stream_cases": "1",
            "decodecorpus_max_compressed_buffered": "64",
            "decodecorpus_max_compressed_capacity": "64",
            "decodecorpus_streamed_literal_blocks": "1",
            "decodecorpus_streamed_sequence_blocks": "1",
            "decodecorpus_max_block_stream_decoded_buffered": "1",
            "decodecorpus_max_block_stream_decoded_capacity": "8",
            "decodecorpus_max_sequence_count": "1",
            "decodecorpus_max_block_count": "2",
            "decodecorpus_sequence_count_tiers": "0x1",
            "decodecorpus_sequence_mode_combinations": "2",
            "decodecorpus_sequence_mode_mask": "0x5",
            "decodecorpus_combined_mode_combinations": "2",
            "decodecorpus_combined_mode_mask": "0x5",
            "unsupported": "0",
            "sequence_mode_mask": "0x5",
            "combined_mode_mask": "0x5",
        }
        with self.assertRaisesRegex(RuntimeError, "retained decoded block scratch"):
            gate.validate_campaign_summary(fields, gate.CAMPAIGNS[0], 0)

    def test_small_block_campaign_allows_no_block_stream_switch(self) -> None:
        fields = {
            "decodecorpus_cases": "500",
            "decodecorpus_incremental_cases": "500",
            "decodecorpus_block_stream_cases": "0",
            "decodecorpus_max_compressed_buffered": "32",
            "decodecorpus_max_compressed_capacity": "64",
            "decodecorpus_streamed_literal_blocks": "0",
            "decodecorpus_streamed_sequence_blocks": "0",
            "decodecorpus_max_block_stream_decoded_buffered": "0",
            "decodecorpus_max_block_stream_decoded_capacity": "0",
            "decodecorpus_max_sequence_count": "5",
            "decodecorpus_max_block_count": "3",
            "decodecorpus_sequence_count_tiers": "0x1",
            "decodecorpus_sequence_mode_combinations": "64",
            "decodecorpus_sequence_mode_mask": hex(gate.COMPLETE_MODE_MASK),
            "decodecorpus_combined_mode_combinations": "64",
            "decodecorpus_combined_mode_mask": hex(gate.COMPLETE_MODE_MASK),
            "unsupported": "0",
            "sequence_mode_mask": hex(gate.COMPLETE_MODE_MASK),
            "combined_mode_mask": hex(gate.COMPLETE_MODE_MASK),
        }
        combined, block_stream_cases, *_ = gate.validate_campaign_summary(
            fields,
            gate.CAMPAIGNS_BY_NAME["compressed-16b-67867979"],
            0,
        )
        self.assertEqual(combined, gate.COMPLETE_MODE_MASK)
        self.assertEqual(block_stream_cases, 0)

    def test_driver_runs_and_cleans_success_and_failure_corpora(self) -> None:
        with tempfile.TemporaryDirectory(prefix="vort-zstd-gate-smoke-") as temp:
            root = Path(temp)
            generator = root / "decodecorpus"
            probe = root / "probe"
            bad_probe = root / "bad-probe"
            scratch = root / "scratch"
            scratch.mkdir()
            write_executable(generator, GENERATOR)
            write_executable(probe, PROBE)
            write_executable(bad_probe, BAD_PROBE)
            environment = os.environ.copy()
            environment["TMPDIR"] = str(scratch)

            command = [
                sys.executable,
                str(SCRIPT),
                str(probe),
                "--decodecorpus",
                str(generator),
                "--campaign",
                "plain-17",
                "--campaign",
                "dict-2027-64k",
            ]
            success = subprocess.run(command, text=True, capture_output=True, env=environment, check=False)
            self.assertEqual(success.returncode, 0, success.stdout + success.stderr)
            self.assertIn("zstd_decodecorpus_gate=ok campaigns=2 cases=400", success.stdout)
            self.assertIn("block_stream_cases=200", success.stdout)
            self.assertIn("max_compressed_buffered=131104", success.stdout)
            self.assertIn("streamed_sequence_blocks=14", success.stdout)
            self.assertIn("max_block_stream_decoded_buffered=0", success.stdout)
            self.assertIn("max_block_stream_decoded_capacity=0", success.stdout)
            self.assertIn("sequence_mode_mask=0x000000000000000f", success.stdout)
            self.assertEqual(list(scratch.iterdir()), [])

            stress_command = [
                sys.executable,
                str(SCRIPT),
                str(probe),
                "--decodecorpus",
                str(generator),
                "--campaign",
                "compressed-16b-67867979",
            ]
            stress = subprocess.run(stress_command, text=True, capture_output=True, env=environment, check=False)
            self.assertEqual(stress.returncode, 0, stress.stdout + stress.stderr)
            self.assertIn("zstd_decodecorpus_gate=ok campaigns=1 cases=500", stress.stdout)
            self.assertEqual(list(scratch.iterdir()), [])

            command[2] = str(bad_probe)
            failure = subprocess.run(command, text=True, capture_output=True, env=environment, check=False)
            self.assertNotEqual(failure.returncode, 0)
            self.assertIn("did not emit a zstd_compat_probe summary", failure.stderr)
            self.assertEqual(list(scratch.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
