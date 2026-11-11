"""Negative evidence cases must fail before a matrix can be summarized."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from evidence import bootstrap_log_mean, validate_manifest, validate_report
from fixtures import LEVELS, SILESIA, sha256


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        plain, wire, library = root / "plain", root / "wire", root / "libzstd.so.1.6.0"
        plain.write_bytes(b"data")
        wire.write_bytes(b"wire")
        library.write_bytes(b"pinned reference")
        self.library = library
        self.fixture = {"codec": "zstd", "input_path": str(plain), "encoded_input_path": str(wire), "input_bytes": 4, "input_first_byte": 100, "encoded_bytes": 4, "input_sha256": sha256(plain), "encoded_sha256": sha256(wire)}
        self.task = {"fixture": self.fixture, "lifecycle": "cold", "iterations": 10}
        self.manifest = {"config": {"rounds": 4, "warmup": 2, "cpu": 15, "target_cpu": "skylake"}, "probe_sha256": "a" * 64, "environment": {"zig_version": "0.16.0", "cpu_model": "Test CPU"}, "references": {"zstd": {"path": str(library), "version": "1.6.0", "file_sha256": {str(library): sha256(library)}}}}
        pairs = [{"pair_id": i, "first": "vort" if i % 2 == 0 else "reference", "vort_ns": value, "reference_ns": value // 2, "vort_mix": 1040, "reference_mix": 1040} for i, value in enumerate((80, 80, 2, 200, 400, 600))]
        self.report = {"schema": "vort.decode-compare.v1", "codec": "zstd", "lifecycle": "cold", "lifecycle_match": "matched-cold", "vort_api": "decodeFrameInto", "reference_api": "ZSTD_decompress", "iterations": 10, "rounds": 4, "warmup": 2, "input_path": str(plain), "encoded_input_path": str(wire), **{key: self.fixture[key] for key in ("input_bytes", "encoded_bytes", "input_sha256", "encoded_sha256")}, "reference_version": "1.6.0", "reference_version_origin": "queried-ZSTD_versionString", "reference_paths": [str(library)], "loaded_shared_library_paths": [str(library)], "alignment": {"guard_bytes": 64, "input_mod64": 0, "encoded_mod64": 0, "vort_output_mod64": 0, "reference_output_mod64": 0}, "validation": {"every_iteration_count": True, "full_output_per_batch": True, "guards_per_batch": True, "input_unchanged_per_batch": True, "exact_consumption_per_batch": False}, "warmup_pairs": pairs[:2], "pairs": pairs[2:], "summary": {"vort_median_ns": 300.0, "reference_median_ns": 150.0}, "provenance": {"optimize": "ReleaseFast", "benchmark_threads": 1, "affinity_cpu_count": 1, "cpu_affinity": "15", "executable_sha256": "a" * 64, "zig_version": "0.16.0", "target_arch": "x86_64", "target_os": "linux", "target_abi": "gnu", "target_cpu": "skylake", "cpu_model": "Test CPU", "codec_thread_policy": "single"}}

    def test_complete_samples_and_fixed_ratio(self):
        validate_report(self.report, self.task, self.manifest)
        stats = bootstrap_log_mean([self.report], 42, 200)
        self.assertAlmostEqual(stats["time_ratio_geomean"], 2.0)
        self.assertEqual(stats["ci95"], [2.0, 2.0])

    def test_selecting_fastest_instead_of_median_fails(self):
        report = copy.deepcopy(self.report)
        report["summary"]["vort_median_ns"] = 2
        with self.assertRaisesRegex(ValueError, "Median"):
            validate_report(report, self.task, self.manifest)

    def test_drop_reorder_unbalanced_or_wrong_checksum(self):
        mutations = (
            lambda r: r["pairs"].pop(),
            lambda r: r["pairs"].reverse(),
            lambda r: r["pairs"][0].update(first="reference"),
            lambda r: r["pairs"][0].update(vort_mix=39),
            lambda r: r["pairs"][0].update(vort_ns=0),
            lambda r: r["pairs"][0].update(vort_mix=0, reference_mix=0),
            lambda r: r["pairs"][0].update(vort_mix=-1, reference_mix=-1),
            lambda r: r["pairs"][0].update(vort_ns=1 << 65),
            lambda r: r["warmup_pairs"].pop(),
        )
        for mutate in mutations:
            report = copy.deepcopy(self.report)
            mutate(report)
            with self.assertRaises(ValueError):
                validate_report(report, self.task, self.manifest)

    def test_reference_closure_version_and_build_tampering(self):
        mutations = (
            lambda r: r.update(reference_version="1.4.8"),
            lambda r: r["loaded_shared_library_paths"].clear(),
            lambda r: r["loaded_shared_library_paths"].append("/tmp/libzstd.so.1.4.8"),
            lambda r: r["provenance"].update(optimize="Debug"),
            lambda r: r["provenance"].update(affinity_cpu_count=16),
            lambda r: r["provenance"].update(executable_sha256="b" * 64),
            lambda r: r["provenance"].update(cpu_model="different host"),
            lambda r: r["provenance"].update(target_cpu="generic"),
            lambda r: r["provenance"].update(target_abi="musl"),
            lambda r: r["provenance"].update(codec_thread_policy="auto"),
            lambda r: r["alignment"].update(vort_output_mod64=1),
            lambda r: r["validation"].update(guards_per_batch=False),
            lambda r: r.update(reference_api="ZSTD_decompressDCtx"),
        )
        for mutate in mutations:
            report = copy.deepcopy(self.report)
            mutate(report)
            with self.assertRaises(ValueError):
                validate_report(report, self.task, self.manifest)

    def test_frozen_library_or_input_mutation(self):
        self.library.write_bytes(b"different reference")
        with self.assertRaisesRegex(ValueError, "library changed"):
            validate_report(self.report, self.task, self.manifest)
        self.library.write_bytes(b"pinned reference")
        Path(self.fixture["input_path"]).write_bytes(b"changed data")
        with self.assertRaisesRegex(ValueError, "Frozen bytes"):
            validate_report(self.report, self.task, self.manifest)

    def test_matrix_rejects_missing_duplicate_and_unknown_rows(self):
        fixtures = [{"key": f"{codec}/{name}/65536/{level}", "codec": codec, "name": name, "size": "65536", "level": level} for codec, levels in LEVELS.items() for name in SILESIA for level in levels]
        tasks = [{"fixture": f, "lifecycle": lifecycle, "iterations": 100} for f in fixtures for lifecycle in ("cold", "prepared") if not (f["codec"] == "brotli" and lifecycle == "prepared")]
        manifest = {"schema": "vort.decode-matrix.v1", "config": {"sizes": ["65536"], "lifecycles": ["cold", "prepared"], "iterations": {"65536": 100}}, "fixtures": fixtures, "tasks": tasks}
        validate_manifest(manifest)
        mutations = (
            lambda m: m["fixtures"].pop(),
            lambda m: m["fixtures"].append(copy.deepcopy(m["fixtures"][0])),
            lambda m: m["fixtures"][0].update(key="unknown"),
            lambda m: m["fixtures"][0].update(codec="zstd", level=19),
            lambda m: m["tasks"].pop(),
            lambda m: m["tasks"].__setitem__(0, copy.deepcopy(m["tasks"][1])),
            lambda m: m["tasks"][0].update(iterations=99),
            lambda m: m["config"]["sizes"].append("65536"),
            lambda m: m["config"]["lifecycles"].append("cold"),
        )
        for mutate in mutations:
            modified = copy.deepcopy(manifest)
            mutate(modified)
            with self.assertRaises(ValueError):
                validate_manifest(modified)


if __name__ == "__main__":
    unittest.main()
