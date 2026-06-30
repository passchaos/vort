#!/usr/bin/env python3
import pathlib
import subprocess
import sys
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXE = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 and pathlib.Path(sys.argv[1]).exists() else ROOT / "zig-out" / "bin" / "vort-bench-native-parallel"
SILESIA = pathlib.Path.home() / "Work" / "zlib-rs" / "silesia-small.tar"
SMOKE_LIMIT = 128 * 1024
HEADER = "corpus,mode,input_bytes,stream_bytes,elapsed_ms,range_offset,range_len,range_crc32"
COLS = HEADER.split(",")


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
                label = f"{label}-128k"
            cases.append((label, data))
    return cases


def row_to_dict(row: str) -> dict[str, str]:
    return dict(zip(COLS, row.split(",")))


def write_markdown(rows: list[str], path: pathlib.Path, full: bool) -> None:
    records = [row_to_dict(row) for row in rows]
    lines = [
        "# Native parallel Silesia benchmark",
        "",
        f"- mode: `{'full' if full else 'bounded-128KiB'}`",
        f"- rows: {len(records)}",
        "",
        "| corpus | mode | input | stream bytes | elapsed ms | range crc32 |",
        "| --- | --- | ---: | ---: | ---: | ---: |",
    ]
    for rec in records:
        lines.append("| {corpus} | {mode} | {input_bytes} | {stream_bytes} | {elapsed_ms} | {range_crc32} |".format(**rec))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    if not EXE.exists():
        raise SystemExit(f"missing native parallel bench executable at {EXE}; run zig build first")
    full = "--full" in sys.argv[1:]
    markdown_path = None
    for index, arg in enumerate(sys.argv):
        if arg == "--markdown" and index + 1 < len(sys.argv):
            markdown_path = pathlib.Path(sys.argv[index + 1])
    block_len = "65536" if full else "8192"
    cases = load_cases(full)
    if not cases:
        print("native parallel corpus report: missing silesia-small.tar")
        return 0
    rows: list[str] = []
    print(HEADER)
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        for index, (label, data) in enumerate(cases):
            sample = root / f"case-{index:03d}.bin"
            sample.write_bytes(data)
            out = subprocess.run([str(EXE), str(sample), block_len], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip().splitlines()
            for line in out[1:]:
                fields = line.split(",", 1)
                row = f"{label},{fields[1]}"
                rows.append(row)
                print(row)
    if markdown_path is not None:
        write_markdown(rows, markdown_path, full)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
