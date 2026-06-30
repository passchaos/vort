#!/usr/bin/env python3
import pathlib
import subprocess
import sys
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXE = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 and pathlib.Path(sys.argv[1]).exists() else ROOT / "zig-out" / "bin" / "vort-split-policy-report"
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
                label = f"{label}-128k"
            cases.append((label, data))
    return cases


def main() -> int:
    if not EXE.exists():
        raise SystemExit(f"missing split policy executable at {EXE}; run zig build first")
    full = "--full" in sys.argv[1:]
    all_cases = "--all" in sys.argv[1:]
    cases = load_cases(full)
    if not all_cases:
        cases = cases[:1]
    if not cases:
        print("split policy corpus report: missing silesia-small.tar")
        return 0
    print("case,level,input_bytes,one_shot_bytes,adaptive_bytes,delta_bytes,adaptive_ratio,roundtrip_crc32")
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        for index, (label, data) in enumerate(cases):
            sample = root / f"case-{index:03d}.bin"
            sample.write_bytes(data)
            out = subprocess.run([str(EXE), str(sample)], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip().splitlines()
            for line in out[1:]:
                fields = line.split(",", 1)
                print(f"{label},{fields[1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
