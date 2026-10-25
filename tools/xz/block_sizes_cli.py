#!/usr/bin/env python3
"""Exercise XZ size flags through an already-built CLI; never compile or time."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
from block_sizes_diff import Reference, inspect, identity

ROOT = Path(__file__).resolve().parents[2]


def require(ok, detail):
    if not ok:
        raise AssertionError(detail)


def sources():
    return [identity(ROOT / name) for name in (
        "examples/cli.zig", "examples/lzma_cli_probe.zig", "examples/cli/xz.zig",
        "examples/cli/lzma_controls.zig", "examples/cli/lzma_controls_tests.zig",
        "examples/cli/lzma.zig", "examples/cli/microlzma.zig",
        "tools/xz/block_sizes_cli.py")]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--directory", required=True, type=Path)
    parser.add_argument("--reference", required=True, type=Path)
    parser.add_argument("--reference-headers", required=True, type=Path)
    args = parser.parse_args()
    cli, directory = args.cli.resolve(), args.directory.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    before = sources()
    reference = Reference(args.reference, args.reference_headers)
    payload = (b"XZ declared size CLI content; repeated metadata and safe output.\n" * 70)[:4099]
    source = directory / "input.bin"
    source.write_bytes(payload)
    cases = []
    for command in ("encode-xz-file", "encode-xz-stored-file"):
        for check in ("none", "crc32", "crc64", "sha256"):
            for enabled in (False, True):
                cases.append((command, [check, "1024"],
                              ["--block-sizes=" + str(enabled).lower()], enabled, None))
        cases.append((command, ["crc64", "1024"], [], False, None))
        cases.append((command, ["crc64", "1024"], ["--block-sizes"], True, None))
        for flags, error in (
            (["--block-sizes", "--block-sizes=false"], "DuplicateLzmaOption"),
            (["--block-sizes=false", "--block-sizes"], "DuplicateLzmaOption"),
            (["--block-sizes=yes"], "InvalidBoolean"),
            (["--block-sizes="], "MissingLzmaOptionValue"),
        ):
            cases.append((command, [], flags, None, error))
    for command in ("encode-lzma-file", "encode-microlzma-file"):
        for flag in ("--block-sizes", "--block-sizes=false"):
            cases.append((command, [], [flag], None, "UnsupportedXzBlockSizesOption"))
    results, failures = [], []
    for index, (command, positional, flags, enabled, error) in enumerate(cases):
        name = f"cli-{index:03d}"
        target = directory / (name + ".output")
        target.write_bytes(b"caller-output-must-survive")
        original = target.read_bytes()
        argv = [str(cli), command, str(source), str(target), *positional, *flags]
        process = subprocess.run(argv, capture_output=True, timeout=120, check=False)
        out, err = directory / (name + ".stdout"), directory / (name + ".stderr")
        out.write_bytes(process.stdout)
        err.write_bytes(process.stderr)
        row = {"command": argv, "exit_code": process.returncode,
               "stdout": identity(out), "stderr": identity(err), "expected_error": error}
        try:
            require(source.read_bytes() == payload, "caller input changed")
            if error:
                require(process.returncode != 0 and error.encode() in process.stderr,
                        ("exact rejected flag", argv, process.stderr.decode(errors="replace")))
                require(target.read_bytes() == original, "failed command published caller output")
                row["caller_output_preserved"] = True
            else:
                require(process.returncode == 0, process.stderr.decode(errors="replace"))
                wire = target.read_bytes()
                parsed = inspect(wire)
                require(parsed["decoded_bytes"] == len(payload) and parsed["block_count"] == 5,
                        "complete original input and block count")
                for block in parsed["blocks"]:
                    require(all(field["present"] == enabled for field in block["declared_sizes"]),
                            "CLI flag did not reach public XZ encoder")
                require(reference.decode(wire, payload)["complete_contents_verified"],
                        "independent reference content/consumption")
                row.update({"wire": identity(target), "declared_sizes": enabled,
                            "independent_wire": parsed, "full_reference_decode": True})
            row["status"] = "passed"
        except (AssertionError, OSError) as failure:
            row.update({"status": "failed", "failure": str(failure)})
            failures.append({"command": argv, "failure": str(failure)})
        results.append(row)
    report = {"schema": "vort.xz.block-sizes-cli.v1", "cli": identity(cli),
              "source_before": before, "sources_preserved": before == sources(),
              "reference": reference.describe(), "input": identity(source),
              "cases": len(results), "passed": sum(row["status"] == "passed" for row in results),
              "failures": failures, "results": results,
              "scope": "Actual public CLI module flags, complete content/consumption and rejected-output preservation; no timing measurement."}
    (directory / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"cases": report["cases"], "passed": report["passed"],
                      "failed": len(failures), "sources_preserved": report["sources_preserved"]}))
    require(not failures and report["sources_preserved"], "XZ size CLI gate failed")


if __name__ == "__main__":
    main()
