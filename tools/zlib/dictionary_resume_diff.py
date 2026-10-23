#!/usr/bin/env python3
"""Independent Python-zlib FDICT recovery and exact step-progress checks.

Every compressed member is generated and checked by system Python zlib.
The Zig probe resumes the same public decoder after NeedDictionary. This is
functional wire/progress evidence and makes no throughput claim.
"""

import argparse
from collections import Counter
from contextlib import nullcontext
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import random
import struct
import subprocess
import sys
import tempfile
import zlib


ROOT = Path(__file__).resolve().parents[2]
STRATEGIES = {"default": zlib.Z_DEFAULT_STRATEGY, "filtered": zlib.Z_FILTERED,
              "huffman": zlib.Z_HUFFMAN_ONLY, "rle": zlib.Z_RLE, "fixed": zlib.Z_FIXED}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def run(*args):
    result = subprocess.run([str(value) for value in args], cwd=ROOT, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"command failed: {' '.join(map(str, args))}\n{result.stderr.decode(errors='replace')}")
    return result


def encode(data, dictionary, level, strategy):
    compressor = zlib.compressobj(level, zlib.DEFLATED, 15, 8, strategy, zdict=dictionary)
    wire = compressor.compress(data) + compressor.flush()
    require(wire[1] & 0x20, "Python must emit FDICT")
    require(struct.unpack_from(">I", wire, 2)[0] == zlib.adler32(dictionary), "Python DICTID")
    decoder = zlib.decompressobj(wbits=15, zdict=dictionary)
    require(decoder.decompress(wire) + decoder.flush() == data and decoder.eof, "Python round trip")
    return wire


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--work-dir", type=Path)
    args = parser.parse_args()
    args.probe = args.probe.resolve()
    if args.work_dir:
        args.work_dir = args.work_dir.resolve()
        args.work_dir.mkdir(parents=True, exist_ok=True)
        require(not any(args.work_dir.iterdir()), "--work-dir must be empty")
    workspace = nullcontext(str(args.work_dir)) if args.work_dir else tempfile.TemporaryDirectory(prefix="vort-zlib-dictionary-resume-")
    rng = random.Random(0xD1C710)
    dictionaries = {
        "short": b"preset dictionary: HTTP JSON source log keys\n" * 20,
        "repeat-long": b"abcabcabcXYZ012345\n" * 4000,
        "random-long": rng.randbytes(65537),
        "prefix-long": rng.randbytes(35001) + b"suffix reusable dictionary contents\n" * 200,
        "byte-cycle-long": bytes(range(256)) * 201,
    }
    rows, corpus = [], []
    with workspace as directory:
        temp = Path(directory)
        dictionary_paths = {}
        for name, data in dictionaries.items():
            path = temp / f"dictionary-{name}"
            path.write_bytes(data)
            dictionary_paths[name] = path

        def check(name, wire, expected, dictionary_names, pattern="micro", initializer="missing", **options):
            index = len(rows)
            source, expect, output, config_path = (temp / f"case-{index}-{suffix}" for suffix in
                                                  ("input.zlib", "expected", "output", "config.json"))
            source.write_bytes(wire)
            expect.write_bytes(expected)
            config = {"pattern": pattern, "initializer": initializer,
                      "dictionary_paths": [str(dictionary_paths[name]) for name in dictionary_names], **options}
            config_path.write_text(json.dumps(config) + "\n")
            stats = json.loads(run(args.probe, source, expect, output, config_path).stdout)
            require(stats["input_read"] == stats["snapshot"]["total_input"], (name, "snapshot input accounting"))
            require(stats["output_written"] == stats["snapshot"]["total_output"], (name, "snapshot output accounting"))
            require(output.read_bytes() == expected[:stats["output_written"]], (name, "actual published prefix"))
            if options.get("expected_error"):
                require(stats["error"] == options["expected_error"], (name, "expected error"))
            else:
                require(stats["error"] is None and output.read_bytes() == expected, (name, "resumed result"))
                require(stats["input_read"] == len(wire), (name, "complete input consumption"))
            if initializer in ("missing", "set-miss", "wrong"):
                require(bool(stats["requests"]), (name, "must exercise NeedDictionary recovery"))
            if initializer in ("correct", "set-hit") and len(dictionary_names) == 1:
                require(not stats["requests"], (name, "preset/Set hit should decode immediately"))
            allowed_ids = {zlib.adler32(dictionaries[name]) for name in dictionary_names}
            for request in stats["requests"]:
                require(request["id"] in allowed_ids, (name, "required dictionary ID"))
                dictionary = next(data for data in dictionaries.values() if zlib.adler32(data) == request["id"])
                wrong_attempts = 2 + int(len(dictionary) > 32768 and zlib.adler32(dictionary[-32768:]) != request["id"])
                require(request["wrong_dictionary_attempts"] == wrong_attempts,
                        (name, "required ID and rejected wrong dictionaries"))
                require(request["last_error_input_offset"] == request["input_offset"]
                        and request["last_error_output_offset"] == request["output_offset"],
                        (name, "NeedDictionary error offsets"))
                if options.get("finish_on_need"):
                    require(request["finish_error"] == "NeedDictionary", (name, "deferred EOF dictionary resolution"))
            rows.append({"case_index": index, "case": name, "config": config,
                         "input_bytes": len(wire), "expected_bytes": len(expected),
                         "input_sha256": digest(wire), "expected_sha256": digest(expected),
                         "output_sha256": digest(output.read_bytes()), **stats})
            return stats

        for dictionary_index, (name, dictionary) in enumerate(dictionaries.items()):
            suffix = dictionary[-8192:]
            payloads = [b"", suffix[-97:], suffix + b'\n{"id":10,"type":"dictionary"}\n' + suffix,
                        rng.randbytes(2049)]
            for level_index, level in enumerate((0, 1, 6, 9)):
                for strategy_index, (strategy_name, strategy) in enumerate(STRATEGIES.items()):
                    payload = payloads[(dictionary_index + level_index + strategy_index) % len(payloads)]
                    encoded = encode(payload, dictionary, level, strategy)
                    case_name = f"{name}-level{level}-{strategy_name}"
                    corpus.append((case_name, encoded, payload, name))
                    for pattern in ("one", "micro", "full"):
                        check(case_name, encoded, payload, [name], pattern)
            print(f"zlib FDICT dictionary={name} cases={len(rows)} Python=ok", flush=True)
        for name, dictionary in dictionaries.items():
            payload = dictionary[-4096:] * 2
            encoded = encode(payload, dictionary, 6, zlib.Z_DEFAULT_STRATEGY)
            for initializer in ("correct", "set-hit", "set-miss", "wrong"):
                check(f"initializer-{name}-{initializer}", encoded, payload, [name], initializer=initializer)
            check(f"reset-{name}", encoded, payload, [name], reset_after=True)
            check(f"EOF-resume-{name}", encoded, payload, [name], "full", finish_on_need=True)
        first_data = b"plain zlib first member produces output before a dictionary request\n" * 5
        first = zlib.compress(first_data)
        dict_one, dict_two = "short", "random-long"
        second_data, third_data = dictionaries[dict_one][-200:] * 2, dictionaries[dict_two][-1000:] * 2
        second = encode(second_data, dictionaries[dict_one], 6, zlib.Z_DEFAULT_STRATEGY)
        third = encode(third_data, dictionaries[dict_two], 9, zlib.Z_FIXED)
        concatenated, concatenated_data = first + second + third, first_data + second_data + third_data
        # Independent member decoding verifies the concatenated expected value.
        for pattern in ("one", "micro", "full"):
            stats = check("concatenated-distinct-dictionaries", concatenated, concatenated_data,
                          [dict_one, dict_two], pattern, allow_concatenated=True)
            require(len(stats["requests"]) == 2 and stats["snapshot"]["stream_count"] == 3, "three member resume")
            require(stats["requests"][0]["output_offset"] == len(first_data), "prior member output retained")
        stats = check("concatenated-same-call-progress", first + second, first_data + second_data,
                      [dict_one], "full", allow_concatenated=True)
        require(stats["requests"][0]["error_output_progress"] == len(first_data), "NeedDictionary same-call output progress")
        check("concatenated-set-miss", concatenated, concatenated_data, [dict_one, dict_two], "full",
              initializer="set-miss", allow_concatenated=True)
        check("concatenated-set-hit", concatenated, concatenated_data, [dict_one, dict_two], "full",
              initializer="set-hit", allow_concatenated=True)
        check("concatenated-cumulative-limit", concatenated, concatenated_data, [dict_one, dict_two], "full",
              allow_concatenated=True, max_output_len=len(concatenated_data) - 1, expected_error="OutputLimitExceeded")
        dictionary = dictionaries["short"]
        limited_data = dictionary[-300:] * 3
        limited = encode(limited_data, dictionary, 6, zlib.Z_DEFAULT_STRATEGY)
        check("exact-output-limit", limited, limited_data, ["short"], max_output_len=len(limited_data))
        check("output-limit", limited, limited_data, ["short"], "full", max_output_len=len(limited_data) - 1,
              expected_error="OutputLimitExceeded")
        check("exact-expected-length", limited, limited_data, ["short"], expected_output_len=len(limited_data))
        corrupt = bytearray(limited)
        corrupt[-1] ^= 1
        check("corrupt-footer-after-resume", bytes(corrupt), limited_data, ["short"], "full", expected_error="ChecksumMismatch")
        check("truncated-footer-after-resume", limited[:-2], limited_data, ["short"], expected_error="TruncatedFrame")
        check("trailing-after-resume", limited + b"x", limited_data, ["short"], "full", expected_error="TrailingData")
        requests = [request for row in rows for request in row["requests"]]
        require(any(request["error_output_progress"] > 0 for request in requests), "same-call output before NeedDictionary must be observed")
        require(any(row["error_output_progress"] > 0 for row in rows if row["error"] is not None),
                "non-dictionary error must preserve real published progress")
        report = {"schema": "vort-zlib-dictionary-resume-v1",
                  "claim": "Python-zlib wire compatibility, in-place dictionary recovery and exact progress; no throughput claim",
                  "created_utc": datetime.now(timezone.utc).isoformat(), "platform": platform.platform(), "invocation": sys.argv,
                  "python_version": sys.version, "zlib_compile_version": zlib.ZLIB_VERSION,
                  "zlib_runtime_version": zlib.ZLIB_RUNTIME_VERSION,
                  "generator": "compressobj(level;DEFLATED;wbits=15;memLevel=8;strategy;zdict); compress+flush",
                  "python_executable_sha256": digest(Path(sys.executable).read_bytes()),
                  "zlib_module_origin": zlib.__spec__.origin,
                  "zlib_python_extension_sha256": digest(Path(zlib.__file__).read_bytes()) if getattr(zlib, "__file__", None) else None,
                  "probe_sha256": digest(args.probe.read_bytes()),
                  "repository_commit": run("git", "rev-parse", "HEAD").stdout.decode().strip(),
                  "repository_dirty": bool(run("git", "status", "--porcelain").stdout),
                  "source_sha256": {str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in
                                    [ROOT / "src/root.zig", ROOT / "src/deflate.zig", ROOT / "src/core.zig", ROOT / "src/checksum.zig",
                                     *sorted((ROOT / "src/deflate/incremental/decoder").glob("*.zig")),
                                     ROOT / "src/deflate/zlib/dictionary_set.zig", ROOT / "tools/zlib/dictionary_resume_probe.zig", Path(__file__).resolve()]},
                  "dictionaries": {name: {"bytes": len(data), "id": zlib.adler32(data), "sha256": digest(data),
                                          "suffix32k_id": zlib.adler32(data[-32768:])} for name, data in dictionaries.items()},
                  "corpus_streams": len(corpus), "dictionary_requests": len(requests), "rows": rows}
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(f"zlib_dictionary_resume_cases={len(rows)} Python_zlib={zlib.ZLIB_RUNTIME_VERSION} "
              f"generated_FDICT_streams={len(corpus)} dictionary_requests={len(requests)} "
              f"wrong_dictionary_rejections={sum(request['wrong_dictionary_attempts'] for request in requests)} "
              f"terminal_errors={sum(row['error'] is not None for row in rows)}")


if __name__ == "__main__":
    main()
