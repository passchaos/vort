"""Restore the pinned Git base plus verified counted-context source overlays."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile


def extract(archive, output):
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:*") as source:
        for member in source.getmembers():
            destination = (output / member.name).resolve()
            assert output.resolve() in destination.parents, member.name
            if member.isdir():
                destination.mkdir(parents=True, exist_ok=True)
                continue
            assert member.isfile(), member.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(source.extractfile(member).read())


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--repo", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
package = Path(__file__).resolve().parent
manifest = json.loads((package / "source-manifest.json").read_text())
for line in (package / "SHA256SUMS").read_text().splitlines():
    expected, name = line.split("  ", 1)
    assert hashlib.sha256((package / name).read_bytes()).hexdigest() == expected, name
args.output.mkdir(parents=True, exist_ok=True)
if any(args.output.iterdir()):
    parser.error("--output must be empty")
base = subprocess.check_output(["git", "-C", str(args.repo), "archive", manifest["base_commit"],
                                "--", "src", "tools", "build.zig", "build.zig.zon"])
extract(base, args.output)
extract((package / "sources/overlays.tar.xz").read_bytes(), args.output)
for entry in manifest["base_references"] + manifest["overlays"]:
    data = (args.output / entry["path"]).read_bytes()
    assert len(data) == entry["bytes"] and hashlib.sha256(data).hexdigest() == entry["sha256"], entry["path"]
print(json.dumps({"base_commit": manifest["base_commit"], "output": str(args.output),
                  "overlays_checked": len(manifest["overlays"]), "exit_code": 0}, sort_keys=True))
