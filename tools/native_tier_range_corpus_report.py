#!/usr/bin/env python3
"""Run native seekability tier range benchmark over discoverable standard corpora."""

from __future__ import annotations

import pathlib
import subprocess
import sys
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXE = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 and pathlib.Path(sys.argv[1]).exists() else ROOT / "zig-out" / "bin" / "vort-native-tier-range-bench"
SILESIA = pathlib.Path.home() / "Work" / "zlib-rs" / "silesia-small.tar"
CORPORA_DIR = pathlib.Path.home() / "Work" / "corpora"
STANDARD_CORPUS_CANDIDATES = [
    SILESIA,
    CORPORA_DIR / "calgary.tar",
    CORPORA_DIR / "canterbury.tar",
    CORPORA_DIR / "large-canterbury.tar",
    CORPORA_DIR / "enwik8",
]
SMOKE_LIMIT = 128 * 1024


def discover_standard_corpora() -> list[pathlib.Path]:
    found: list[pathlib.Path] = []
    seen: set[pathlib.Path] = set()
    for path in STANDARD_CORPUS_CANDIDATES:
        if path.exists() and path not in seen:
            found.append(path)
            seen.add(path)
    return found


def append_case(cases: list[tuple[str, bytes]], label: str, data: bytes, full: bool, limit: int | None) -> bool:
    if not full:
        data = data[:SMOKE_LIMIT]
        label = f"{label}-128k"
    cases.append((label, data))
    return limit is not None and len(cases) >= limit


def load_archive_cases(path: pathlib.Path, full: bool, limit: int | None) -> list[tuple[str, bytes]]:
    cases: list[tuple[str, bytes]] = []
    with tarfile.open(path, "r:*") as tar:
        for member in tar.getmembers():
            if not member.isfile():
                continue
            extracted = tar.extractfile(member)
            if extracted is None:
                continue
            label = member.name.removeprefix("silesia-small/")
            if label == member.name:
                label = f"{path.name}:{member.name}"
            if append_case(cases, label, extracted.read(), full, limit):
                return cases
    return cases


def load_path_cases(paths: list[pathlib.Path], full: bool, limit: int | None) -> list[tuple[str, bytes]]:
    cases: list[tuple[str, bytes]] = []
    for path in paths:
        if path.is_dir():
            for child in sorted(p for p in path.rglob("*") if p.is_file()):
                label = str(child.relative_to(path.parent))
                if append_case(cases, label, child.read_bytes(), full, limit):
                    return cases
        elif tarfile.is_tarfile(path):
            remaining = None if limit is None else max(0, limit - len(cases))
            cases.extend(load_archive_cases(path, full, remaining))
            if limit is not None and len(cases) >= limit:
                return cases
        else:
            if append_case(cases, path.name, path.read_bytes(), full, limit):
                return cases
    return cases


def main() -> int:
    if not EXE.exists():
        raise SystemExit(f"missing native tier range bench executable at {EXE}; run zig build first")
    full = "--full" in sys.argv[1:]
    limit = 3
    csv_path: pathlib.Path | None = None
    extra_args: list[str] = []
    paths: list[pathlib.Path] = []
    index = 1
    while index < len(sys.argv):
        arg = sys.argv[index]
        if pathlib.Path(arg).exists() and index == 1:
            index += 1
            continue
        if arg == "--limit" and index + 1 < len(sys.argv):
            limit = int(sys.argv[index + 1])
            index += 2
            continue
        if arg == "--csv" and index + 1 < len(sys.argv):
            csv_path = pathlib.Path(sys.argv[index + 1])
            index += 2
            continue
        if arg in {"--iterations", "--repeat", "--range-len"} and index + 1 < len(sys.argv):
            extra_args.extend([arg, sys.argv[index + 1]])
            index += 2
            continue
        if arg == "--paths":
            index += 1
            while index < len(sys.argv) and not sys.argv[index].startswith("--"):
                paths.append(pathlib.Path(sys.argv[index]))
                index += 1
            continue
        index += 1

    sources = paths or discover_standard_corpora()
    cases = load_path_cases(sources, full, limit)
    if not cases:
        print("native tier range corpus report: no standard corpora discovered")
        return 0

    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        sample_paths: list[str] = []
        labels: list[str] = []
        for i, (label, data) in enumerate(cases):
            safe = label.replace("/", "_").replace(":", "_")
            path = root / f"{i:03d}-{safe}.bin"
            path.write_bytes(data)
            sample_paths.append(str(path))
            labels.append(label)
        out_csv = csv_path or (root / "native-tier-range-corpus.csv")
        subprocess.run([str(EXE), "--csv", str(out_csv), *extra_args, "--paths", *sample_paths], cwd=ROOT, check=True)
        text = out_csv.read_text().splitlines()
        if not text:
            return 1
        header = text[0]
        print(header)
        for line in text[1:]:
            parts = line.split(",", 1)
            fixture = parts[0]
            label = labels[int(fixture.split("-", 1)[0])] if fixture[:3].isdigit() else fixture
            print(f"{label},{parts[1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
