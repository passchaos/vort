#!/usr/bin/env python3
"""Run and validate the Brotli serialized-dictionary real-corpus report."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

import real_corpus_diff

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "vort.br_serialized_dictionary_trainer_report"
SCHEMA_VERSION = 1
HEADER = (
    "label", "category", "input_bytes", "training_samples", "validation_samples",
    "baseline_frames", "trained_frames", "dictionary_bytes", "total_bytes",
    "savings", "ratio_ppm", "winner", "word_profile", "cover_d", "cover_hash_log",
    "context_profile", "context_mode", "context_cutoff", "context_clusters",
    "transform_profile", "transform_lists", "shift_parameters", "train_ns",
    "peak_bytes", "worst_sample_delta",
)
INTEGER_FIELDS = {
    "input_bytes", "training_samples", "validation_samples", "baseline_frames",
    "trained_frames", "dictionary_bytes", "total_bytes", "savings", "winner",
    "ratio_ppm",
    "context_clusters", "transform_lists", "shift_parameters", "train_ns",
    "peak_bytes", "worst_sample_delta",
}
OPTIONAL_INTEGER_FIELDS = {"cover_d", "cover_hash_log", "context_mode", "context_cutoff"}


def parse_rows(output: str) -> list[dict[str, object]]:
    lines = [line for line in output.splitlines() if line]
    if not lines or tuple(lines[0].split("\t")) != HEADER:
        raise RuntimeError("serialized trainer report has an unexpected header")
    rows: list[dict[str, object]] = []
    for line_number, line in enumerate(lines[1:], 2):
        values = line.split("\t")
        if len(values) != len(HEADER):
            raise RuntimeError(f"report line {line_number} has {len(values)} fields")
        row: dict[str, object] = dict(zip(HEADER, values))
        try:
            for field in INTEGER_FIELDS:
                row[field] = int(str(row[field]), 10)
            for field in OPTIONAL_INTEGER_FIELDS:
                row[field] = None if row[field] == "-" else int(str(row[field]), 10)
        except ValueError as error:
            raise RuntimeError(f"report line {line_number} has a malformed integer") from error
        rows.append(row)
    return rows


def validate_rows(rows: list[dict[str, object]], manifest: real_corpus_diff.Manifest, limit: int) -> dict[str, int]:
    if len(rows) != len(manifest.cases):
        raise RuntimeError(f"report has {len(rows)} cases; expected {len(manifest.cases)}")
    by_label = {str(row["label"]): row for row in rows}
    if len(by_label) != len(rows):
        raise RuntimeError("report contains duplicate labels")
    winners = 0
    totals = {
        "input_bytes": 0,
        "baseline_frames": 0,
        "trained_frames": 0,
        "dictionary_bytes": 0,
        "total_bytes": 0,
        "savings": 0,
        "train_ns": 0,
        "peak_bytes": 0,
        "worst_sample_delta": 0,
    }
    for case in manifest.cases:
        row = by_label.get(case.label)
        if row is None:
            raise RuntimeError(f"report misses case {case.label}")
        if row["category"] != case.category:
            raise RuntimeError(f"case {case.label} changed category")
        expected_bytes = min(limit, case.byte_count)
        if row["input_bytes"] != expected_bytes:
            raise RuntimeError(f"case {case.label} used {row['input_bytes']} bytes; expected {expected_bytes}")
        baseline = int(row["baseline_frames"])
        total = int(row["total_bytes"])
        savings = int(row["savings"])
        winner = int(row["winner"])
        if baseline <= 0 or total <= 0 or total > baseline or savings != baseline - total:
            raise RuntimeError(f"case {case.label} violates complete-total accounting")
        if row["ratio_ppm"] != total * 1_000_000 // baseline:
            raise RuntimeError(f"case {case.label} has an inconsistent ratio")
        if winner not in (0, 1):
            raise RuntimeError(f"case {case.label} has invalid winner flag")
        if winner == 0 and (savings != 0 or row["dictionary_bytes"] != 0 or row["word_profile"] != "none"):
            raise RuntimeError(f"case {case.label} reports a synthetic non-winner")
        if winner == 1:
            winners += 1
            if row["word_profile"] not in ("heavy_hitter", "cover"):
                raise RuntimeError(f"case {case.label} has an unknown word profile")
        if int(row["training_samples"]) < 5 or int(row["validation_samples"]) <= 0:
            raise RuntimeError(f"case {case.label} has an invalid partition")
        if int(row["train_ns"]) <= 0 or int(row["peak_bytes"]) <= 0:
            raise RuntimeError(f"case {case.label} lacks resource evidence")
        if int(row["peak_bytes"]) > 1024 * 1024 * 1024:
            raise RuntimeError(f"case {case.label} exceeds the 1 GiB logical peak guard")
        for field in totals:
            if field == "peak_bytes":
                totals[field] = max(totals[field], int(row[field]))
            elif field == "worst_sample_delta":
                totals[field] = max(totals[field], int(row[field]))
            else:
                totals[field] += int(row[field])
    totals["winners"] = winners
    totals["cases"] = len(rows)
    totals["categories"] = len({case.category for case in manifest.cases})
    totals["ratio_ppm"] = totals["total_bytes"] * 1_000_000 // totals["baseline_frames"]
    return totals


def write_json(path: Path, rows: list[dict[str, object]], summary: dict[str, int], limit: int, chunk: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    document = {
        "schema": SCHEMA,
        "schema_version": SCHEMA_VERSION,
        "limit": limit,
        "chunk_size": chunk,
        "summary": summary,
        "cases": rows,
    }
    path.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_markdown(path: Path, rows: list[dict[str, object]], summary: dict[str, int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Brotli serialized dictionary trainer corpus report",
        "",
        f"Cases: {summary['cases']}; categories: {summary['categories']}; winners: {summary['winners']}.",
        "",
        "| Case | Category | Baseline | Frames | Dictionary | Total | Ratio | Saving | Word/context/transform | Train ms | Peak MiB | Worst delta |",
        "|---|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|",
    ]
    for row in rows:
        profiles = f"{row['word_profile']}/{row['context_profile']}/{row['transform_profile']}"
        lines.append(
            f"| {row['label']} | {row['category']} | {row['baseline_frames']} | "
            f"{row['trained_frames']} | {row['dictionary_bytes']} | {row['total_bytes']} | "
            f"{int(row['ratio_ppm']) / 10_000:.2f}% | {row['savings']} | {profiles} | {int(row['train_ns']) / 1_000_000:.1f} | "
            f"{int(row['peak_bytes']) / (1024 * 1024):.2f} | {row['worst_sample_delta']} |"
        )
    lines.extend([
        "",
        f"Aggregate baseline/total/saving: {summary['baseline_frames']}/{summary['total_bytes']}/{summary['savings']} bytes ({summary['ratio_ppm'] / 10_000:.2f}%).",
        f"Total training time: {summary['train_ns'] / 1_000_000:.1f} ms; maximum logical peak: {summary['peak_bytes'] / (1024 * 1024):.2f} MiB.",
        "",
        "Times are observational; the gate enforces accounting, coverage, determinism tests, and a 1 GiB logical peak guard, not a host-dependent latency ceiling.",
    ])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("executable", type=Path)
    parser.add_argument("--manifest", type=Path, default=ROOT / "tools/br/serialized_dictionary_trainer_manifest.json")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--limit", type=int, default=16 * 1024)
    parser.add_argument("--chunk", type=int, default=256)
    parser.add_argument("--json", type=Path, default=ROOT / "zig-out/vort-br-serialized-trainer-report.json")
    parser.add_argument("--markdown", type=Path, default=ROOT / "zig-out/vort-br-serialized-trainer-report.md")
    args = parser.parse_args()
    if args.limit <= 0 or args.chunk < 64 or args.limit < args.chunk:
        raise RuntimeError("invalid report limit/chunk")
    manifest = real_corpus_diff.load_manifest(args.manifest.resolve(), args.root.resolve())
    command = [str(args.executable.resolve()), "--limit", str(args.limit), "--chunk", str(args.chunk)]
    for case in manifest.cases:
        command.extend(("--case", case.label, case.category, str(case.path)))
    result = subprocess.run(command, cwd=args.root.resolve(), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    if result.returncode != 0:
        if result.stdout:
            print(result.stdout, end="")
        raise RuntimeError(f"serialized trainer report failed with exit code {result.returncode}")
    rows = parse_rows(result.stdout)
    summary = validate_rows(rows, manifest, args.limit)
    write_json(args.json, rows, summary, args.limit, args.chunk)
    write_markdown(args.markdown, rows, summary)
    print(
        "br_serialized_trainer_report=ok "
        f"cases={summary['cases']} categories={summary['categories']} winners={summary['winners']} "
        f"baseline={summary['baseline_frames']} total={summary['total_bytes']} savings={summary['savings']} "
        f"train_ns={summary['train_ns']} peak_bytes={summary['peak_bytes']} worst_delta={summary['worst_sample_delta']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
