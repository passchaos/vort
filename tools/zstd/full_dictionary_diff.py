#!/usr/bin/env python3
"""Train a deterministic standard dictionary and run the Zig/libzstd diff."""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: full_dictionary_diff.py <probe>")
    zstd = shutil.which("zstd")
    if not zstd:
        raise SystemExit("zstd CLI is required")
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        samples = []
        for index in range(40):
            path = root / f"sample-{index:03d}.json"
            path.write_text(
                f'{{"kind":"event","service":"vort","id":{index},'
                f'"message":"standard dictionary sample {index % 7}"}}\n'
            )
            samples.append(path)
        dictionary = root / "dictionary.zdict"
        subprocess.run(
            [zstd, "--train", "--dictID=1180675969", *map(str, samples), "-o", str(dictionary)],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        output = subprocess.check_output([sys.argv[1], str(dictionary)], text=True)
        if not output.startswith("zstd_full_dictionary_diff=ok version="):
            raise SystemExit(f"unexpected probe output: {output!r}")
        if "id=1180675969" not in output:
            raise SystemExit(f"dictionary id mismatch: {output!r}")
        print(output, end="")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
