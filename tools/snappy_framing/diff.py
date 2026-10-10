#!/usr/bin/env python3
import argparse
import os
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
    parser.add_argument("--snappy-java", type=Path)
    parser.add_argument("--java", type=Path)
    parser.add_argument("--javac", type=Path)
    args = parser.parse_args()
    java = args.java or (Path(found) if (found := shutil.which("java")) else None)
    javac = args.javac or (Path(found) if (found := shutil.which("javac")) else None)
    helper_source = Path(__file__).with_name("SnappyInterop.java")

    payload = bytes((index * 29 + index // 17) & 0xFF for index in range(700_000))
    self_cases = 0
    java_cases = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-snappy-framing-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.bin"
        source.write_bytes(payload)
        for kind in ("xerial", "hadoop"):
            first = temp / f"vort-{kind}-first.snappy"
            second = temp / f"vort-{kind}-second.snappy"
            encode_command = f"encode-{kind}-snappy-file"
            decode_command = f"decode-{kind}-snappy-file"
            inspect_command = f"inspect-{kind}-snappy-file"
            for output in (first, second):
                run(args.cli, encode_command, source, output)
            if first.read_bytes() != second.read_bytes():
                raise AssertionError(f"Vort {kind} Snappy output is not deterministic")
            decoded = temp / f"vort-{kind}.out"
            run(args.cli, decode_command, first, decoded, len(payload))
            if decoded.read_bytes() != payload:
                raise AssertionError(f"Vort {kind} Snappy self decode mismatch")
            listing = run(args.cli, inspect_command, first).stdout
            if "decoded_bytes=700000" not in listing:
                raise AssertionError(f"Vort {kind} metadata mismatch: {listing}")
            limited = run(
                args.cli,
                decode_command,
                first,
                temp / f"limited-{kind}.out",
                len(payload) - 1,
                check=False,
            )
            if limited.returncode == 0 or "OutputLimitExceeded" not in limited.stderr:
                raise AssertionError(f"Vort ignored {kind} output limit")
            self_cases += 1

        bad_xerial = bytearray((temp / "vort-xerial-first.snappy").read_bytes())
        bad_xerial[0] ^= 1
        bad_xerial_path = temp / "bad-xerial.snappy"
        bad_xerial_path.write_bytes(bad_xerial)
        if run(args.cli, "inspect-xerial-snappy-file", bad_xerial_path, check=False).returncode == 0:
            raise AssertionError("Vort accepted corrupt Xerial magic")
        malformed += 1

        bad_hadoop = bytearray((temp / "vort-hadoop-first.snappy").read_bytes())
        bad_hadoop[0:4] = (1).to_bytes(4, "big")
        bad_hadoop_path = temp / "bad-hadoop.snappy"
        bad_hadoop_path.write_bytes(bad_hadoop)
        if run(args.cli, "inspect-hadoop-snappy-file", bad_hadoop_path, check=False).returncode == 0:
            raise AssertionError("Vort accepted mismatched Hadoop block length")
        malformed += 1

        if args.snappy_java is not None and java is not None and javac is not None:
            classes = temp / "classes"
            classes.mkdir()
            run(javac, "-cp", args.snappy_java, "-d", classes, helper_source)
            classpath = f"{classes}{os.pathsep}{args.snappy_java}"
            for kind in ("xerial", "hadoop"):
                vort_stream = temp / f"vort-{kind}-first.snappy"
                java_decoded = temp / f"java-{kind}-decoded.out"
                run(java, "-cp", classpath, "SnappyInterop", f"{kind}-decode", vort_stream, java_decoded)
                if java_decoded.read_bytes() != payload:
                    raise AssertionError(f"snappy-java rejected Vort {kind} stream")
                java_stream = temp / f"java-{kind}.snappy"
                run(java, "-cp", classpath, "SnappyInterop", f"{kind}-encode", source, java_stream)
                vort_decoded = temp / f"vort-{kind}-java.out"
                run(
                    args.cli,
                    f"decode-{kind}-snappy-file",
                    java_stream,
                    vort_decoded,
                    len(payload),
                )
                if vort_decoded.read_bytes() != payload:
                    raise AssertionError(f"Vort rejected snappy-java {kind} stream")
                java_cases += 1

    print(
        f"self_cases={self_cases} java_available={java_cases != 0} "
        f"java_cases={java_cases} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
