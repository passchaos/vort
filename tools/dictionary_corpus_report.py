#!/usr/bin/env python3
import pathlib
import re
import subprocess
import sys
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXE = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 and pathlib.Path(sys.argv[1]).exists() else ROOT / "zig-out" / "bin" / "vort-dictionary-report"
SILESIA = pathlib.Path.home() / "Work" / "zlib-rs" / "silesia-small.tar"
SMOKE_LIMIT = 32 * 1024
FIELDS = [
    "target",
    "dict_bytes",
    "sample_bytes",
    "patch_deflate_bytes",
    "patch_deflate_ratio",
    "best_with_dict_bytes",
    "best_with_dict_ratio",
    "best_with_dict_patches",
    "best_with_dict_deflates",
    "baseline_deflate_bytes",
    "baseline_ratio",
]


def load_cases(full: bool) -> list[tuple[str, bytes]]:
    if not SILESIA.exists():
        return []
    cases: list[tuple[str, bytes]] = []
    with tarfile.open(SILESIA, "r:*") as tar:
        for member in tar.getmembers():
            if not member.isfile():
                continue
            extracted = tar.extractfile(member)
            if extracted is None:
                continue
            data = extracted.read()
            label = member.name.removeprefix("silesia-small/")
            if not full:
                data = data[:SMOKE_LIMIT]
                label = f"{label}-32k"
            cases.append((label, data))
    return cases


def main() -> int:
    if not EXE.exists():
        raise SystemExit(f"missing dictionary report executable at {EXE}; run zig build first")
    full = "--full" in sys.argv[1:]
    all_cases = "--all" in sys.argv[1:]
    per_file = "--per-file" in sys.argv[1:]
    target_args: list[str] = []
    target_values: list[str] = []
    markdown_path = None
    for index, arg in enumerate(sys.argv):
        if arg == "--markdown" and index + 1 < len(sys.argv):
            markdown_path = pathlib.Path(sys.argv[index + 1])
        if arg == "--target" and index + 1 < len(sys.argv):
            target_args = ["--target", sys.argv[index + 1]]
        if arg == "--targets" and index + 1 < len(sys.argv):
            target_values = [value for value in sys.argv[index + 1].split(",") if value]
    cases = load_cases(full)
    if not all_cases:
        cases = cases[:3]
    if not cases:
        print("dictionary corpus report: missing silesia-small.tar")
        return 0
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        paths: list[str] = []
        for index, (label, data) in enumerate(cases):
            sample = root / f"{index:03d}-{label.replace('/', '_')}.bin"
            sample.write_bytes(data)
            paths.append(str(sample))
        if target_values:
            rows = []
            print("target,report")
            for target in target_values:
                report = subprocess.run([str(EXE), "--target", target, *paths], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()
                parsed = parse_report(report)
                rows.append((f"target-{target}", parsed))
                print(f"{target},{report}")
            if markdown_path is not None:
                write_markdown(rows, markdown_path, full)
        elif per_file:
            rows = []
            print("case,report")
            for label, path in zip((label for label, _ in cases), paths):
                report = subprocess.run([str(EXE), *target_args, path], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()
                rows.append((label, parse_report(report)))
                print(f"{label},{report}")
            if markdown_path is not None:
                write_markdown(rows, markdown_path, full)
        else:
            print(subprocess.run([str(EXE), *target_args, *paths], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip())
    return 0


def parse_report(report: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for field in FIELDS:
        match = re.search(rf"{field}=([^ ]+)", report)
        parsed[field] = match.group(1) if match else ""
    return parsed


def write_markdown(rows: list[tuple[str, dict[str, str]]], path: pathlib.Path, full: bool) -> None:
    summary = summarize_rows(rows)
    lines = [
        "# Dictionary corpus report",
        "",
        f"- mode: `{'full' if full else 'bounded-32KiB'}`",
        f"- rows: {len(rows)}",
        f"- total sample bytes: {summary['sample_bytes']}",
        f"- total best+dict bytes: {summary['best_with_dict_bytes']}",
        f"- total baseline bytes: {summary['baseline_deflate_bytes']}",
        f"- net delta bytes: {summary['delta_bytes']}",
        f"- files improved: {summary['improved']}",
        f"- files regressed: {summary['regressed']}",
        "",
        "## Rows",
        "",
        "| corpus | target | dict bytes | sample bytes | patch deflate bytes | patch deflate ratio | best+dict bytes | best+dict ratio | dict frames | baseline bytes | baseline ratio |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for label, row in rows:
        dict_frames = int(row.get("best_with_dict_patches") or 0) + int(row.get("best_with_dict_deflates") or 0)
        lines.append(
            f"| {label} | {row['target']} | {row['dict_bytes']} | {row['sample_bytes']} | {row['patch_deflate_bytes']} | {row['patch_deflate_ratio']} | {row['best_with_dict_bytes']} | {row['best_with_dict_ratio']} | {dict_frames} | {row['baseline_deflate_bytes']} | {row['baseline_ratio']} |"
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def summarize_rows(rows: list[tuple[str, dict[str, str]]]) -> dict[str, int]:
    summary = {
        "sample_bytes": 0,
        "best_with_dict_bytes": 0,
        "baseline_deflate_bytes": 0,
        "delta_bytes": 0,
        "improved": 0,
        "regressed": 0,
    }
    for _, row in rows:
        best = int(row.get("best_with_dict_bytes") or 0)
        baseline = int(row.get("baseline_deflate_bytes") or 0)
        summary["sample_bytes"] += int(row.get("sample_bytes") or 0)
        summary["best_with_dict_bytes"] += best
        summary["baseline_deflate_bytes"] += baseline
        if best < baseline:
            summary["improved"] += 1
        elif best > baseline:
            summary["regressed"] += 1
    summary["delta_bytes"] = summary["best_with_dict_bytes"] - summary["baseline_deflate_bytes"]
    return summary


if __name__ == "__main__":
    raise SystemExit(main())
