#!/usr/bin/env python3
"""Small Zstd CLI search-control gate with an independently built old codec."""

import argparse
import ctypes
import ctypes.util
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import random
import subprocess


OLD_REVISION = "97c4ad9956e7d8f4a9ffb1a690bf341ab1fc3ef4"
OPTIMAL = ("btopt", "btultra", "btultra2")
FILE_COMMANDS = ("encode-zstd-native-file", "encode-zstd-level-file", "encode-zstd-native-stream-file")
U64_MAX = 18446744073709551615


def digest(data):
    return hashlib.sha256(data).hexdigest()


def samples():
    rng = random.Random(0x48515343)
    return {
        "empty": b"", "tiny": b"a",
        "repeated": b"HQ alpha beta 0123456789\n" * 10,
        "mixed": rng.randbytes(40) + b"prefix alpha beta alpha gamma\n" * 6 + rng.randbytes(40),
    }


class Reference:
    def __init__(self):
        path = ctypes.util.find_library("zstd")
        if path is None:
            raise RuntimeError("libzstd is required for independent frame decoding")
        self.library = ctypes.CDLL(path)
        self.library.ZSTD_versionString.restype = ctypes.c_char_p
        self.version = self.library.ZSTD_versionString().decode()
        self.library.ZSTD_decompress.argtypes = (ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
        self.library.ZSTD_decompress.restype = ctypes.c_size_t
        self.library.ZSTD_isError.argtypes = (ctypes.c_size_t,)
        self.library.ZSTD_isError.restype = ctypes.c_uint

    def decode(self, frame, expected):
        output = ctypes.create_string_buffer(max(1, len(expected)))
        source = ctypes.create_string_buffer(frame)
        size = self.library.ZSTD_decompress(output, len(expected), source, len(frame))
        assert not self.library.ZSTD_isError(size), "libzstd rejected the frame"
        assert size == len(expected) and output.raw[:size] == expected, "decoded bytes differ"


def profile(log, prefix):
    lines = [line for line in log.decode().splitlines() if line.startswith(prefix + " ")]
    assert len(lines) == 1, (prefix, lines)
    result = {}
    for token in lines[0].split()[1:]:
        key, value = token.split("=", 1)
        result[key] = value == "true" if value in ("true", "false") else int(value) if value.isdecimal() else value
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", required=True, type=Path)
    legacy = parser.add_mutually_exclusive_group(required=True)
    legacy.add_argument("--legacy-cli", type=Path, help="Old thin CLI with the same encode commands")
    legacy.add_argument("--legacy-probe", type=Path, help="Old hq_controls_probe using input/output/config JSON")
    parser.add_argument("--legacy-revision", required=True, choices=(OLD_REVISION,))
    parser.add_argument("--legacy-source-archive", required=True, type=Path)
    parser.add_argument("--legacy-binding", type=Path, help="Optional source/build binding JSON from the independent legacy build")
    parser.add_argument("--output-dir", required=True, type=Path, help="New evidence directory; existing directories are refused")
    parser.add_argument("--timeout", type=int, default=60, help="Maximum seconds per small invocation")
    args = parser.parse_args()
    cli = args.cli.resolve(strict=True)
    old = (args.legacy_cli or args.legacy_probe).resolve(strict=True)
    archive = args.legacy_source_archive.resolve(strict=True)
    assert cli != old and digest(cli.read_bytes()) != digest(old.read_bytes()), "legacy codec must be an independent binary"
    folder = args.output_dir.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    corpus = samples()
    report = {
        "schema": "vort-zstd-hq-search-cli-v1", "utc": datetime.now(timezone.utc).isoformat(),
        "cli": {"path": str(cli), "sha256": digest(cli.read_bytes())},
        "legacy": {"path": str(old), "sha256": digest(old.read_bytes()), "revision": args.legacy_revision,
                   "source_archive": str(archive), "source_archive_sha256": digest(archive.read_bytes()),
                   "surface": "cli" if args.legacy_cli else "hq_controls_probe"},
        "samples": {name: {"bytes": len(data), "sha256": digest(data)} for name, data in corpus.items()},
        "round_trips": 0, "legacy_wire_checks": 0, "profile_wire_checks": 0,
        "cap_boundaries": [], "output_preserved": 0, "invocations": [],
        "dictionary_cli_cases": 0, "seekable_cli_cases": 0,
    }
    if args.legacy_binding:
        binding = json.loads(args.legacy_binding.read_text())
        assert binding["revision"] == args.legacy_revision
        assert binding["archive_sha256"] == report["legacy"]["source_archive_sha256"]
        assert binding.get("probe_sha256", binding.get("cli_sha256")) == report["legacy"]["sha256"]
        (folder / "legacy-binding.json").write_text(json.dumps(binding, indent=2) + "\n")
        report["legacy"]["binding_sha256"] = digest(args.legacy_binding.read_bytes())
        report["legacy"]["binding"] = "legacy-binding.json"
    paths = {}
    for name, data in corpus.items():
        paths[name] = folder / (name + ".raw")
        paths[name].write_bytes(data)
    output = folder / "output.zst"

    def run(binary, command, positional, flags=()):
        argv = [str(binary)] + ([command] if command else []) + [str(value) for value in positional] + list(flags)
        result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=args.timeout)
        number = len(report["invocations"])
        log_path = folder / f"call-{number:03d}"
        log_path.with_suffix(".stdout").write_bytes(result.stdout)
        log_path.with_suffix(".stderr").write_bytes(result.stderr)
        report["invocations"].append({"argv": argv, "returncode": result.returncode, "log_prefix": log_path.name})
        return result

    def encode(command, positional, flags, expected, destination=output):
        result = run(cli, command, positional, flags)
        assert result.returncode == 0, (command, flags, result.stderr.decode(errors="replace"))
        frame = bytes.fromhex(result.stdout.decode().splitlines()[0]) if command.endswith("hex") else destination.read_bytes()
        reference.decode(frame, expected)
        assert (b"zstd_profile " in result.stdout) == ("--profile" in flags)
        assert (b"zstd_search_profile " in result.stdout) == ("--profile" in flags)
        report["round_trips"] += 1
        return frame, result.stdout

    def failure(command, flags, error_name, same_path=False, absent=False):
        sentinel = corpus["repeated"] if same_path else b"existing output survives rejected search controls\n"
        destination = folder / "same-path.raw" if same_path else output
        destination.write_bytes(sentinel)
        source = destination if same_path else folder / "absent.raw" if absent else paths["repeated"]
        result = run(cli, command, (source, destination), flags)
        assert result.returncode != 0 and error_name.encode() in result.stderr, (command, flags, result.stderr)
        assert destination.read_bytes() == sentinel, (command, flags, "destination changed after failure")
        report["output_preserved"] += 1

    try:
        reference = Reference()
        report["reference_zstd"] = reference.version
        # Freeze wires with the old binary before asking the product for any expected wire.
        frozen = []
        for name, data in corpus.items():
            for strategy in (None, "auto", "lazy2", "btlazy2", *OPTIMAL):
                flags = () if strategy is None else (f"--strategy={strategy}",)
                old_output = folder / f"legacy-{name}-{strategy or 'default'}.zst"
                if args.legacy_cli:
                    result = run(old, FILE_COMMANDS[0], (paths[name], old_output), flags)
                    assert result.returncode == 0, result.stderr
                else:
                    config = folder / f"legacy-{name}-{strategy or 'default'}.json"
                    config.write_text(json.dumps({"mode": "native-default" if strategy is None else "level", "level": 1,
                                                  "strategy": strategy or "auto", "checksum": True, "profile_enabled": False}) + "\n")
                    result = run(old, None, (paths[name], old_output, config))
                    assert result.returncode == 0 and json.loads(result.stdout)["error"] is None, result.stdout
                frame = old_output.read_bytes()
                reference.decode(frame, data)
                frozen.append({"sample": name, "args": flags, "wire": old_output.name, "bytes": len(frame), "sha256": digest(frame)})
        (folder / "legacy-wire.json").write_text(json.dumps(frozen, indent=2) + "\n")
        for row in frozen:
            expected = corpus[row["sample"]]
            for instrumented in (False, True):
                flags = tuple(row["args"]) + (("--profile",) if instrumented else ())
                frame, _ = encode(FILE_COMMANDS[0], (paths[row["sample"]], output), flags, expected)
                assert len(frame) == row["bytes"] and digest(frame) == row["sha256"], row
                report["legacy_wire_checks"] += 1
            if row["args"] and row["args"][0].removeprefix("--strategy=") in ("lazy2", "btlazy2", *OPTIMAL):
                flags = tuple(row["args"]) + ("--hq-parse-mode=bounded", "--hq-match-lengths=sampled", "--profile")
                frame, _ = encode(FILE_COMMANDS[0], (paths[row["sample"]], output), flags, expected)
                assert len(frame) == row["bytes"] and digest(frame) == row["sha256"], row
                report["legacy_wire_checks"] += 1

        # All four policy combinations are independent; B is observed per actual plan.
        payload = corpus["repeated"]
        for strategy in OPTIMAL:
            for mode in ("bounded", "whole_block"):
                for lengths in ("sampled", "complete"):
                    flags = (f"--strategy={strategy}", f"--hq-parse-mode={mode}", f"--hq-match-lengths={lengths}")
                    plain, _ = encode(FILE_COMMANDS[0], (paths["repeated"], output), flags, payload)
                    measured, log = encode(FILE_COMMANDS[0], (paths["repeated"], output), flags + ("--profile",), payload)
                    assert plain == measured, "profile changed the wire"
                    report["profile_wire_checks"] += 1
                    search = profile(log, "zstd_search_profile")
                    assert search["parse_mode"] == mode and search["match_lengths"] == lengths and search["max_prices"] == "unlimited", search
                    assert search[f"{mode}_passes"] > 0 and search[f"{lengths}_length_passes"] > 0, search
                    boundary = search["max_plan_price_evaluations"]
                    assert boundary > 0, search
                    if mode == "whole_block" or lengths == "complete":
                        assert search["baseline_searches"] > 0 and search["guarded_frames"] > 0, search
                    capped, capped_log = encode(FILE_COMMANDS[0], (paths["repeated"], output), flags + (f"--hq-max-prices={boundary}", "--profile"), payload)
                    assert capped == plain, "an exact sufficient cap changed the wire"
                    capped_search = profile(capped_log, "zstd_search_profile")
                    assert capped_search["max_prices"] == boundary and capped_search["max_plan_price_evaluations"] <= boundary, capped_search
                    failure(FILE_COMMANDS[0], flags + (f"--hq-max-prices={boundary - 1}",), "SearchLimitExceeded")
                    failure(FILE_COMMANDS[0], flags + ("--hq-max-prices=0",), "SearchLimitExceeded")
                    report["cap_boundaries"].append({"strategy": strategy, "parse_mode": mode, "match_lengths": lengths,
                                                     "B": boundary, "B_success": True, "B_minus_1_failure": True, "zero_failure": True,
                                                     "profile": search})

        # The same common resolver feeds every existing CLI consumer.
        flags = ("--strategy=btultra2", "--hq-parse-mode=whole_block", "--hq-match-lengths=complete", f"--hq-max-prices={U64_MAX}")
        for command, positional, data in (
            ("encode-zstd-native-hex", (payload.decode(),), payload),
            ("encode-zstd-native-bytes-hex", (corpus["mixed"].hex(),), corpus["mixed"]),
            ("encode-zstd-native-file-hex", (paths["mixed"],), corpus["mixed"]),
            *((command, (paths["repeated"], output), payload) for command in FILE_COMMANDS),
        ):
            plain, _ = encode(command, positional, flags, data)
            measured, log = encode(command, positional, flags + ("--profile",), data)
            assert plain == measured
            assert profile(log, "zstd_search_profile")["max_prices"] == U64_MAX
            report["profile_wire_checks"] += 1

        # Rejections precede input I/O, and runtime refusal preserves both outputs and same-path sources.
        for strategy in ("auto", "fast", "double_fast", "greedy", "lazy", "optimal", "lazy2", "btlazy2"):
            for control in ("--hq-parse-mode=whole_block", "--hq-match-lengths=complete", "--hq-max-prices=0"):
                failure(FILE_COMMANDS[0], (f"--strategy={strategy}", control), "InvalidBlockPlan")
        for command in FILE_COMMANDS:
            failure(command, ("--strategy=lazy2", "--hq-match-lengths=complete"), "InvalidBlockPlan", absent=True)
            failure(command, ("--strategy=btopt", "--hq-max-prices=0"), "SearchLimitExceeded", same_path=True)
            failure(command, ("--strategy=btopt", "--hq-max-prices=0", "--hq-max-prices=1"), "DuplicateZstdOption")
            same = folder / "same-path-success.raw"
            same.write_bytes(payload)
            encode(command, (same, same), flags, payload, destination=same)
        report["status"] = "passed"
    except Exception as error:
        report["status"] = "failed"
        report["failure"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        (folder / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({key: report[key] for key in ("status", "round_trips", "legacy_wire_checks", "profile_wire_checks", "output_preserved", "reference_zstd")}))


if __name__ == "__main__":
    main()
