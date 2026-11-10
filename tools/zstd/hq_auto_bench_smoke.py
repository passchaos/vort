#!/usr/bin/env python3
"""Bounded HQ-auto encode benchmark CLI and sample metadata contracts."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "tools/codec_bench"))
from sample_gate import validate


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def reference_library() -> Path | None:
    candidates = (
        Path.home() / "Work/zstd/lib/libzstd.so.1.6.0",
        Path("/lib/x86_64-linux-gnu/libzstd.so.1"),
        Path("/usr/lib/x86_64-linux-gnu/libzstd.so.1"),
        Path("/lib/aarch64-linux-gnu/libzstd.so.1"),
        Path("/usr/lib/aarch64-linux-gnu/libzstd.so.1"),
        Path("/opt/homebrew/opt/zstd/lib/libzstd.dylib"),
        Path("/usr/local/opt/zstd/lib/libzstd.dylib"),
    )
    return next((path.resolve() for path in candidates if path.is_file()), None)


def run_case(executable: Path, library: Path | None, directory: Path, source: Path,
             name: str, level: int, flags: tuple[str, ...] = ()) -> dict:
    csv_path, json_path = directory / f"{name}.csv", directory / f"{name}.json"
    command = [str(executable), "--level", str(level), "--path", str(source),
               "--iterations", "1", "--rounds", "2", "--csv", str(csv_path),
               "--samples-json", str(json_path), *flags]
    if library is not None:
        command += ["--libzstd", str(library)]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, (name, result.stdout, result.stderr)
    report = json.loads(json_path.read_text())
    with csv_path.open(newline="") as handle:
        csv_rows = list(csv.DictReader(handle))
    manifest = {"input_sets": [{"frozen_path": str(source), "input_bytes": source.stat().st_size,
                                "input_sha256": digest(source.read_bytes())}]}
    checked = validate(report, manifest, csv_rows=csv_rows, executable=executable,
                       require_explicit_references=library is not None)
    assert checked["rows"] == 1 and checked["rounds"] == 2, name
    assert report["codec"] == "zstd", name
    assert report["provenance"]["codec_thread_policy"] == "internal-auto", name
    assert ("--hq-auto" in report["provenance"]["command"].split()) == ("--hq-auto" in flags), name
    row = report["rows"][0]
    settings = row["settings"]
    assert settings["level"] == level, name
    assert settings["comparison_mode"] == "level_preset", name
    assert settings["requested_controls_match"] is None, name
    assert settings["reference"]["level"] == level, name
    assert settings["reference"]["api"] == "ZSTD_compress", name
    assert settings["reference"]["requested_parameters"] is None, name
    assert settings["resolved_primary"]["control_profile_enabled"] is False, name
    assert settings["resolved_primary"]["memory_profile_enabled"] is False, name
    if library is not None:
        assert report["references"][0]["requested_path"] == str(library), name
    return row


def assert_same_path_and_wire(left: dict, right: dict, name: str) -> None:
    for field in ("api", "resolved_primary", "internal_candidate_settings", "wire_header", "reference"):
        assert left["settings"][field] == right["settings"][field], (name, field)
    # Hash identity also protects deterministic wire bytes, beyond size alone.
    assert left["wires"] == right["wires"], (name, "HQ-auto changed the explicit/legacy wire")


def assert_hq(row: dict, strategy: str, depth: int, nice: int) -> None:
    settings, name = row["settings"], row["case"]
    primary, profile = settings["resolved_primary"], settings["vort_profile"]
    assert settings["api"] == "native_frame", name
    assert settings["internal_candidate_settings"] == "resolved_primary", name
    assert primary["strategy"] == strategy and primary["selection"] == "fast_compressed", name
    assert primary["fast_acceleration"] is None and primary["rep_beam_search"] is False, name
    hq = primary["hq"]
    assert hq["search_depth"] == depth and hq["nice_len"] == nice and hq["min_match"] == 3, name
    assert hq["parse_mode"] == "bounded" and hq["match_lengths"] == "sampled", name
    assert hq["parser_engine"] == "local_optimal" and hq["max_price_evaluations"] is None, name
    assert profile["available"] and profile["controls_used"] and profile["hq_used"], name
    assert profile["resolved_strategy"] == strategy, name
    for field in ("search_depth", "nice_len", "min_match", "max_working_memory",
                  "parser_engine", "parse_mode", "match_lengths", "max_price_evaluations"):
        assert profile[f"effective_hq_{field}"] == hq[field], (name, field)
    # These counters demonstrate actual parsing, matching and wire publication.
    for field in ("positions_tested", "parser_matches", "tree_nodes", "byte_comparisons",
                  "price_evaluations", "hq_passes", "bounded_passes", "sampled_length_passes",
                  "compressed_blocks"):
        assert profile[field] > 0, (name, "no actual HQ work", field)
    if strategy == "btultra2":
        assert profile["hq_passes"] >= 2 and profile["refinement_passes"] > 0, name
    else:
        assert profile["refinement_passes"] == 0, name


def assert_non_hq(row: dict, strategy: str, acceleration: int = 1) -> None:
    settings, name = row["settings"], row["case"]
    primary, profile = settings["resolved_primary"], settings["vort_profile"]
    assert settings["api"] == "native_frame", name
    assert primary["strategy"] == strategy and primary["hq"] is None, name
    assert profile["available"] and profile["controls_used"] and not profile["hq_used"], name
    assert profile["resolved_strategy"] == strategy and profile["fast_acceleration"] == acceleration, name
    assert profile["positions_tested"] > 0 and profile["parser_matches"] > 0, name
    assert profile["hq_passes"] == profile["price_evaluations"] == 0, name


def cli_rejections(executable: Path, library: Path | None, directory: Path, source: Path) -> int:
    invalid = (
        (("--level", "9", "--hq-auto", "--hq-auto"), "DuplicateZstdOption"),
        (("--hq-auto", "--level", "9", "--level=22"), "DuplicateZstdOption"),
        (("--hq-auto", "--level", "23"), "InvalidBlockPlan"),
        (("--hq-auto", "--level=-131073"), "InvalidBlockPlan"),
        (("--hq-auto", "--level", "-2147483648"), "InvalidBlockPlan"),
    )
    # Always preserve existing CSV and JSON; also verify no new output is made.
    for index, (flags, error) in enumerate(invalid):
        for existing in (True, False):
            csv_path = directory / f"invalid-{index}-{existing}.csv"
            json_path = directory / f"invalid-{index}-{existing}.json"
            before = b"existing output sentinel\n"
            for path in (csv_path, json_path):
                if existing:
                    path.write_bytes(before)
                else:
                    path.unlink(missing_ok=True)
            command = [str(executable), "--path", str(source), "--iterations", "1", "--rounds", "2",
                       "--csv", str(csv_path), "--samples-json", str(json_path), *flags]
            if library is not None:
                command += ["--libzstd", str(library)]
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=30)
            assert result.returncode != 0 and error in result.stderr, (index, command, result.stdout, result.stderr)
            for path in (csv_path, json_path):
                if existing:
                    assert path.read_bytes() == before, (index, "failed CLI overwrote output", path)
                else:
                    assert not path.exists(), (index, "failed CLI created output", path)
    return len(invalid) * 2


def campaign(executable: Path, library: Path | None, directory: Path) -> dict:
    help_result = subprocess.run([str(executable), "--help"], cwd=ROOT, capture_output=True, text=True, timeout=30)
    assert help_result.returncode == 0 and "--hq-auto" in help_result.stdout, (help_result.stdout, help_result.stderr)
    source = directory / "source-2048.zig"
    source.write_bytes((ROOT / "src/zstd/match/hq_parser/prices.zig").read_bytes()[:2048])
    (directory / "inputs.manifest.json").write_text(json.dumps({"input_sets": [
        {"frozen_path": str(source), "input_bytes": source.stat().st_size,
         "input_sha256": digest(source.read_bytes())}]}, indent=2) + "\n")
    commands = 0
    legacy = run_case(executable, library, directory, source, "legacy-level8", 8)
    unchanged = run_case(executable, library, directory, source, "hq-auto-level8", 8, ("--hq-auto",))
    assert_same_path_and_wire(legacy, unchanged, "level8")
    assert unchanged["settings"]["api"] == "level_policy", "level8 must retain legacy arbitration"
    assert unchanged["settings"]["resolved_primary"]["strategy"] == "auto", "level8"
    assert unchanged["settings"]["resolved_primary"]["hq"] is None, "level8"
    commands += 2
    for level, strategy, depth, nice in ((9, "btopt", 64, 128), (16, "btultra", 128, 256),
                                         (19, "btultra2", 256, 512), (22, "btultra2", 256, 512)):
        row = run_case(executable, library, directory, source, f"hq-auto-level{level}", level, ("--hq-auto",))
        assert row["settings"]["requested_strategy"] is None, level
        assert row["settings"]["requested_fast_acceleration"] is None, level
        assert_hq(row, strategy, depth, nice)
        commands += 1
    overrides = (
        ("strategy-greedy", ("--strategy", "greedy"), "greedy", 1),
        ("strategy-btopt", ("--strategy=btopt",), "btopt", 1),
        ("fast-acceleration", ("--fast-acceleration", "4"), "fast", 4),
        ("fast-long-matches", ("--fast-long-matches",), "fast", 1),
    )
    for name, flags, strategy, acceleration in overrides:
        baseline = run_case(executable, library, directory, source, f"{name}-legacy", 22, flags)
        row = run_case(executable, library, directory, source, f"{name}-hq-auto", 22, ("--hq-auto", *flags))
        assert_same_path_and_wire(baseline, row, name)
        assert row["settings"]["requested_strategy"] == (strategy if name.startswith("strategy-") else None), name
        assert row["settings"]["requested_fast_acceleration"] == (4 if name == "fast-acceleration" else None), name
        if strategy == "btopt":
            assert_hq(row, strategy, 256, 512)
        else:
            assert_non_hq(row, strategy, acceleration)
        if name == "fast-long-matches":
            assert row["settings"]["vort_profile"]["long_hash_probes"] > 0, name
        commands += 2
    return {"status": "ok", "commands": commands, "rows": commands, "hq_auto_levels": [9, 16, 19, 22],
            "explicit_overrides": len(overrides), "cli_rejections": cli_rejections(executable, library, directory, source),
            "explicit_libzstd": library is not None, "scope": "CLI and sample metadata; no performance gate"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("--libzstd", type=Path)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    executable = args.executable.resolve(strict=True)
    library = args.libzstd.resolve(strict=True) if args.libzstd else reference_library()
    if args.output_dir:
        directory = args.output_dir.resolve()
        directory.mkdir(parents=True, exist_ok=True)
        summary = campaign(executable, library, directory)
        (directory / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    else:
        with tempfile.TemporaryDirectory(prefix="vort-zstd-hq-auto-") as temporary:
            summary = campaign(executable, library, Path(temporary))
    print("zstd_hq_auto_bench_smoke=" + json.dumps(summary, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
