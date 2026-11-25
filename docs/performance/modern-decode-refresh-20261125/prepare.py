"""Prepare a new decode epoch from validated, already-produced Silesia wires.

Run with PYTHONPATH pointing at tools/decode in the measured Vort checkout.
"""
import argparse
import json
from functools import lru_cache
from pathlib import Path
import subprocess

from evidence import require, validate_manifest
from fixtures import sha256
from matrix import ROOT, environment, source_state, verify_references, write_json


@lru_cache(None)
def verified_file(path, digest, length=None):
    require(path.is_file(), f"Missing pinned file: {path}")
    if length is not None:
        require(path.stat().st_size == length, f"Wrong size: {path}")
    require(sha256(path) == digest, f"SHA-256 mismatch: {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--references", type=Path, required=True)
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    opts = parser.parse_args()
    output = opts.output.resolve()
    require(not (output / "manifest.json").exists(), "Refusing to overwrite a frozen epoch")
    status = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)
    require(not status, "The measured worktree must be clean")
    manifest = json.loads(opts.template.read_text())
    validate_manifest(manifest)

    references = manifest["references"]
    for codec, reference in references.items():
        pinned = reference.pop("file_sha256")
        roles = ("encoder", "decoder", "common") if codec == "brotli" else ("path",)
        for role in roles:
            original = Path(reference[role])
            candidate = (opts.references / codec / original.name).resolve()
            verified_file(candidate, pinned[str(original)])
            reference[role] = str(candidate)
    verify_references(references)

    for fixture in manifest["fixtures"]:
        for key, hash_key, length_key in (
            ("input_path", "input_sha256", "input_bytes"),
            ("encoded_input_path", "encoded_sha256", "encoded_bytes"),
        ):
            path = (opts.fixtures / Path(fixture[key]).name).resolve()
            verified_file(path, fixture[hash_key], fixture[length_key])
            fixture[key] = str(path)
        if fixture["size"] == "full":
            verified_file((opts.corpus / fixture["name"]).resolve(), fixture["input_sha256"], fixture["input_bytes"])
    by_key = {fixture["key"]: fixture for fixture in manifest["fixtures"]}
    for task in manifest["tasks"]:
        task["fixture"] = by_key[task["fixture"]["key"]]

    probe = opts.probe.resolve()
    manifest.update(source=source_state(), probe=str(probe), probe_sha256=sha256(probe),
                    environment=environment(manifest["config"]["cpu"]))
    validate_manifest(manifest)
    output.mkdir(parents=True, exist_ok=True)
    write_json(output / "references.json", references)
    write_json(output / "manifest.json", manifest)
    print(f"Verified {len(by_key)} fixtures, {len(manifest['tasks'])} tasks, and {len(references)} reference families")
    print(f"Source registry {manifest['source']['digest']}; probe {manifest['probe_sha256']}")


if __name__ == "__main__":
    main()
