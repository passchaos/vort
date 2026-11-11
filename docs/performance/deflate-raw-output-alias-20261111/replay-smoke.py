#!/usr/bin/env python3
"""Replay the 72 frozen Deflate wires for functional smoke coverage only."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import subprocess


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--probe", required=True, type=Path)
    parser.add_argument("--fixture-root", required=True, type=Path)
    parser.add_argument("--reference", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args()
    package = Path(__file__).resolve().parent
    original = json.loads((package / "smoke-summary.json").read_text())
    manifest = json.loads(gzip.decompress((package / "fixture-manifest.json.gz").read_bytes()))
    repo, probe, reference = args.repo.resolve(), args.probe.resolve(), args.reference.resolve()
    fixtures, out = args.fixture_root.resolve(), args.out_dir.resolve()
    assert sha(probe) == original["probe_sha256"], "Use the exact archived probe for this replay"
    assert all(sha(repo / path) == digest for path, digest in original["source_sha256"].items()), "Source differs from the repaired smoke epoch"
    assert sha(reference) == next(iter(original["reference"]["file_sha256"].values())), "Reference binary differs"
    assert not out.exists() or not any(out.iterdir()), "Use an empty replay output directory"
    out.mkdir(parents=True, exist_ok=True)
    rows = []
    selected = [fixture for fixture in manifest["fixtures"] if fixture["codec"] == "deflate"]
    assert len(selected) == 72
    for fixture in selected:
        plain = fixtures / Path(fixture["input_path"]).name
        wire = fixtures / Path(fixture["encoded_input_path"]).name
        assert sha(plain) == fixture["input_sha256"] and sha(wire) == fixture["encoded_sha256"], "Frozen fixture identity differs"
        name = f"{fixture['name']}.{fixture['size']}.{fixture['level']}"
        result_path, error_path = out / (name + ".json"), out / (name + ".stderr.txt")
        command = ["taskset", "-c", "15", str(probe), "--codec", "deflate",
                   "--input", str(plain), "--encoded-input", str(wire),
                   "--iterations", "1", "--rounds", "2", "--warmup", "0",
                   "--lifecycle", "cold", "--reference", str(reference),
                   "--reference-version", "1.26", "--output", str(result_path)]
        with error_path.open("wb") as stderr:
            subprocess.run(command, cwd=repo, stdout=subprocess.DEVNULL, stderr=stderr, check=True)
        assert error_path.read_bytes() == b"", "Probe stderr is nonempty"
        row = json.loads(result_path.read_text())
        assert row["provenance"]["executable_sha256"] == original["probe_sha256"]
        assert row["provenance"]["cpu_affinity"] == "15"
        assert row["reference_version"] == "1.26" and row["reference_paths"] == [str(reference)]
        assert str(reference) in row["loaded_shared_library_paths"]
        assert row["warmup_pairs"] == [] and len(row["pairs"]) == 2
        assert row["iterations"] == 1 and row["rounds"] == 2 and row["warmup"] == 0
        assert row["exact_consumption"] == {"vort": True, "reference": True}
        assert all(row["validation"][field] is True for field in
                   ("every_iteration_count", "full_output_per_batch", "guards_per_batch",
                    "input_unchanged_per_batch", "exact_consumption_per_batch"))
        assert row["input_sha256"] == fixture["input_sha256"] and row["encoded_sha256"] == fixture["encoded_sha256"]
        for index, pair in enumerate(row["pairs"]):
            assert pair["pair_id"] == index and pair["first"] == ("vort" if index == 0 else "reference")
            assert pair["vort_mix"] == pair["reference_mix"] == fixture["input_bytes"] + fixture["input_first_byte"]
        rows.append({"key": fixture["key"], "row": result_path.name, "sha256": sha(result_path),
                     "stderr_sha256": sha(error_path)})
    assert all(sha(repo / path) == digest for path, digest in original["source_sha256"].items())
    assert sha(probe) == original["probe_sha256"]
    report = {"schema": "vort.raw-output-alias-replay-smoke.v1", "valid": True,
              "scope": "functional compatibility and benchmark executability; no performance claim",
              "source_sha256": original["source_sha256"], "probe_sha256": sha(probe),
              "reference_path": str(reference), "reference_sha256": sha(reference),
              "fixtures": 72, "paired_batches": 144, "iterations": 1, "rounds": 2,
              "warmup_pairs": 0, "rows": rows}
    (out / "replay-summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print("All 72 frozen fixtures passed; 144 paired batches; functional smoke only")


if __name__ == "__main__":
    main()
