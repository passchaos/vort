#!/usr/bin/env python3
import pathlib
import subprocess
import sys
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXE = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 and pathlib.Path(sys.argv[1]).exists() else ROOT / "zig-out" / "bin" / "vort-dictionary-report"
SILESIA = pathlib.Path.home() / "Work" / "zlib-rs" / "silesia-small.tar"
SMOKE_LIMIT = 32 * 1024


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
        print(subprocess.run([str(EXE), *paths], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
