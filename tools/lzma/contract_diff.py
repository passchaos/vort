#!/usr/bin/env python3
"""Independent LZMA-Alone stream/resource contract differential (no CLI).

Build the public-module probe in ReleaseSafe, then pass --probe. --prepare-only
validates the independent reference corpus without building Vort. Reports are
correctness evidence and contain no throughput measurements.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import lzma
from pathlib import Path
import platform
import random
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def require(value, context):
    if not value:
        raise AssertionError(context)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def command(*args, data=None):
    result = subprocess.run([str(a) for a in args], input=data, capture_output=True, cwd=ROOT)
    if result.returncode:
        raise RuntimeError(f"command failed: {args}\n{result.stderr.decode(errors='replace')}")
    return result.stdout


def sources():
    paths = [ROOT / "src/lzma.zig", ROOT / "src/core.zig", ROOT / "src/io/working_allocator.zig", *(ROOT / "src/lzma").rglob("*.zig")]
    rows = [{"path": str(p.relative_to(ROOT)), "sha256": sha(p.read_bytes())} for p in sorted(paths)]
    return {"files": rows, "sha256": sha(json.dumps(rows, sort_keys=True).encode())}


def cpu():
    for line in Path("/proc/cpuinfo").read_text().splitlines():
        if line.startswith("model name"):
            return line.split(":", 1)[1].strip()
    return platform.processor()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--probe", type=Path)
    p.add_argument("--report", type=Path)
    p.add_argument("--work-dir", type=Path)
    p.add_argument("--prepare-only", action="store_true")
    args = p.parse_args()
    require(args.prepare_only or args.probe, "--probe is required unless --prepare-only")
    probe = args.probe.resolve() if args.probe else None
    before = sources()
    driver_sha = sha(Path(__file__).read_bytes())
    rows, corpus = [], []
    rng = random.Random(0x1A2B3C07)
    xz = shutil.which("xz")
    tmp = tempfile.TemporaryDirectory(prefix="vort-lzma-contract-") if args.work_dir is None else None
    work = Path(tmp.name) if tmp else args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    payloads = [("empty", b""), ("tiny", b"hello LZMA-Alone\n"),
                ("repetitive", b"symbol-progressive LZMA ring\n" * 1000),
                ("binary", bytes(range(256)) * 129), ("random", rng.randbytes(16387)),
                ("source", (ROOT / "src/root.zig").read_bytes()[:32768])]
    cases = []
    for dictionary in (4096, 65536):
        for name, data in payloads:
            filt = {"id": lzma.FILTER_LZMA1, "dict_size": dictionary, "lc": 3, "lp": 0, "pb": 2, "preset": 6}
            encoded = lzma.compress(data, format=lzma.FORMAT_ALONE, filters=[filt])
            require(lzma.decompress(encoded, format=lzma.FORMAT_ALONE) == data, (name, "Python reference"))
            if xz:
                require(command(xz, "--format=lzma", "-dc", data=encoded) == data, (name, "xz reference"))
            for mode in ("eos", "known"):
                wire = encoded if mode == "eos" else encoded[:5] + len(data).to_bytes(8, "little") + encoded[13:]
                label = f"{name}-dict{dictionary}-{mode}"
                cases.append((label, wire, data, dictionary))
                corpus.append({"name": label, "source": "Python lzma.FORMAT_ALONE / liblzma" if mode == "eos" else "Independent Python EOS payload with known-size header rewrite; legacy Vort known-size contract",
                               "reference_verified_transport": mode == "eos", "filter": filt,
                               "compressed_bytes": len(wire), "output_bytes": len(data), "compressed_sha256": sha(wire), "output_sha256": sha(data)})
    lp_data = b"literal contexts after matches\n" * 127 + rng.randbytes(4096) + b"literal contexts after matches\n" * 21
    lp_filter = {"id": lzma.FILTER_LZMA1, "dict_size": 4096, "lc": 2, "lp": 2, "pb": 2, "preset": 6}
    lp_wire = lzma.compress(lp_data, format=lzma.FORMAT_ALONE, filters=[lp_filter])
    require(lzma.decompress(lp_wire, format=lzma.FORMAT_ALONE) == lp_data, "nonzero LP reference")
    cases.append(("matched-literal-nonzero-lp", lp_wire, lp_data, 4096))
    corpus.append({"name": "matched-literal-nonzero-lp", "source": "Python lzma.FORMAT_ALONE / liblzma", "filter": lp_filter,
                   "compressed_bytes": len(lp_wire), "output_bytes": len(lp_data), "compressed_sha256": sha(lp_wire), "output_sha256": sha(lp_data)})

    def check(name, encoded, data, pattern="mixed", error=None, **opts):
        i = len(rows)
        inp, expected, output, cfg = (work / f"{i}-{s}" for s in ("input.lzma", "expected", "output", "config.json"))
        inp.write_bytes(encoded)
        expected.write_bytes(data)
        config = {"pattern": pattern, "max_dictionary_size": 65536, "max_compressed_buffer_len": 64,
                  "expect_failure": error is not None, **opts}
        cfg.write_text(json.dumps(config) + "\n")
        try:
            result = json.loads(command(probe, inp, expected, output, cfg))
        except Exception as exc:
            raise RuntimeError(f"LZMA case {name}: {config}") from exc
        actual = output.read_bytes()
        require(actual == data[:result["output_written"]], (name, "published prefix"))
        require(result["snapshot"]["input_read"] == result["input_read"] and result["snapshot"]["output_written"] == len(actual), (name, "total progress"))
        require(result["max_output_capacity"] == 273, (name, "fixed symbol stage"))
        require(result["max_compressed_capacity"] <= config["max_compressed_buffer_len"], (name, "compressed capacity"))
        require(result["peak_working_bytes"] <= config.get("max_working_memory", 2**64 - 1), (name, "working cap"))
        if error is None:
            require(result["error"] is None and actual == data, (name, "decode"))
        else:
            require(result["error"] in ([error] if isinstance(error, str) else error), (name, error, result["error"]))
            require(result["sticky_checks"] > 0, (name, "sticky error"))
        rows.append({"name": name, "config": config, "compressed_sha256": sha(encoded), "output_sha256": sha(actual), **result})
        return result

    if not args.prepare_only:
        for name, data in payloads:
            src, dst = work / "known-source", work / "proper-known.lzma"
            src.write_bytes(data)
            command(probe, "--encode-known", src, dst)
            proper = dst.read_bytes()
            require(lzma.decompress(proper, format=lzma.FORMAT_ALONE) == data, (name, "proper known Python reference"))
            if xz:
                require(command(xz, "--format=lzma", "-dc", data=proper) == data, (name, "proper known xz reference"))
            label = f"{name}-proper-known-no-eos"
            cases.append((label, proper, data, 4096))
            corpus.append({"name": label, "source": "Vort public LZMA writer known/no-EOS, independently Python liblzma and xz decoded",
                           "reference_verified_transport": True, "compressed_bytes": len(proper), "output_bytes": len(data), "compressed_sha256": sha(proper), "output_sha256": sha(data)})
        for name, wire, data, dictionary in cases:
            for pattern in ("one", "mixed", "wide"):
                check(name, wire, data, pattern, max_dictionary_size=dictionary)
        name, wire, data, dictionary = next(c for c in cases if c[0] == "repetitive-dict4096-eos")
        for label, wide_wire, wide_data in (("repetitive", wire, data), ("nonzero-lp", lp_wire, lp_data)):
            zero = check(f"wide-zero-output-{label}", wide_wire, wide_data, "wide_zero")
            require(zero["zero_output_steps"] > 0, "wide input with zero/tiny output")
        baseline = check("resources-baseline", wire, data, reset_after=True, oom=True, move_after_steps=7)
        require(baseline["oom_failure_cases"] > 0 and baseline["reset_checks"] == 2 and baseline["moves"] == 1, "allocation/reset/move coverage")
        for pattern in ("one", "mixed", "wide"):
            base = check(f"resource-{pattern}", wire, data, pattern)
            for field, exact, expected_error in (
                    ("max_output_len", len(data), "OutputLimitExceeded"),
                    ("max_dictionary_size", dictionary, "OutputLimitExceeded"),
                    ("max_working_memory", base["peak_working_bytes"], "WorkingMemoryLimitExceeded")):
                check(f"{field}-exact-{pattern}", wire, data, pattern, **{field: exact})
                check(f"{field}-below-{pattern}", wire, data, pattern, expected_error, **{field: exact - 1})
            check(f"compressed-exact-{pattern}", wire, data, pattern, max_compressed_buffer_len=64)
            check(f"compressed-below-{pattern}", wire, data, pattern,
                  ("CompressedBufferLimitExceeded", "OutputLimitExceeded"), max_compressed_buffer_len=63)
        check("expected-size-exact", wire, data, expected_output_len=len(data))
        check("expected-size-below", wire, data, error="SizeMismatch", expected_output_len=len(data) - 1)
        check("expected-size-above", wire, data, error="SizeMismatch", expected_output_len=len(data) + 1)
        for pattern in ("one", "mixed", "wide"):
            suffix = b"outer-container-tail\0\xff"
            dec = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE)
            require(dec.decompress(wire + suffix) == data and dec.unused_data == suffix, "reference EOS boundary")
            stopped = check("eos-container-tail", wire + suffix, data, pattern, stop_after_end_marker=True)
            require(len(wire + suffix) - stopped["input_read"] + stopped["snapshot"]["trailing_input_bytes"] == len(suffix), "EOS retained suffix")
            check("eos-trailing-rejected", wire + suffix, data, pattern, "TrailingData")
            short_data = bytes(range(14))
            short = lzma.compress(short_data, format=lzma.FORMAT_ALONE, filters=[{"id": lzma.FILTER_LZMA1, "dict_size": 4096}])
            require(len(short) == 37, "short EOS fixture length")
            for guard in (12, 16):
                suffix = b"outer-tail-padding0123456789"
                require(len(suffix) == 28, "short suffix fixture length")
                for label, guard_wire, guard_data in (("short37", short, short_data), ("nonzero-lp", lp_wire, lp_data)):
                    stopped = check(f"guard{guard}-{label}", guard_wire + suffix, guard_data, pattern,
                                    stop_after_end_marker=True, end_marker_input_guard=guard)
                    require(len(guard_wire + suffix) - stopped["input_read"] + stopped["snapshot"]["trailing_input_bytes"] == len(suffix), "small-guard EOS suffix")
        bad = bytes([255]) + wire[1:]
        check("invalid-properties", bad, b"", error="InvalidLzmaHeader", reset_after=True)
        check("range-prefix-invalid", wire[:13] + b"\xff" + wire[14:], b"", error="InvalidLzmaStream")
        for cut in (0, 1, 5, 12, 13, 17, len(wire) // 2, len(wire) - 1):
            for pattern in ("mixed", "wide"):
                check(f"truncated-{cut}", wire[:cut], data, pattern, "TruncatedFrame")
    require(before == sources(), "codec sources changed during differential; rebuild and rerun after source freeze")
    require(driver_sha == sha(Path(__file__).read_bytes()), "driver changed during differential; rerun after source freeze")
    report = {"schema": "vort.lzma_stream_contracts", "schema_version": 1,
              "status": "reference_prepared" if args.prepare_only else "ok", "utc": datetime.now(timezone.utc).isoformat(),
              "python": sys.version, "xz": command(xz, "--version").decode().splitlines()[0] if xz else None,
              "zig": command("zig", "version").decode().strip(), "cpu": cpu(), "build_mode": rows[0]["build_mode"] if rows else None,
              "command": sys.argv, "probe": str(probe) if probe else None, "probe_sha256": sha(probe.read_bytes()) if probe else None,
              "driver_sha256": driver_sha, "sources": before, "corpus": corpus,
              "git_head": command("git", "rev-parse", "HEAD").decode().strip(),
              "cases": rows, "summary": {"corpus_streams": len(corpus), "runs": len(rows), "errors": dict(Counter(r["error"] for r in rows if r["error"])),
                                        "oom_failure_cases": sum(r["oom_failure_cases"] for r in rows)}}
    if args.report:
        args.report.resolve().parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], **report["summary"]}, sort_keys=True))
    if tmp:
        tmp.cleanup()


if __name__ == "__main__":
    main()
