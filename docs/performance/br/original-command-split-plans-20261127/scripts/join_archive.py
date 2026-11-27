"""Reconstruct sealed archive parts without running a codec or benchmark."""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--envelope", default=str(Path(__file__).resolve().parents[1] / "archive-envelope.json"))
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    envelope_path = Path(args.envelope)
    envelope = json.loads(envelope_path.read_text())
    output = Path(args.output)
    if output.exists():
        raise ValueError("Refuse to overwrite an existing archive")
    full = hashlib.sha256()
    total = 0
    with output.open("wb") as target:
        for part in envelope["parts"]:
            digest = hashlib.sha256()
            size = 0
            with (envelope_path.parent / part["path"]).open("rb") as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(chunk)
                    full.update(chunk)
                    size += len(chunk)
                    target.write(chunk)
            if digest.hexdigest() != part["sha256"] or size != part["bytes"]:
                raise ValueError(f"Part identity mismatch: {part['path']}")
            total += size
    if full.hexdigest() != envelope["sha256"] or total != envelope["bytes"]:
        raise ValueError("Reconstructed archive identity mismatch")
    print(output)


if __name__ == "__main__":
    main()
