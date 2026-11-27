"""Verify assembled artifact bytes only after Root releases archival I/O."""
import argparse
import hashlib
from pathlib import Path
from common import PACKAGE, read_json, require_release, validate_release


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", help="Original-host release; extracted payload can use its sealed inline release")
    default = PACKAGE / "manifest.json" if (PACKAGE / "manifest.json").exists() else PACKAGE / "data/manifest.json"
    parser.add_argument("--manifest", default=str(default))
    args = parser.parse_args()
    path = Path(args.manifest)
    manifest = read_json(path)
    if manifest["schema"] != "vort.original-command-split-plans.portable-manifest.v1":
        raise ValueError("Unexpected assembled manifest schema")
    if manifest.get("phase") != "assembled-after-root-release":
        raise ValueError("Package was not assembled after Root release")
    if args.release:
        require_release(args.release)
    else:
        release = validate_release(manifest["release"], require_original_record=False)
        if not any(row["origin_path"] == release["final_verdict"]["record"] for row in manifest["artifacts"]):
            raise ValueError("Inline release lacks an archived final verdict artifact")
    for row in manifest["artifacts"]:
        artifact = (path.parent / row["logical_path"]).resolve()
        if not artifact.is_relative_to(path.parent.resolve()):
            raise ValueError("Artifact escapes package")
        digest = hashlib.sha256()
        with artifact.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        if digest.hexdigest() != row["sha256"] or artifact.stat().st_size != row["bytes"]:
            raise ValueError(f"Artifact identity mismatch: {row['logical_path']}")
    if manifest["source_scope_proof"]["source_trees_byte_identical"]:
        raise ValueError("Distinct source epochs were mislabeled identical")
    print(f"Verified {len(manifest['artifacts'])} archived artifact identities")


if __name__ == "__main__":
    main()
