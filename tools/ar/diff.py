#!/usr/bin/env python3
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path


def run(*args: object, cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(arg) for arg in args],
        cwd=cwd,
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", required=True, type=Path)
    parser.add_argument("--ar", dest="ar_tool", type=Path)
    args = parser.parse_args()
    ar_tool = args.ar_tool
    if ar_tool is None:
        found = shutil.which("ar")
        ar_tool = Path(found) if found else None

    expected = {
        "short.txt": b"short ar payload\n",
        "very-long-member-name-for-vort.txt": b"long ar payload\n",
        "odd.bin": bytes(range(5)),
    }
    self_cases = 0
    external_read = 0
    external_write = 0
    malformed = 0

    with tempfile.TemporaryDirectory(prefix="vort-ar-diff-") as temp_text:
        temp = Path(temp_text)
        vort_archive = temp / "vort.a"
        run(args.writer, vort_archive)
        listing = run(args.cli, "list-ar-file", vort_archive).stdout
        if "ar_entries=3" not in listing:
            raise AssertionError(f"Vort ar writer count mismatch: {listing}")
        for index, (name, data) in enumerate(expected.items()):
            if f"name={name}" not in listing:
                raise AssertionError(f"Vort ar writer omitted {name}: {listing}")
            output = temp / f"self-{index}.out"
            run(args.cli, "extract-ar-file", vort_archive, name, output, len(data))
            if output.read_bytes() != data:
                raise AssertionError(f"Vort ar self extraction mismatch: {name}")
            self_cases += 1

        if ar_tool is not None:
            names = tuple(line for line in run(ar_tool, "t", vort_archive).stdout.splitlines() if line)
            if names != tuple(expected):
                raise AssertionError(f"GNU ar rejected Vort member names: {names}")
            extracted = temp / "gnu-extracted"
            extracted.mkdir()
            run(ar_tool, "x", vort_archive, cwd=extracted)
            for name, data in expected.items():
                if (extracted / name).read_bytes() != data:
                    raise AssertionError(f"GNU ar rejected Vort data: {name}")
                external_read += 1

            source = temp / "gnu-source"
            source.mkdir()
            for name, data in expected.items():
                (source / name).write_bytes(data)
            gnu_archive = temp / "gnu.a"
            run(ar_tool, "rcs", gnu_archive, *expected.keys(), cwd=source)
            gnu_listing = run(args.cli, "list-ar-file", gnu_archive).stdout
            if "ar_entries=3" not in gnu_listing:
                raise AssertionError(f"Vort rejected GNU ar members: {gnu_listing}")
            for index, (name, data) in enumerate(expected.items()):
                output = temp / f"gnu-{index}.out"
                run(args.cli, "extract-ar-file", gnu_archive, name, output, len(data))
                if output.read_bytes() != data:
                    raise AssertionError(f"Vort rejected GNU ar data: {name}")
                external_write += 1

            thin_archive = temp / "thin.a"
            run(ar_tool, "rcT", thin_archive, "short.txt", cwd=source)
            failed = run(args.cli, "list-ar-file", thin_archive, check=False)
            if failed.returncode == 0 or "UnsupportedArFeature" not in failed.stderr:
                raise AssertionError("Vort accepted a thin ar archive as self-contained")
            malformed += 1

        corrupt = bytearray(vort_archive.read_bytes())
        corrupt[8 + 58] ^= 1
        corrupt_path = temp / "corrupt.a"
        corrupt_path.write_bytes(corrupt)
        if run(args.cli, "list-ar-file", corrupt_path, check=False).returncode == 0:
            raise AssertionError("Vort accepted a corrupt ar header trailer")
        malformed += 1

    print(
        f"self_cases={self_cases} ar_tool={ar_tool is not None} "
        f"external_read={external_read} external_write={external_write} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
