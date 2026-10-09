#!/usr/bin/env python3
"""Black-box CAB compatibility checks against public libmspack fixtures."""

from __future__ import annotations

import argparse
import hashlib
import subprocess
import tempfile
from pathlib import Path


EXPECTED = {
    "simple": {
        "sha256": "590791307b407a6ec6d885542952b7eb6575defde68e06d25bac4f41a9b634fd",
        "files": {
            "hello.c": b'#include <stdio.h>\r\n\r\nvoid main(void)\r\n{\r\n    printf("Hello, world!\\n");\r\n}\r\n',
            "welcome.c": b'#include <stdio.h>\r\n\r\nvoid main(void)\r\n{\r\n    printf("Welcome!\\n");\r\n}\r\n\r\n',
        },
    },
    "mixed": {
        "sha256": "0ce0b55fe705b744d41bb361170c0467db30da0c7f9bdd386d5dade71a78e171",
        "files": {
            "mszip.txt": b"If you can read this, the MSZIP decompressor is working!\n",
        },
    },
}


def run(cli: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(cli), *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def fixture(root: Path, name: str) -> bytes:
    encoded = (root / f"libmspack-{name}.cab.hex").read_text(encoding="ascii")
    data = bytes.fromhex(encoded)
    digest = hashlib.sha256(data).hexdigest()
    if digest != EXPECTED[name]["sha256"]:
        raise AssertionError(f"CAB fixture digest mismatch for {name}: {digest}")
    return data


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument(
        "--fixtures",
        type=Path,
        default=Path("src/cab/testdata"),
    )
    args = parser.parse_args()

    extracted = 0
    with tempfile.TemporaryDirectory(prefix="vort-cab-diff-") as temp_text:
        temp = Path(temp_text)
        for fixture_name, expected in EXPECTED.items():
            cab_path = temp / f"{fixture_name}.cab"
            cab_path.write_bytes(fixture(args.fixtures, fixture_name))
            listing = run(args.cli, "list-cab-file", str(cab_path)).stdout
            for name in expected["files"]:
                if f"name={name}" not in listing:
                    raise AssertionError(f"CAB listing omitted {name!r}: {listing}")
            for index, (name, payload) in enumerate(expected["files"].items()):
                output = temp / f"{fixture_name}-{index}.out"
                run(
                    args.cli,
                    "extract-cab-file",
                    str(cab_path),
                    name,
                    str(output),
                    "1048576",
                    "1048576",
                )
                if output.read_bytes() != payload:
                    raise AssertionError(f"CAB extraction mismatch for {name!r}")
                extracted += 1

        mixed_path = temp / "mixed.cab"
        unsupported = run(
            args.cli,
            "extract-cab-file",
            str(mixed_path),
            "lzx.txt",
            str(temp / "lzx.out"),
            check=False,
        )
        if unsupported.returncode == 0 or "UnsupportedCabinetCompression" not in unsupported.stderr:
            raise AssertionError(f"LZX CAB entry did not fail explicitly: {unsupported.stderr}")

    print(f"cab_diff=ok fixtures=2 extracted={extracted} unsupported_lzx=ok")


if __name__ == "__main__":
    main()
