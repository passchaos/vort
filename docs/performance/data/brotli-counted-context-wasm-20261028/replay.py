"""Replay one frozen Wasm comparison and independently validate saved v2 traces."""
import argparse
import datetime
import hashlib
import importlib.util
import json
import lzma
from pathlib import Path
import shlex
import subprocess
import sys
import tarfile
import tempfile

sys.dont_write_bytecode = True


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify(package):
    for line in (package / "SHA256SUMS").read_text().splitlines():
        expected, name = line.split("  ", 1)
        assert digest((package / name).read_bytes()) == expected, name
    manifest = json.loads((package / "source-manifest.json").read_text())
    for archive, field in (("overlays.tar.xz", "overlays"),
                           ("base-references.tar.xz", "base_references")):
        entries = {entry["path"]: entry for entry in manifest[field]}
        with tarfile.open(package / "sources" / archive, "r:xz") as source:
            assert {member.name for member in source.getmembers()} == set(entries)
            for name, entry in entries.items():
                data = source.extractfile(name).read()
                assert len(data) == entry["bytes"] and digest(data) == entry["sha256"], name
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--cpus", default="0,1,3-9,11-15")
    args = parser.parse_args()
    package = Path(__file__).resolve().parent
    manifest = verify(package)
    evidence = json.loads((package / "evidence.json").read_text())
    output = args.output or Path(tempfile.mkdtemp(prefix="vort-br-counted-wasm-replay-"))
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        parser.error("--output must be empty")
    raw_module = lzma.decompress((package / "modules/candidate.wasm.xz").read_bytes())
    assert digest(raw_module) == evidence["candidate_wasm_sha256"]
    assert len(raw_module) == evidence["candidate_wasm_bytes"]
    candidate = output / "candidate.wasm"
    candidate.write_bytes(raw_module)
    baseline = package / "modules/baseline-ci.wasm.br"
    assert digest(baseline.read_bytes()) == evidence["compressed_baseline_sha256"]
    command = ["taskset", "-c", args.cpus, "node", str(package / "gates/wasm-gate.js"),
               str(baseline), str(candidate), str(output / "wires")]
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (output / "frozen-wasm.log").write_text(
        "$ " + shlex.join(command) + "\n" + result.stdout +
        "\nexit_code=" + str(result.returncode) + "\n")
    assert result.returncode == 0, result.stdout
    report = json.loads(next(line for line in result.stdout.splitlines() if line.startswith("{")))
    assert report["full_wire_equal"] is True
    for variant in ("baseline", "candidate"):
        for field, expected in evidence["expected_result"][variant].items():
            assert report[variant][field] == expected, (variant, field)
    for name in ("input.bin", "baseline.br", "candidate.br"):
        expected = lzma.decompress((package / "wires" / (name + ".xz")).read_bytes())
        assert (output / "wires" / name).read_bytes() == expected, name

    # Only relocate local input paths. Preserve the frozen JSON and all its
    # event, timing, executable-provenance, and wire-identity fields unchanged.
    profile = json.loads(lzma.decompress((package / "profiles/final-stage.json.xz").read_bytes()))
    inputs = json.loads((package / "profiles/input-manifest.json").read_text())
    relocated = {}
    (output / "trace-inputs").mkdir()
    for index, entry in enumerate(inputs):
        data = lzma.decompress((package / entry["archive_path"]).read_bytes())
        assert len(data) == entry["bytes"] and digest(data) == entry["sha256"]
        destination = output / "trace-inputs" / (str(index) + ".bin")
        destination.write_bytes(data)
        relocated[entry["original_path"]] = str(destination)
    for row in profile["rows"]:
        row["path"] = relocated[row["path"]]
    spec = importlib.util.spec_from_file_location("frozen_quality_profile_gate", package / "gates/quality_profile_gate.py")
    gate = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gate)
    profile_result = gate.validate(profile)
    assert profile_result["validated_runs"] == evidence["profile_validated_runs"]
    (output / "v2-profile-validation.json").write_text(json.dumps(profile_result, indent=2) + "\n")
    summary = {
        "replayed_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "output": str(output),
        "base_commit": manifest["base_commit"],
        "source_overlays_checked": len(manifest["overlays"]),
        "exit_codes": {"frozen_wasm_gate": result.returncode, "v2_profile_validation": 0},
        "wasm_result": report,
        "profile_validated_runs": profile_result["validated_runs"],
        "scope": "Frozen modules and full bytes replayed once; saved v2 traces independently validated. Source compilation and benchmark timing are outside this replay.",
    }
    (output / "replay-summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main()
