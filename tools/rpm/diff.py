#!/usr/bin/env python3
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path


def run(*args: object, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--7zz", dest="seven_zip", type=Path)
    args = parser.parse_args()
    seven_zip = args.seven_zip
    if seven_zip is None:
        found = shutil.which("7zz") or shutil.which("7z")
        seven_zip = Path(found) if found else None
    if args.fixture is None:
        print(f"fixture=False seven_zip={seven_zip is not None} entries=0 external=0 malformed=0")
        return

    entries = 0
    external = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-rpm-diff-") as temp_text:
        temp = Path(temp_text)
        listing = run(args.cli, "list-rpm-file", args.fixture).stdout
        if "payload_entries=" not in listing or "payload_compression=" not in listing:
            raise AssertionError(f"Vort RPM listing is incomplete: {listing}")
        entry_lines = [line for line in listing.splitlines() if line.startswith("index=")]
        entries = len(entry_lines)
        if entries == 0:
            raise AssertionError("Vort RPM parser found no payload entries")
        raw_cpio = temp / "vort.cpio"
        run(args.cli, "extract-rpm-payload", args.fixture, raw_cpio, 512 * 1024 * 1024)

        first_regular = next(
            line.split(" name=", 1)[1]
            for line in entry_lines
            if "kind=regular" in line and "size=0 " not in line
        )
        vort_member = temp / "vort-member.out"
        run(
            args.cli,
            "extract-rpm-file",
            args.fixture,
            first_regular,
            vort_member,
            512 * 1024 * 1024,
        )

        if seven_zip is not None:
            reference = temp / "7z-rpm"
            run(seven_zip, "x", "-y", f"-o{reference}", args.fixture)
            reference_cpio = next(reference.glob("*.cpio"))
            if reference_cpio.read_bytes() != raw_cpio.read_bytes():
                raise AssertionError("Vort RPM payload differs from 7-Zip output")
            extracted = temp / "7z-cpio"
            run(seven_zip, "x", "-y", f"-o{extracted}", reference_cpio, first_regular)
            reference_member = extracted.joinpath(*first_regular.removeprefix("./").split("/"))
            if reference_member.read_bytes() != vort_member.read_bytes():
                raise AssertionError(f"Vort RPM member differs from 7-Zip: {first_regular}")
            external += 1

        too_small = run(
            args.cli,
            "extract-rpm-payload",
            args.fixture,
            temp / "too-small.cpio",
            raw_cpio.stat().st_size - 1,
            check=False,
        )
        if too_small.returncode == 0 or "OutputLimitExceeded" not in too_small.stderr:
            raise AssertionError("Vort ignored the RPM payload output limit")
        malformed += 1

        original = bytearray(args.fixture.read_bytes())
        bad_magic = original.copy()
        bad_magic[0] ^= 1
        bad_magic_path = temp / "bad-magic.rpm"
        bad_magic_path.write_bytes(bad_magic)
        if run(args.cli, "list-rpm-file", bad_magic_path, check=False).returncode == 0:
            raise AssertionError("Vort accepted a corrupt RPM lead")
        malformed += 1

        bad_compressor = original.copy()
        compressor_offset = bad_compressor.find(b"zstd\0")
        if compressor_offset >= 0:
            bad_compressor[compressor_offset : compressor_offset + 4] = b"zzzz"
            bad_compressor_path = temp / "bad-compressor.rpm"
            bad_compressor_path.write_bytes(bad_compressor)
            failed = run(args.cli, "list-rpm-file", bad_compressor_path, check=False)
            if failed.returncode == 0 or "UnsupportedRpmPayload" not in failed.stderr:
                raise AssertionError("Vort accepted an unsupported RPM compressor")
            malformed += 1

    print(
        f"fixture=True seven_zip={seven_zip is not None} entries={entries} "
        f"external={external} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
