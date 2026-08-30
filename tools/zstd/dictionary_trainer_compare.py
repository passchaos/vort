#!/usr/bin/env python3
"""Compare Vort and zstd dictionary trainers on identical held-out corpora."""

import random
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def sample_bytes(kind: str, index: int) -> bytes:
    rng = random.Random(0x9E3779B1 + index * 977 + len(kind) * 131)
    if kind == "text":
        words = ["compression", "dictionary", "stream", "history", "entropy", "packet", "buffer", "codec"]
        return (" ".join(words[(index + rng.randrange(4) + j) % len(words)] for j in range(42)) + f" #{index}\n").encode()
    if kind == "json":
        rows = [
            f'{{"kind":"event","service":"svc-{index % 5}","region":"r-{(index * 3) % 7}",'
            f'"status":"{("ok", "warn", "retry")[index % 3]}","request":{index * 17 + row}}}'
            for row in range(6)
        ]
        return ("\n".join(rows) + "\n").encode()
    data = bytearray()
    for block in range(12):
        data += b"VORT" + index.to_bytes(2, "little") + block.to_bytes(2, "little")
        data += bytes(rng.choices([0, 0, 0, 1, 2, 3, 0xFF, rng.randrange(256)], k=24))
    return bytes(data)


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: dictionary_trainer_compare.py <probe>")
    zstd = shutil.which("zstd")
    if not zstd:
        raise SystemExit("zstd CLI is required")
    rows = []
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        for case_index, kind in enumerate(("text", "json", "binary")):
            case_root = root / kind
            case_root.mkdir()
            paths = []
            for index in range(40):
                path = case_root / f"sample-{index:03d}.bin"
                path.write_bytes(sample_bytes(kind, index))
                paths.append(path)
            training, selector, heldout = paths[:32], paths[32:36], paths[36:]
            reference = case_root / "reference.zdict"
            generated = case_root / "vort.zdict"
            subprocess.run(
                [zstd, "--train", "--maxdict=512", f"--dictID={0x564F5200 + case_index}", *map(str, training + selector), "-o", str(reference)],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            args = [
                sys.argv[1], kind, str(reference), str(generated), "352",
                str(len(training)), str(len(selector)), str(len(heldout)),
                *map(str, training), *map(str, selector), *map(str, heldout),
            ]
            output = subprocess.check_output(args, text=True).strip()
            if not output.startswith("zstd_dictionary_trainer_compare=ok"):
                raise SystemExit(f"unexpected probe output: {output!r}")
            fields = dict(field.split("=", 1) for field in output.split() if "=" in field)
            if fields.get("case") != kind or fields.get("samples") != "32/4/4":
                raise SystemExit(f"coverage mismatch: {output!r}")
            selected_content, reference_content = map(int, fields["content"].split("/", 1))
            if selected_content <= 0 or selected_content > int(fields["target"]) or reference_content <= 0:
                raise SystemExit(f"invalid selected history size: {output!r}")
            ratios = []
            for level in ("level1", "level3", "level9"):
                vort_size, reference_size = map(int, fields[level].split("/", 1))
                ratios.append(vort_size / reference_size)
            # This command is an honest parity-gap gate, not a claim that the
            # lightweight selector already beats COVER/FastCover. Prevent a
            # silent >50% regression on any row and require the aggregate gap
            # to remain within 20% while the selector is improved iteratively.
            if max(ratios) > 1.50 or sum(ratios) / len(ratios) > 1.20:
                raise SystemExit(f"trainer parity gap exceeded: {output!r}")
            rows.append((kind, fields, output))

    for _, _, output in rows:
        print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
