#!/usr/bin/env python3
"""ARJ methods 0-4 interoperability against ARJ and 7-Zip."""

from __future__ import annotations

import argparse
import base64
import hashlib
import random
import shutil
import subprocess
import tempfile
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
ARJ_TESTDATA = REPOSITORY / "src" / "arj" / "testdata"


def decode_fixture(name: str, output: Path, expected_sha256: str) -> None:
    encoded = (ARJ_TESTDATA / name).read_text(encoding="ascii")
    data = base64.b64decode("".join(encoded.split()), validate=True)
    actual_sha256 = hashlib.sha256(data).hexdigest()
    if actual_sha256 != expected_sha256:
        raise AssertionError(
            f"ARJ fixture digest mismatch for {name}: {actual_sha256}"
        )
    output.write_bytes(data)


def run(
    program: Path | str, *args: str, check: bool = True
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(program), *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def make_payload() -> bytes:
    rng = random.Random(0xA4F40001)
    prefix = bytes(rng.randrange(256) for _ in range(40_000))
    return prefix + b"ARJ interoperability payload\n" * 512 + prefix


def seven_zip_extract(tool: str, archive: Path, name: str) -> bytes:
    return subprocess.run(
        [tool, "x", "-so", "-bd", str(archive), name],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--seven-zip", type=Path)
    parser.add_argument("--arj", type=Path)
    parser.add_argument("--unarc", type=Path)
    parser.add_argument("--fixtures", type=Path)
    args = parser.parse_args()
    seven_zip = (
        str(args.seven_zip)
        if args.seven_zip
        else shutil.which("7zz") or shutil.which("7z")
    )
    arj_tool = str(args.arj) if args.arj else shutil.which("arj")
    unarc = str(args.unarc) if args.unarc else shutil.which("unarc")
    payload = make_payload()
    writer_7zip = 0
    writer_arj = 0
    writer_encrypted = 0
    writer_encrypted_arj = 0
    writer_encrypted_unarc = 0
    writer_volumes = 0
    writer_volumes_arj = 0
    writer_volumes_unarc = 0
    reader_fixtures = 0
    reader_encrypted = 0
    reader_multivolume = 0

    with tempfile.TemporaryDirectory(prefix="vort-arj-diff-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.bin"
        source.write_bytes(payload)
        methods = ("stored", "method1", "method2", "method3", "method4")
        for method in methods:
            first = temp / f"vort-{method}-first.arj"
            second = temp / f"vort-{method}-second.arj"
            output = temp / f"vort-{method}.out"
            run(args.cli, "create-arj-file", str(first), "payload.bin", str(source), method)
            run(args.cli, "create-arj-file", str(second), "payload.bin", str(source), method)
            if first.read_bytes() != second.read_bytes():
                raise AssertionError(f"Vort ARJ {method} output is not deterministic")
            listing = run(args.cli, "list-arj-file", str(first)).stdout
            expected_method = "stored" if method == "stored" else method.replace("method", "method_")
            if f"method={expected_method}" not in listing:
                raise AssertionError(f"Vort ARJ listing mislabeled {method}: {listing}")
            run(
                args.cli,
                "extract-arj-file",
                str(first),
                "payload.bin",
                str(output),
                str(len(payload)),
            )
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort ARJ {method} self-extraction mismatch")
            if seven_zip is not None:
                if seven_zip_extract(seven_zip, first, "payload.bin") != payload:
                    raise AssertionError(f"7-Zip could not decode Vort ARJ {method}")
                writer_7zip += 1
            if arj_tool is not None:
                tested = subprocess.run(
                    [arj_tool, "t", str(first), "-i", "-y"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                if tested.returncode != 0:
                    raise AssertionError(f"ARJ rejected Vort {method}: {tested.stdout!r}")
                writer_arj += 1

        encrypted_first = temp / "vort-garble-first.arj"
        encrypted_second = temp / "vort-garble-second.arj"
        encrypted_output = temp / "vort-garble.out"
        encrypted_password = "secret"
        for archive_path in (encrypted_first, encrypted_second):
            run(
                args.cli,
                "create-arj-file",
                str(archive_path),
                "payload.bin",
                str(source),
                "method1",
                encrypted_password,
                "a7",
            )
        if encrypted_first.read_bytes() != encrypted_second.read_bytes():
            raise AssertionError("Vort Garble ARJ output is not deterministic")
        encrypted_listing = run(
            args.cli,
            "list-arj-file",
            str(encrypted_first),
        ).stdout
        if "encryption=garble" not in encrypted_listing or "modifier=167" not in encrypted_listing:
            raise AssertionError(f"Vort Garble ARJ listing mismatch: {encrypted_listing}")
        missing_password = run(
            args.cli,
            "extract-arj-file",
            str(encrypted_first),
            "payload.bin",
            str(temp / "vort-garble-missing.out"),
            str(len(payload)),
            check=False,
        )
        if missing_password.returncode == 0 or "EncryptedArjEntry" not in missing_password.stderr:
            raise AssertionError("Vort accepted Garble ARJ data without a password")
        run(
            args.cli,
            "extract-arj-file",
            str(encrypted_first),
            "payload.bin",
            str(encrypted_output),
            str(len(payload)),
            encrypted_password,
        )
        if encrypted_output.read_bytes() != payload:
            raise AssertionError("Vort Garble ARJ self-extraction mismatch")
        writer_encrypted = 1
        if arj_tool is not None:
            tested = subprocess.run(
                [
                    arj_tool,
                    "t",
                    str(encrypted_first),
                    f"-g{encrypted_password}",
                    "-i",
                    "-y",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            if tested.returncode != 0:
                raise AssertionError(
                    f"ARJ rejected Vort Garble output: {tested.stdout!r}"
                )
            writer_encrypted_arj = 1
        if unarc is not None:
            unarc_output = temp / "unarc-vort-garble"
            run(
                unarc,
                "extract",
                str(encrypted_first),
                "payload.bin",
                "--output",
                str(unarc_output),
                "--password",
                encrypted_password,
                "--force",
            )
            if (unarc_output / "payload.bin").read_bytes() != payload:
                raise AssertionError("unarc-rs rejected Vort Garble ARJ output")
            writer_encrypted_unarc = 1

        volume_prefix = temp / "vort-volume"
        run(
            args.cli,
            "create-arj-volumes",
            str(volume_prefix),
            "payload.bin",
            str(source),
            "4096",
            "method1",
            encrypted_password,
            "40",
        )
        writer_volumes_paths = (volume_prefix.with_suffix(".arj"),) + tuple(
            sorted(temp.glob("vort-volume.a[0-9][0-9]"))
        )
        if len(writer_volumes_paths) < 2:
            raise AssertionError("Vort ARJ volume writer did not split")
        volume_output = temp / "vort-volume.out"
        run(
            args.cli,
            "extract-arj-volumes",
            "payload.bin",
            str(volume_output),
            str(len(payload)),
            encrypted_password,
            *(str(path) for path in writer_volumes_paths),
        )
        if volume_output.read_bytes() != payload:
            raise AssertionError("Vort ARJ volume round trip mismatch")
        writer_volumes = 1
        if arj_tool is not None:
            tested = subprocess.run(
                [
                    arj_tool,
                    "t",
                    str(writer_volumes_paths[0]),
                    f"-g{encrypted_password}",
                    "-i",
                    "-y",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            if tested.returncode != 0:
                raise AssertionError(
                    f"ARJ rejected Vort volume set: {tested.stdout!r}"
                )
            writer_volumes_arj = 1
        if unarc is not None:
            unarc_volume_output = temp / "unarc-vort-volume"
            run(
                unarc,
                "extract",
                str(writer_volumes_paths[0]),
                "payload.bin",
                "--output",
                str(unarc_volume_output),
                "--password",
                encrypted_password,
                "--force",
            )
            if (unarc_volume_output / "payload.bin").read_bytes() != payload:
                raise AssertionError("unarc-rs rejected Vort ARJ volume set")
            writer_volumes_unarc = 1

        encrypted = temp / "unarc-rs-license-garble.arj"
        decode_fixture(
            "unarc-rs-license-garble.arj.b64",
            encrypted,
            "29b1c579452f5b6ef2c731be8c3be4d788926a1fbf5691f9b1940d895ffcfe65",
        )
        encrypted_listing = run(args.cli, "list-arj-file", str(encrypted)).stdout
        if "encryption=garble" not in encrypted_listing:
            raise AssertionError("Vort failed to report ARJ encryption")
        encrypted_fixture_output = temp / "encrypted-fixture.out"
        run(
            args.cli,
            "extract-arj-file",
            str(encrypted),
            "LICENSE",
            str(encrypted_fixture_output),
            str(1024 * 1024),
            "secret",
        )
        if hashlib.sha256(encrypted_fixture_output.read_bytes()).hexdigest() != (
            "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4"
        ):
            raise AssertionError("Vort Garble ARJ fixture payload digest mismatch")
        reader_encrypted = 1

        multi_names_and_digests = (
            (
                "unarc-rs-multi-test_file.arj.b64",
                "f33c9bea36e8b6fd7ebf7f8c144c0bf542528af3e3ef86ee08e69815fd98a404",
            ),
            (
                "unarc-rs-multi-test_file.a01.b64",
                "80c1a51a509eddc9296a904be1f89f0b150aa7d5eb0ff8baa425fda61e552bf6",
            ),
            (
                "unarc-rs-multi-test_file.a02.b64",
                "caf74286c0b424e38ac7bc03d4176d103ae9e394efcb70372c8898b7d0525f70",
            ),
        )
        multi_paths = tuple(
            temp
            / (
                "fixture-multi.arj"
                if index == 0
                else f"fixture-multi.a{index:02d}"
            )
            for index in range(len(multi_names_and_digests))
        )
        for (name, digest), path in zip(multi_names_and_digests, multi_paths):
            decode_fixture(name, path, digest)
        multi_listing = run(args.cli, "list-arj-file", str(multi_paths[0])).stdout
        if "name=TEST.ICY" not in multi_listing:
            raise AssertionError("Vort failed to list the ARJ multi-volume entry")
        multi_extract = run(
            args.cli,
            "extract-arj-file",
            str(multi_paths[0]),
            "TEST.ICY",
            str(temp / "multi-incomplete.out"),
            check=False,
        )
        if multi_extract.returncode == 0:
            raise AssertionError("Vort accepted incomplete ARJ multi-volume data")
        multi_output = temp / "multi-complete.out"
        run(
            args.cli,
            "extract-arj-volumes",
            "TEST.ICY",
            str(multi_output),
            str(1024 * 1024),
            "-",
            *(str(path) for path in multi_paths),
        )
        multi_payload = multi_output.read_bytes()
        if (
            len(multi_payload) != 29813
            or hashlib.sha256(multi_payload).hexdigest()
            != "be8a087b4563b116bd79d2f8b1f0544c2709a70c4787e05a57b7e11ec33a7f74"
        ):
            raise AssertionError("Vort ARJ volume fixture payload mismatch")
        reader_multivolume = 1

        if args.fixtures is not None:
            for method in ("stored", "method1", "method2", "method3", "method4"):
                fixture = args.fixtures / f"{method}.arj"
                if not fixture.is_file():
                    raise AssertionError(f"missing ARJ fixture: {fixture}")
                listing = run(args.cli, "list-arj-file", str(fixture)).stdout
                expected_method = (
                    "stored"
                    if method == "stored"
                    else method.replace("method", "method_")
                )
                if f"method={expected_method}" not in listing:
                    raise AssertionError(f"Vort misparsed {fixture.name}: {listing}")
                output = temp / f"fixture-{method}.out"
                run(
                    args.cli,
                    "extract-arj-file",
                    str(fixture),
                    "LICENSE",
                    str(output),
                    str(1024 * 1024),
                )
                if seven_zip is not None:
                    expected = seven_zip_extract(seven_zip, fixture, "LICENSE")
                    if output.read_bytes() != expected:
                        raise AssertionError(f"Vort fixture extraction mismatch for {fixture}")
                reader_fixtures += 1

            wrong_crc = args.fixtures / "wrongcrc32.arj"
            failed = run(
                args.cli,
                "extract-arj-file",
                str(wrong_crc),
                "LICENSE",
                str(temp / "wrong-crc.out"),
                check=False,
            )
            if failed.returncode == 0:
                raise AssertionError("Vort accepted an ARJ entry with a bad data CRC")

    print(
        "arj_diff=ok methods=5 self_writer_cases=5 "
        f"seven_zip={seven_zip is not None} writer_7zip={writer_7zip} "
        f"arj={arj_tool is not None} writer_arj={writer_arj} "
        f"unarc={unarc is not None} writer_encrypted={writer_encrypted} "
        f"writer_encrypted_arj={writer_encrypted_arj} "
        f"writer_encrypted_unarc={writer_encrypted_unarc} "
        f"writer_volumes={writer_volumes} writer_volumes_arj={writer_volumes_arj} "
        f"writer_volumes_unarc={writer_volumes_unarc} "
        f"reader_fixtures={reader_fixtures} reader_encrypted={reader_encrypted} "
        f"reader_multivolume={reader_multivolume} "
        "corrupt_crc=True encrypted=True multivolume=True"
    )


if __name__ == "__main__":
    main()
