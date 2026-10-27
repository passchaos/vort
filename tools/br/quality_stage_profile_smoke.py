#!/usr/bin/env python3
"""Check q8 profile aliases and exact evaluated-candidate emission reports."""
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
        assert report["schema"] == "vort.brotli.q8-candidate-profile.v2"
        profile = report["rows"][0]["rounds"][0]["profile"]
        assert "evaluation_attempts" in profile and "evaluate" in profile["exclusive_ns"]
        gate = validate(report, executable)
        assert gate["validated_runs"] == 1 and source.read_bytes() == contents
        cases.append({"case": "separate_output", "accepted": True, "input_preserved": True,
                      "timing_and_identity_validated": True})
        evaluated_source = root / "evaluated-input.bin"
        state = 0x243F6A88
        letters = bytearray()
        for _ in range(6000):
            state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
            letters.append(97 + ((state >> 24) % 26))
        evaluated_contents = b"".join(
            b'{"index":%d,"value":"%s","kind":"generic"}\n' %
            (index, letters[index * 24:(index + 1) * 24])
            for index in range(250))
        evaluated_source.write_bytes(evaluated_contents)
        evaluated_output = root / "evaluated-report.json"
        result = subprocess.run([str(executable), "--rounds", "1", "--path", str(evaluated_source),
                                 "--json", str(evaluated_output)], capture_output=True)
        assert result.returncode == 0, result.stderr
        evaluated_report = json.loads(evaluated_output.read_text())
        assert evaluated_report["schema"] == "vort.brotli.q8-candidate-profile.v2"
        gate = validate(evaluated_report, executable)
        profile = evaluated_report["rows"][0]["rounds"][0]["profile"]
        assert gate["validated_runs"] == 1 and profile["evaluation_attempts"] > 0
        emissions = [event for event in profile["events"]
                     if event["stage"] == "wire" and event["evaluation_event_id"] is not None]
        assert emissions and evaluated_source.read_bytes() == evaluated_contents
        returned = next(event for event in profile["events"]
                        if event["id"] == profile["returned_wire_event_id"])
        assert returned["stage"] == "wire"
        cases.append({"case": "evaluated_candidates", "accepted": True, "input_preserved": True,
                      "evaluation_attempts": profile["evaluation_attempts"],
                      "linked_emissions": len(emissions), "returned_real_wire": True,
                      "timing_and_identity_validated": True})
    return {"executable_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(), "cases": cases,
            "scope": "Isolated temporary file aliases, a tiny input report, and deterministic JSON candidate evaluation/emission links; no benchmark timing claim."}


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
