#!/usr/bin/env python3
"""Compare Vort optimized COVER with zstd COVER and FastCover."""

import random
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRAIN_ROUNDS = 3


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


def source_samples() -> list[bytes]:
    source = b"\n".join(
        (ROOT / path).read_bytes()
        for path in ("src/zstd.zig", "src/dictionary.zig", "src/root.zig", "docs/roadmap.md")
    )
    chunk_len = 768
    available = len(source) - chunk_len
    return [
        source[(index * available // 39):(index * available // 39) + chunk_len]
        for index in range(40)
    ]


def train_reference(zstd: str, algorithm: str, output: Path, dictionary_id: int, samples: list[Path]) -> int:
    best = None
    for _ in range(TRAIN_ROUNDS):
        start = time.perf_counter_ns()
        subprocess.run(
            [
                zstd,
                algorithm,
                "--maxdict=512",
                f"--dictID={dictionary_id}",
                "-f",
                *map(str, samples),
                "-o",
                str(output),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        elapsed = time.perf_counter_ns() - start
        best = elapsed if best is None else min(best, elapsed)
    assert best is not None
    return best


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: cover_trainer_compare.py <probe>")
    zstd = shutil.which("zstd")
    if not zstd:
        raise SystemExit("zstd CLI is required")
    outputs = []
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        for case_index, kind in enumerate(("text", "json", "binary", "source")):
            case_root = root / kind
            case_root.mkdir()
            generated_samples = source_samples() if kind == "source" else [sample_bytes(kind, index) for index in range(40)]
            paths = []
            for index, contents in enumerate(generated_samples):
                path = case_root / f"sample-{index:03d}.bin"
                path.write_bytes(contents)
                paths.append(path)
            training, selector, heldout = paths[:32], paths[32:36], paths[36:]
            reference_samples = training + selector
            cover = case_root / "cover.zdict"
            fastcover = case_root / "fastcover.zdict"
            generated = case_root / "vort-cover.zdict"
            dictionary_id = 0x564F5400 + case_index * 4
            cover_ns = train_reference(zstd, "--train-cover", cover, dictionary_id, reference_samples)
            fastcover_ns = train_reference(zstd, "--train-fastcover", fastcover, dictionary_id + 1, reference_samples)
            args = [
                sys.argv[1],
                kind,
                str(cover),
                str(fastcover),
                str(generated),
                "352",
                str(len(training)),
                str(len(selector)),
                str(len(heldout)),
                str(cover_ns),
                str(fastcover_ns),
                *map(str, training),
                *map(str, selector),
                *map(str, heldout),
            ]
            output = subprocess.check_output(args, text=True).strip()
            if not output.startswith("zstd_cover_trainer_compare=ok"):
                raise SystemExit(f"unexpected probe output: {output!r}")
            fields = dict(field.split("=", 1) for field in output.split() if "=" in field)
            if fields.get("case") != kind or fields.get("samples") != "32/4/4":
                raise SystemExit(f"coverage mismatch: {output!r}")
            if int(fields.get("candidates", 0)) != 30:
                raise SystemExit(f"candidate grid mismatch: {output!r}")
            if int(fields.get("rounds", 0)) != TRAIN_ROUNDS:
                raise SystemExit(f"training round coverage mismatch: {output!r}")
            selected = [int(value) for value in fields.get("selected", "").split("/")]
            if len(selected) != 3 or selected[0] not in (32, 64, 128, 256, 352) or selected[1] not in (6, 8) or selected[2] not in (12, 16, 20):
                raise SystemExit(f"selected COVER parameters are outside the grid: {output!r}")
            for field in ("content", "dict", "level1", "level3", "level9", "train_ns"):
                values = [int(value) for value in fields.get(field, "").split("/")]
                if len(values) != 3 or min(values) <= 0:
                    raise SystemExit(f"invalid {field} evidence: {output!r}")
            for level in ("level1", "level3", "level9"):
                vort_size, cover_size, fastcover_size = map(int, fields[level].split("/"))
                if vort_size * 100 > cover_size * 126 or vort_size * 100 > fastcover_size * 116:
                    raise SystemExit(f"COVER held-out ratio gap exceeded for {kind}/{level}: {output!r}")
            vort_ns, cover_ns, fastcover_ns = map(int, fields["train_ns"].split("/"))
            if vort_ns > min(cover_ns, fastcover_ns) * 200:
                raise SystemExit(f"COVER training-time gap exceeded: {output!r}")
            outputs.append((kind, fields, output))

    for _, _, output in outputs:
        print(output)
    vort_total = sum(int(fields[level].split("/")[0]) for _, fields, _ in outputs for level in ("level1", "level3", "level9"))
    cover_total = sum(int(fields[level].split("/")[1]) for _, fields, _ in outputs for level in ("level1", "level3", "level9"))
    fastcover_total = sum(int(fields[level].split("/")[2]) for _, fields, _ in outputs for level in ("level1", "level3", "level9"))
    if vort_total * 100 > cover_total * 103 or vort_total * 100 > fastcover_total * 103:
        raise SystemExit(f"aggregate COVER ratio gap exceeded: {vort_total}/{cover_total}/{fastcover_total}")
    print(
        f"zstd_cover_trainer_compare_gate=ok cases={len(outputs)} rounds={TRAIN_ROUNDS} "
        f"total={vort_total}/{cover_total}/{fastcover_total}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
