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
    entries = 0
    external = 0
    malformed = 0
    writer_cases = 0
    writer_external = 0
    with tempfile.TemporaryDirectory(prefix="vort-rpm-diff-") as temp_text:
        temp = Path(temp_text)
        writer_source = temp / "writer-source.bin"
        writer_payload = b"Vort RPM writer payload\n" * 128
        writer_source.write_bytes(writer_payload)
        writer_name = "usr/share/vort/payload.txt"
        first_writer_archive: Path | None = None
        for index, compression in enumerate(
            ("none", "gzip", "bzip2", "lzma", "xz", "zstd")
        ):
            archive = temp / f"vort-writer-{compression}.rpm"
            run(
                args.cli,
                "create-rpm-file",
                archive,
                "vort-test",
                "1.0",
                writer_name,
                writer_source,
                compression,
            )
            if first_writer_archive is None:
                first_writer_archive = archive
            writer_listing = run(args.cli, "list-rpm-file", archive).stdout
            if (
                "rpm_name=vort-test" not in writer_listing
                or "md5=true" not in writer_listing
                or "sha1=true" not in writer_listing
                or "sha256=true" not in writer_listing
                or f"name={writer_name}" not in writer_listing
            ):
                raise AssertionError(
                    f"Vort RPM {compression} writer metadata mismatch: {writer_listing}"
                )
            output = temp / f"writer-{compression}.out"
            run(
                args.cli,
                "extract-rpm-file",
                archive,
                writer_name,
                output,
                len(writer_payload),
            )
            if output.read_bytes() != writer_payload:
                raise AssertionError(f"Vort RPM {compression} writer self mismatch")
            writer_cases += 1
            if seven_zip is not None:
                run(seven_zip, "t", archive)
                reference = temp / f"writer-7z-{compression}"
                run(seven_zip, "x", "-y", f"-o{reference}", archive)
                vort_cpio = temp / f"writer-{compression}.cpio"
                run(args.cli, "extract-rpm-payload", archive, vort_cpio, 64 * 1024 * 1024)
                reference_cpio = next(reference.glob("*.cpio"), None)
                if reference_cpio is not None:
                    if reference_cpio.read_bytes() != vort_cpio.read_bytes():
                        raise AssertionError(
                            f"7-Zip rejected Vort RPM {compression} payload"
                        )
                elif (reference / writer_name).read_bytes() != writer_payload:
                    raise AssertionError(
                        f"7-Zip rejected Vort RPM {compression} member"
                    )
                writer_external += 1

        if first_writer_archive is None:
            raise AssertionError("RPM writer matrix was empty")
        duplicate = temp / "vort-writer-duplicate.rpm"
        run(
            args.cli,
            "create-rpm-file",
            duplicate,
            "vort-test",
            "1.0",
            writer_name,
            writer_source,
            "none",
        )
        if duplicate.read_bytes() != first_writer_archive.read_bytes():
            raise AssertionError("Vort RPM writer output is not deterministic")

        corrupt_writer = bytearray(first_writer_archive.read_bytes())
        corrupt_writer[-1] ^= 1
        corrupt_writer_path = temp / "writer-bad-digest.rpm"
        corrupt_writer_path.write_bytes(corrupt_writer)
        failed = run(args.cli, "list-rpm-file", corrupt_writer_path, check=False)
        if failed.returncode == 0 or "RpmDigestMismatch" not in failed.stderr:
            raise AssertionError("Vort accepted a corrupt RPM writer digest")
        malformed += 1

        if args.fixture is None:
            print(
                f"fixture=False seven_zip={seven_zip is not None} entries=0 "
                f"external=0 writer_cases={writer_cases} "
                f"writer_external={writer_external} malformed={malformed}"
            )
            return

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
        f"external={external} writer_cases={writer_cases} "
        f"writer_external={writer_external} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
