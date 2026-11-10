#!/usr/bin/env python3
"""Reproduce HQ level-policy size evidence; timing is a local trend only."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import lzma
import math
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[4]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "tools/codec_bench"))
from sample_gate import validate

NAMES = ("dickens", "mozilla", "mr", "nci", "ooffice", "osdb",
         "reymont", "samba", "sao", "webster", "x-ray", "xml")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n")


def summarize(output: Path) -> None:
    reports = {}
    manifest = json.loads((output / "inputs.manifest.json").read_text())
    commands = []
    for level, policies in ((9, ("legacy", "hq")), (19, ("hq", "legacy"))):
        for policy in policies:
            report = json.loads((output / f"level{level}-{policy}.json").read_text())
            rows = dict(zip(NAMES, report["rows"], strict=True))
            for name, entry in zip(NAMES, manifest["input_sets"], strict=True):
                assert rows[name]["input_sha256"] == entry["input_sha256"]
                assert sha(lzma.decompress((output / entry["archived_input"]).read_bytes())) == entry["input_sha256"]
            reports[level, policy] = rows
            commands.append(report["provenance"]["command"])
    summary = {"scope": "Silesia 64 KiB prefixes; allocating level presets; no performance acceptance",
               "levels": {}}
    for level in (9, 19):
        comparisons = []
        for name in NAMES:
            legacy, hq = reports[level, "legacy"][name], reports[level, "hq"][name]
            assert legacy["wires"]["reference_sha256"] == hq["wires"]["reference_sha256"]
            size = hq["wires"]["vort_bytes"] / legacy["wires"]["vort_bytes"]
            comparisons.append({"case": name, "legacy_bytes": legacy["wires"]["vort_bytes"],
                                "hq_bytes": hq["wires"]["vort_bytes"],
                                "reference_bytes": hq["wires"]["reference_bytes"], "hq_over_legacy_size": size,
                                "legacy_median_ns": legacy["summary"]["vort_median_ns"],
                                "hq_median_ns": hq["summary"]["vort_median_ns"]})
        summary["levels"][str(level)] = {
            "geomean_hq_over_legacy_size": math.exp(sum(math.log(row["hq_over_legacy_size"])
                                                       for row in comparisons) / len(comparisons)),
            "smaller_rows": sum(row["hq_bytes"] < row["legacy_bytes"] for row in comparisons),
            "at_or_below_reference_rows": sum(row["hq_bytes"] <= row["reference_bytes"] for row in comparisons),
            "rows": comparisons,
        }
    write_json(output / "commands.json", commands)
    write_json(output / "summary.json", summary)
    (output / "SHA256SUMS").write_text("".join(
        f"{sha(path.read_bytes())}  {path.relative_to(output)}\n"
        for path in sorted(output.rglob("*")) if path.is_file() and path.name != "SHA256SUMS"))
    print(json.dumps({level: {key: value for key, value in rows.items() if key != "rows"}
                      for level, rows in summary["levels"].items()}, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--library", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--summarize-only", action="store_true",
                        help="Verify archived input hashes and summarize existing completed reports")
    args = parser.parse_args()
    executable, corpus, library, output = (p.resolve() for p in
                                          (args.executable, args.corpus, args.library, args.output))
    if args.summarize_only:
        summarize(output)
        return
    output.mkdir(parents=True, exist_ok=False)
    (output / "inputs").mkdir()
    source_paths = ("build.zig", "src/zstd.zig", "src/zstd/encode/controls.zig",
                    "src/zstd/encode/hq_level_policy_tests.zig", "tools/zstd/encode_bench.zig",
                    "tools/zstd/encode_bench_options.zig", "tools/zstd/hq_auto_bench_smoke.py")
    source = {
        "base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "executable_sha256": sha(executable.read_bytes()),
        "library_path": str(library), "library_sha256": sha(library.read_bytes()),
        "files": {name: sha((ROOT / name).read_bytes()) for name in source_paths},
    }
    patch = subprocess.check_output(["git", "diff", "--", *source_paths], cwd=ROOT)
    for name in ("src/zstd/encode/hq_level_policy_tests.zig", "tools/zstd/hq_auto_bench_smoke.py"):
        if subprocess.run(["git", "ls-files", "--error-unmatch", name], cwd=ROOT,
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
            added = subprocess.run(["git", "diff", "--no-index", "--", "/dev/null", name],
                                   cwd=ROOT, capture_output=True, check=False)
            assert added.returncode == 1, added.stderr
            patch += added.stdout
    (output / "source-overlay.patch.xz").write_bytes(lzma.compress(patch))
    source["overlay_sha256"] = sha(patch)
    write_json(output / "source.json", source)
    commands = []
    with tempfile.TemporaryDirectory(prefix="vort-hq-level-policy-") as temporary:
        paths = []
        manifest = {"input_sets": []}
        for name in NAMES:
            original = (corpus / name).read_bytes()
            data = original[:65536]
            assert len(data) == 65536, name
            path = Path(temporary) / name
            path.write_bytes(data)
            paths.append(path)
            (output / "inputs" / f"{name}.bin.xz").write_bytes(lzma.compress(data))
            manifest["input_sets"].append({
                "frozen_path": str(path), "input_bytes": len(data), "input_sha256": sha(data),
                "source_path": str(corpus / name), "source_sha256": sha(original),
                "archived_input": f"inputs/{name}.bin.xz",
            })
        write_json(output / "inputs.manifest.json", manifest)
        # Alternate policy order between levels. Each benchmark itself alternates
        # Vort/reference order; no dedicated-host acceptance claim is made.
        for level, policies in ((9, ("legacy", "hq")), (19, ("hq", "legacy"))):
            for policy in policies:
                label = f"level{level}-{policy}"
                command = [str(executable), "--level", str(level), "--iterations", "1", "--rounds", "3",
                           "--libzstd", str(library), "--csv", str(output / f"{label}.csv"),
                           "--samples-json", str(output / f"{label}.json")]
                if policy == "hq":
                    command += ["--hq-auto"]
                for path in paths:
                    command += ["--path", str(path)]
                commands.append(command)
                result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=180)
                (output / f"{label}.log").write_text(result.stdout + result.stderr)
                assert result.returncode == 0, (label, result.returncode, result.stderr)
                report = json.loads((output / f"{label}.json").read_text())
                with (output / f"{label}.csv").open(newline="") as handle:
                    rows = list(csv.DictReader(handle))
                gate = validate(report, manifest, csv_rows=rows, executable=executable,
                                require_explicit_references=True)
                assert gate["rows"] == 12 and gate["rounds"] == 36, gate
                print(f"validated {label}: 12 bidirectional reference rows", flush=True)
    write_json(output / "commands.json", commands)
    summarize(output)


if __name__ == "__main__":
    main()
