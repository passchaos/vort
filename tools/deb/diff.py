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
    parser.add_argument("--dpkg-deb", type=Path)
    args = parser.parse_args()
    dpkg_deb = args.dpkg_deb
    if dpkg_deb is None:
        found = shutil.which("dpkg-deb")
        dpkg_deb = Path(found) if found else None

    self_cases = 0
    external_read = 0
    external_write = 0
    malformed = 0
    payload = b"Vort Debian package payload\n" * 64

    with tempfile.TemporaryDirectory(prefix="vort-deb-diff-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.txt"
        source.write_bytes(payload)
        vort_deb = temp / "vort-test.deb"
        data_name = "usr/share/vort/payload.txt"
        run(
            args.cli,
            "create-deb-file",
            vort_deb,
            "vort-test",
            "1.0",
            data_name,
            source,
            "xz",
        )
        listing = run(args.cli, "list-deb-file", vort_deb).stdout
        if (
            "control_entries=1" not in listing
            or "data_entries=1" not in listing
            or "deb_control_compression=gzip" not in listing
            or "deb_data_compression=xz" not in listing
            or f"name={data_name}" not in listing
        ):
            raise AssertionError(f"Vort Debian writer metadata mismatch: {listing}")
        self_output = temp / "self.out"
        run(args.cli, "extract-deb-file", vort_deb, data_name, self_output, len(payload))
        if self_output.read_bytes() != payload:
            raise AssertionError("Vort Debian self extraction mismatch")
        self_cases += 1

        if dpkg_deb is not None:
            run(dpkg_deb, "--info", vort_deb)
            extracted = temp / "dpkg-extracted"
            run(dpkg_deb, "--extract", vort_deb, extracted)
            if (extracted / data_name).read_bytes() != payload:
                raise AssertionError("dpkg-deb rejected Vort package data")
            external_read += 1

            package_root = temp / "dpkg-source"
            control_dir = package_root / "DEBIAN"
            control_dir.mkdir(parents=True)
            (control_dir / "control").write_text(
                "Package: dpkg-vort-test\n"
                "Version: 1.0\n"
                "Architecture: all\n"
                "Maintainer: Vort\n"
                "Description: dpkg generated test\n"
            )
            dpkg_data = package_root / "usr/share/vort/payload.txt"
            dpkg_data.parent.mkdir(parents=True)
            dpkg_data.write_bytes(payload)
            dpkg_archive = temp / "dpkg-test.deb"
            run(dpkg_deb, "--build", package_root, dpkg_archive)
            dpkg_listing = run(args.cli, "list-deb-file", dpkg_archive).stdout
            listed_name = next(
                line.split(" name=", 1)[1]
                for line in dpkg_listing.splitlines()
                if line.startswith("index=") and line.endswith("payload.txt")
            )
            dpkg_output = temp / "dpkg.out"
            run(
                args.cli,
                "extract-deb-file",
                dpkg_archive,
                listed_name,
                dpkg_output,
                len(payload),
            )
            if dpkg_output.read_bytes() != payload:
                raise AssertionError("Vort rejected dpkg-deb package data")
            external_write += 1

        corrupt = bytearray(vort_deb.read_bytes())
        version_offset = corrupt.find(b"2.0\n")
        if version_offset < 0:
            raise AssertionError("could not locate debian-binary payload")
        corrupt[version_offset] = ord("3")
        corrupt_path = temp / "bad-version.deb"
        corrupt_path.write_bytes(corrupt)
        failed = run(args.cli, "list-deb-file", corrupt_path, check=False)
        if failed.returncode == 0 or "InvalidDebPackage" not in failed.stderr:
            raise AssertionError("Vort accepted an invalid debian-binary version")
        malformed += 1

    print(
        f"self_cases={self_cases} dpkg_deb={dpkg_deb is not None} "
        f"external_read={external_read} external_write={external_write} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
