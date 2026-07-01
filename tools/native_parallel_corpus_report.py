#!/usr/bin/env python3
import pathlib
import subprocess
import sys
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXE = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 and pathlib.Path(sys.argv[1]).exists() else ROOT / "zig-out" / "bin" / "vort-bench-native-parallel"
SILESIA = pathlib.Path.home() / "Work" / "zlib-rs" / "silesia-small.tar"
STANDARD_CORPUS_CANDIDATES = [
    SILESIA,
    pathlib.Path.home() / "Work" / "corpora" / "calgary.tar",
    pathlib.Path.home() / "Work" / "corpora" / "canterbury.tar",
    pathlib.Path.home() / "Work" / "corpora" / "large-canterbury.tar",
    pathlib.Path.home() / "Work" / "corpora" / "enwik8",
]
SMOKE_LIMIT = 128 * 1024
HEADER = "corpus,mode,workers,input_bytes,stream_bytes,elapsed_ms,range_offset,range_len,range_crc32"
COLS = HEADER.split(",")


def load_default_cases(full: bool) -> list[tuple[str, bytes]]:
    return load_archive_cases(SILESIA, full) if SILESIA.exists() else []


def discover_standard_corpora() -> list[pathlib.Path]:
    found: list[pathlib.Path] = []
    seen: set[pathlib.Path] = set()
    for path in STANDARD_CORPUS_CANDIDATES:
        if path.exists() and path not in seen:
            found.append(path)
            seen.add(path)
    return found


def load_archive_cases(path: pathlib.Path, full: bool) -> list[tuple[str, bytes]]:
    cases: list[tuple[str, bytes]] = []
    with tarfile.open(path, "r:*") as tar:
        for member in tar.getmembers():
            if not member.isfile():
                continue
            extracted = tar.extractfile(member)
            if extracted is None:
                continue
            data = extracted.read()
            label = member.name.removeprefix("silesia-small/")
            if label == member.name:
                label = f"{path.name}:{member.name}"
            if not full:
                data = data[:SMOKE_LIMIT]
                label = f"{label}-128k"
            cases.append((label, data))
    return cases


def load_path_cases(paths: list[pathlib.Path], full: bool) -> list[tuple[str, bytes]]:
    cases: list[tuple[str, bytes]] = []
    for path in paths:
        if path.is_dir():
            for child in sorted(p for p in path.rglob("*") if p.is_file()):
                data = child.read_bytes()
                label = str(child.relative_to(path.parent))
                if not full:
                    data = data[:SMOKE_LIMIT]
                    label = f"{label}-128k"
                cases.append((label, data))
        elif tarfile.is_tarfile(path):
            cases.extend(load_archive_cases(path, full))
        else:
            data = path.read_bytes()
            label = path.name
            if not full:
                data = data[:SMOKE_LIMIT]
                label = f"{label}-128k"
            cases.append((label, data))
    return cases


def format_paths(paths: list[pathlib.Path]) -> str:
    return ", ".join(str(path) for path in paths) if paths else "none"


def row_to_dict(row: str) -> dict[str, str]:
    return dict(zip(COLS, row.split(",")))


def write_markdown(rows: list[str], path: pathlib.Path, full: bool, external_paths: bool = False, sources: list[pathlib.Path] | None = None) -> None:
    records = [row_to_dict(row) for row in rows]
    lines = [
        "# Native parallel external corpus benchmark" if external_paths else "# Native parallel Silesia benchmark",
        "",
        f"- mode: `{'full' if full else 'bounded-128KiB'}`",
        f"- rows: {len(records)}",
        f"- sources: `{format_paths(sources or [])}`",
        "",
        "## Summary by mode",
        "",
        "| mode | workers | files | total input | total stream bytes | total elapsed ms | MiB/s |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for summary in summarize_by_mode(records):
        lines.append(
            "| {mode} | {workers} | {files} | {input_bytes} | {stream_bytes} | {elapsed_ms:.3f} | {mib_s:.2f} |".format(**summary)
        )
    lines.extend([
        "",
        "## Rows",
        "",
        "| corpus | mode | workers | input | stream bytes | elapsed ms | range crc32 |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: |",
    ])
    for rec in records:
        lines.append("| {corpus} | {mode} | {workers} | {input_bytes} | {stream_bytes} | {elapsed_ms} | {range_crc32} |".format(**rec))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def summarize_by_mode(records: list[dict[str, str]]) -> list[dict[str, object]]:
    by_mode: dict[str, dict[str, object]] = {}
    for rec in records:
        mode = rec["mode"]
        workers = rec.get("workers", "")
        key = f"{mode}:{workers}"
        entry = by_mode.setdefault(key, { "mode": mode, "workers": workers, "files": 0, "input_bytes": 0, "stream_bytes": 0, "elapsed_ms": 0.0, "mib_s": 0.0 })
        entry["files"] = int(entry["files"]) + 1
        entry["input_bytes"] = int(entry["input_bytes"]) + int(rec["input_bytes"])
        entry["stream_bytes"] = int(entry["stream_bytes"]) + int(rec["stream_bytes"])
        entry["elapsed_ms"] = float(entry["elapsed_ms"]) + float(rec["elapsed_ms"])
    order = { "planned": 0, "parallel": 1, "thread_pool": 2, "work_queue": 3 }
    summaries = sorted(by_mode.values(), key=lambda item: order.get(str(item["mode"]), 99))
    for item in summaries:
        elapsed_s = float(item["elapsed_ms"]) / 1000.0
        mib = float(item["input_bytes"]) / (1024.0 * 1024.0)
        item["mib_s"] = 0.0 if elapsed_s == 0 else mib / elapsed_s
    return summaries


def main() -> int:
    if not EXE.exists():
        raise SystemExit(f"missing native parallel bench executable at {EXE}; run zig build first")
    full = "--full" in sys.argv[1:]
    standard_suite = "--standard-suite" in sys.argv[1:]
    markdown_path = None
    corpus_paths: list[pathlib.Path] = []
    source_paths: list[pathlib.Path] = []
    workers = "4"
    worker_values: list[str] = []
    for index, arg in enumerate(sys.argv):
        if arg == "--markdown" and index + 1 < len(sys.argv):
            markdown_path = pathlib.Path(sys.argv[index + 1])
        if arg == "--workers" and index + 1 < len(sys.argv):
            workers = sys.argv[index + 1]
        if arg == "--worker-sweep" and index + 1 < len(sys.argv):
            worker_values = [value for value in sys.argv[index + 1].split(",") if value]
        if arg == "--paths":
            for value in sys.argv[index + 1 :]:
                if value.startswith("--"):
                    break
                corpus_paths.append(pathlib.Path(value))
    block_len = "65536" if full else "8192"
    if corpus_paths:
        source_paths = corpus_paths
        cases = load_path_cases(corpus_paths, full)
    elif standard_suite:
        discovered = discover_standard_corpora()
        if not discovered:
            print("native parallel corpus report: no standard corpora discovered")
            return 0
        source_paths = discovered
        cases = load_path_cases(discovered, full)
    else:
        source_paths = [SILESIA]
        cases = load_default_cases(full)
    if not cases:
        print("native parallel corpus report: missing silesia-small.tar")
        return 0
    rows: list[str] = []
    if not worker_values:
        worker_values = [workers]
    print(HEADER)
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        for index, (label, data) in enumerate(cases):
            sample = root / f"case-{index:03d}.bin"
            sample.write_bytes(data)
            for worker_count in worker_values:
                out = subprocess.run([str(EXE), str(sample), block_len, worker_count], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip().splitlines()
                for line in out[1:]:
                    fields = line.split(",", 1)
                    row = f"{label},{fields[1]}"
                    rows.append(row)
                    print(row)
    if markdown_path is not None:
        write_markdown(rows, markdown_path, full, len(corpus_paths) != 0 or standard_suite, source_paths)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
