import argparse
import filecmp
import hashlib
import json
import platform
import random
import subprocess
import tempfile
from pathlib import Path
from diff import build_probe, x86_payload


def run(*args, check=True):
    return subprocess.run([str(arg) for arg in args], check=check, capture_output=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--probe", required=True, type=Path)
    parser.add_argument("--item-probe", required=True, type=Path)
    parser.add_argument("--wimlib-probe", type=Path)
    parser.add_argument("--wimlib-dir", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    rng = random.Random(0x4C5A4D5347524545)
    prefix = rng.randbytes(8192)
    families = {
        "empty": b"", "one": b"a", "two": b"aa", "tiny": b"abcabcabcabcabcab",
        "text": b"LZMS repeated payload 0123456789\n" * 2000,
        "json": b"".join(json.dumps({"id": i, "value": i % 17, "message": "LZMS JSON matching"}).encode() + b"\n" for i in range(1024)),
        "delta": bytes((i * 4 + 7) & 255 for i in range(32768)),
        "matrix": bytes((row + column) & 255 for row in range(512) for column in range(64)),
        "binary-repeat": prefix * 4, "random": rng.randbytes(65536), "x86": x86_payload(),
        "source": Path("src/lzms/decoder.zig").read_bytes(),
        "mixed": b"structured-prefix\n" * 1000 + rng.randbytes(4096) + b"structured-tail\n" * 1000,
    }
    rows = []
    item_cases = 0
    external = 0
    with tempfile.TemporaryDirectory(prefix="vort-lzms-matches-") as name:
        temp = Path(name)
        oracle = args.wimlib_probe
        if oracle is None and args.wimlib_dir is not None:
            oracle = build_probe(args.wimlib_dir, temp / "wimlib-probe")
        if oracle is None:
            raise AssertionError("an independent --wimlib-probe or --wimlib-dir is required")
        version = run(oracle, "version").stdout.decode().strip()
        for label, plain in families.items():
            source = temp / f"{label}.bin"
            source.write_bytes(plain)
            reference_bytes = 0
            reference_raw = False
            if plain:
                ref = temp / f"{label}-reference.lzms"
                result = run(oracle, "encode", source, ref, check=False)
                if result.returncode == 3:
                    reference_raw = True
                    reference_bytes = len(plain)
                elif result.returncode == 0:
                    reference_bytes = ref.stat().st_size
                    restored = temp / f"{label}-reference.out"
                    run(oracle, "decode", ref, restored, len(plain))
                    if restored.read_bytes() != plain:
                        raise AssertionError(f"reference round trip failed: {label}")
                else:
                    raise AssertionError(f"reference encoding failed: {label}: {result.stderr!r}")
            for mode in ("greedy", "lz", "literals"):
                encoded = temp / f"{label}-{mode}.lzms"
                repeat = temp / f"{label}-{mode}-repeat.lzms"
                observation = run(args.probe, source, encoded, mode)
                row = json.loads(observation.stderr)
                duplicate = run(args.probe, source, repeat, mode)
                if not filecmp.cmp(encoded, repeat, shallow=False) or json.loads(duplicate.stderr) != row:
                    raise AssertionError(f"non-deterministic encoder: {label}/{mode}")
                if len(plain) >= 3:
                    restored = temp / f"{label}-{mode}.out"
                    run(oracle, "decode", encoded, restored, len(plain))
                    if restored.read_bytes() != plain:
                        raise AssertionError(f"wimlib decode failed: {label}/{mode}")
                    external += 1
                if 0 < len(plain) < 3:
                    limitation = run(oracle, "decode", encoded, temp / "tiny-reference.out", len(plain), check=False)
                    if limitation.returncode != 4 or b"reference limitation" not in limitation.stderr:
                        raise AssertionError("tiny oracle limitation was not reported")
                if row["encoded"] > row["literal"]:
                    raise AssertionError(f"literal envelope exceeded: {label}/{mode}")
                if mode == "greedy" and label in ("text", "delta", "matrix", "x86"):
                    if row["encoded"] * 4 >= row["literal"] or row["lz"] + row["delta"] == 0:
                        raise AssertionError(f"missing meaningful match compression: {label}")
                if mode == "greedy" and label == "binary-repeat":
                    # Charge the irreducible random prefix and frame overhead.
                    if row["encoded"] > len(prefix) + 512 or row["matched_bytes"] < 3 * len(prefix) or row["max_lz_offset"] != len(prefix):
                        raise AssertionError("binary repetition did not cover its complete tail near prefix cost")
                if mode == "greedy" and label in ("delta", "matrix") and row["delta"] == 0:
                    raise AssertionError(f"delta path not selected: {label}")
                if mode == "literals" and (row["encoded"] != row["literal"] or row["lz"] or row["delta"]):
                    raise AssertionError(f"literal reference changed: {label}")
                row.update(case=label, strategy=mode, input_sha256=hashlib.sha256(plain).hexdigest(), encoded_sha256=hashlib.sha256(encoded.read_bytes()).hexdigest(), reference_bytes=reference_bytes, reference_raw_fallback=reference_raw)
                rows.append(row)
        for mode, power in [("lz", 0)] + [("delta", i) for i in range(8)] + [("wide", 0)]:
            encoded = temp / f"item-{mode}-{power}.lzms"
            expected = temp / f"item-{mode}-{power}.bin"
            restored = temp / f"item-{mode}-{power}.out"
            run(args.item_probe, encoded, expected, mode, power)
            run(oracle, "decode", encoded, restored, expected.stat().st_size)
            if not filecmp.cmp(expected, restored, shallow=False):
                raise AssertionError(f"item-family oracle failed: {mode}/{power}")
            item_cases += 1
    report = {"schema": "vort-lzms-matching-v1", "claim": "functionality and compressed sizes; no throughput-parity claim", "platform": platform.platform(), "wimlib_version": version, "reference_limitations": ["pinned wimlib LZMS decoder faults on output sizes 1 and 2; native tiny round trips remain checked"], "probe_sha256": hashlib.sha256(args.probe.read_bytes()).hexdigest(), "rows": rows, "raw_cases": len(rows), "external_decodes": external, "item_cases": item_cases}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(f"lzms_matching={len(rows)} external={external} item_families={item_cases} wimlib={version}")


if __name__ == "__main__":
    main()
