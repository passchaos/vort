#!/usr/bin/env python3
"""Check q8 profile file ownership and equivalent input/output aliases."""
import argparse
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path
from quality_profile_gate import validate


def run(executable: Path) -> dict:
    cases = []
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        source = root / "input.bin"
        contents = b"tiny"
        source.write_bytes(contents)
        symlink = root / "input-symbolic.bin"
        symlink.symlink_to(source.name)
        hardlink = root / "input-hard.bin"
        os.link(source, hardlink)
        for name, output in [("same", source), ("spelling", root / "sub/../input.bin"),
                             ("symlink", symlink), ("hardlink", hardlink)]:
            (root / "sub").mkdir(exist_ok=True)
            command = [str(executable), "--rounds", "1", "--path", str(source), "--json", str(output)]
            result = subprocess.run(command, capture_output=True)
            assert result.returncode != 0 and b"OutputPathCollision" in result.stderr, (name, result.stderr)
            assert source.read_bytes() == contents
            cases.append({"case": name, "rejected": True, "input_preserved": True})
        output = root / "report.json"
        result = subprocess.run([str(executable), "--rounds", "1", "--path", str(source), "--json", str(output)], capture_output=True)
        assert result.returncode == 0, result.stderr
        report = json.loads(output.read_text())
        gate = validate(report, executable)
        assert gate["validated_runs"] == 1 and source.read_bytes() == contents
        cases.append({"case": "separate_output", "accepted": True, "input_preserved": True,
                      "timing_and_identity_validated": True})
    return {"executable_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(), "cases": cases,
            "scope": "Isolated temporary file aliases and one tiny input report; no benchmark timing claim."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = run(args.executable.resolve())
    text = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(text)
    else:
        print(text, end="")


if __name__ == "__main__":
    main()
