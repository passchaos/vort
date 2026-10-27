#!/usr/bin/env python3
"""Compare ordinary public q8 encoding and retain reference-library metadata."""
import argparse
import csv
import json
import lzma
import math
import statistics
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--library-directory", type=Path, required=True)
    options = parser.parse_args()
    options.output.mkdir(parents=True, exist_ok=True)
    paths = sorted(path for path in options.corpus.iterdir() if path.is_file())
    if len(paths) != 12:
        parser.error("expected exactly 12 Silesia files")
    records, shapes, samples = [], {}, {}
    for block in range(2):
        labels = ["baseline", "candidate"] if block == 0 else ["candidate", "baseline"]
        for limit in (4096, 16384, 65536):
            for label in labels:
                json_path = options.output / f"{label}-{block}-{limit}.json"
                csv_path = json_path.with_suffix(".csv")
                command = ["taskset", "-c", "2", getattr(options, label), "--planned-quality", "8", "--quality", "8", "--iterations", "1", "--limit", str(limit), "--samples-json", str(json_path), "--csv", str(csv_path)]
                for role, filename in (("encoder", "libbrotlienc.so.1.0.9"), ("decoder", "libbrotlidec.so.1.0.9"), ("common", "libbrotlicommon.so.1.0.9")):
                    command.extend(("--libbrotli-" + role, str(options.library_directory / filename)))
                for path in paths:
                    command.extend(("--path", str(path)))
                subprocess.run(command, check=True)
                result = json.loads(json_path.read_text())
                if len(result["rows"]) != 12 or result["round_count"] != 5:
                    raise RuntimeError("unexpected encoding samples")
                for row in result["rows"]:
                    key = (row["case"], row["input_bytes"])
                    shape = (row["input_sha256"], row["wires"], row["settings"])
                    if key in shapes and shapes[key] != shape:
                        raise RuntimeError(f"input, wire or settings changed: {key}")
                    shapes[key] = shape
                    samples.setdefault((key, label), []).extend(round_["vort_ns"] for round_ in row["rounds"])
                records.append({"block": block, "label": label, "limit": limit, "command": command, "result": result})
                json_path.unlink()
                csv_path.unlink()
    rows = []
    for key, shape in sorted(shapes.items()):
        baseline_ns = statistics.median(samples[key, "baseline"])
        candidate_ns = statistics.median(samples[key, "candidate"])
        rows.append({"case": key[0], "input_bytes": key[1], "input_sha256": shape[0], "wire_bytes": shape[1]["vort_bytes"], "wire_sha256": shape[1]["vort_sha256"], "baseline_ns": baseline_ns, "candidate_ns": candidate_ns, "candidate_over_baseline": candidate_ns / baseline_ns})
    summary = {"schema": "vort.brotli.fused-suffix-encoding.v1", "cases": len(rows), "all_wires_and_settings_equal": True, "aggregation": "median of ten ordinary public encode samples per case and version", "geometric_ratio": math.exp(statistics.mean(math.log(row["candidate_over_baseline"]) for row in rows)), "reference_comparison": "q8 generic; Vort default lgwin16, libbrotli lgwin22; not a matched-window competitor ranking", "rows": rows}
    (options.output / "raw.json.xz").write_bytes(lzma.compress(json.dumps(records, separators=(",", ":")).encode()))
    (options.output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    with (options.output / "rows.csv").open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(json.dumps({key: summary[key] for key in ("cases", "all_wires_and_settings_equal", "geometric_ratio")}))


if __name__ == "__main__":
    main()
