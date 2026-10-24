#!/usr/bin/env python3
"""Small stored Brotli CLI resource checks against an independently frozen codec."""

import argparse
import ctypes
import ctypes.util
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess


OLD_REVISION = "3703184975920d44ed3e781f0e562f45cfe31fa5"
COMMANDS = ("encode-br-stored-file", "encode-br-stored-hex")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def cases():
    text = b"stored memory CLI alpha beta alpha beta\n"
    return (
        {"name": "empty", "payload": b"", "flags": (), "width": 16, "large": False, "metadata": ""},
        {"name": "tiny", "payload": b"x", "flags": (), "width": 16, "large": False, "metadata": ""},
        {"name": "standard10", "payload": text, "flags": ("10", "legacy metadata"), "width": 10, "large": False, "metadata": "legacy metadata"},
        {"name": "standard24", "payload": text * 3, "flags": ("--window-bits=24", "--metadata=header metadata"), "width": 24, "large": False, "metadata": "header metadata"},
        {"name": "large10", "payload": b"", "flags": ("--large-window", "--window-bits=10", "--metadata=empty extension"), "width": 10, "large": True, "metadata": "empty extension"},
        {"name": "large30", "payload": text * 2, "flags": ("30", "large metadata", "--large-window"), "width": 30, "large": True, "metadata": "large metadata"},
    )


def header(wire):
    assert wire, "empty wire"
    first = wire[0]
    if first & 1 == 0:
        return 16, False
    upper = (first >> 1) & 7
    if upper:
        return 17 + upper, False
    lower = (first >> 4) & 7
    if lower != 1:
        return 17 if lower == 0 else 8 + lower, False
    assert len(wire) >= 2 and first & 128 == 0
    width = wire[1] & 63
    assert 10 <= width <= 30
    return width, True


class Reference:
    def __init__(self):
        path = ctypes.util.find_library("brotlidec")
        if path is None:
            raise RuntimeError("libbrotlidec is required for independent decoding")
        self.lib = ctypes.CDLL(path)
        self.lib.BrotliDecoderVersion.restype = ctypes.c_uint
        self.version = self.lib.BrotliDecoderVersion()
        self.lib.BrotliDecoderCreateInstance.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p)
        self.lib.BrotliDecoderCreateInstance.restype = ctypes.c_void_p
        self.lib.BrotliDecoderDestroyInstance.argtypes = (ctypes.c_void_p,)
        self.lib.BrotliDecoderSetParameter.argtypes = (ctypes.c_void_p, ctypes.c_int, ctypes.c_uint)
        self.lib.BrotliDecoderSetParameter.restype = ctypes.c_int
        self.lib.BrotliDecoderDecompressStream.argtypes = (
            ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t), ctypes.POINTER(ctypes.c_void_p),
            ctypes.POINTER(ctypes.c_size_t), ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_size_t),
        )
        self.lib.BrotliDecoderDecompressStream.restype = ctypes.c_int

    def decode(self, encoded, expected, large=False, strict=False):
        state = self.lib.BrotliDecoderCreateInstance(None, None, None)
        assert state
        try:
            if large and not strict:
                assert self.lib.BrotliDecoderSetParameter(state, 1, 1) == 1, "reference rejected Large Window opt-in"
            source = ctypes.create_string_buffer(encoded)
            output = ctypes.create_string_buffer(max(1, len(expected)))
            available_in, available_out = ctypes.c_size_t(len(encoded)), ctypes.c_size_t(len(expected))
            next_in, next_out = ctypes.c_void_p(ctypes.addressof(source)), ctypes.c_void_p(ctypes.addressof(output))
            status = self.lib.BrotliDecoderDecompressStream(state, ctypes.byref(available_in), ctypes.byref(next_in), ctypes.byref(available_out), ctypes.byref(next_out), None)
            if large and strict:
                assert status == 0, "strict reference accepted Large Window wire"
                return
            assert status == 1 and available_in.value == 0 and available_out.value == 0, (status, available_in.value, available_out.value)
            assert output.raw[:len(expected)] == expected, "reference decoded bytes differ"
        finally:
            self.lib.BrotliDecoderDestroyInstance(state)


def memory_profile(log):
    lines = [line for line in log.decode().splitlines() if line.startswith("br_memory_profile ")]
    assert len(lines) == 1, lines
    result = {}
    for token in lines[0].split()[1:]:
        key, value = token.split("=", 1)
        result[key] = value == "true" if value in ("true", "false") else None if value == "unlimited" else int(value)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--legacy-probe", required=True, type=Path, help="Old original general_large_window_probe input/output/config interface")
    parser.add_argument("--legacy-revision", required=True, choices=(OLD_REVISION,))
    parser.add_argument("--legacy-source-archive", required=True, type=Path)
    parser.add_argument("--legacy-binding", type=Path)
    parser.add_argument("--output-dir", required=True, type=Path, help="New evidence directory; refuses existing directories")
    parser.add_argument("--timeout", type=int, default=30)
    args = parser.parse_args()
    cli, old = args.cli.resolve(strict=True), args.legacy_probe.resolve(strict=True)
    archive = args.legacy_source_archive.resolve(strict=True)
    assert cli != old and digest(cli.read_bytes()) != digest(old.read_bytes()), "old baseline must use an independent codec binary"
    folder = args.output_dir.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    report = {
        "schema": "vort-br-stored-memory-cli-v1", "utc": datetime.now(timezone.utc).isoformat(),
        "cli": {"path": str(cli), "sha256": digest(cli.read_bytes())},
        "legacy": {"path": str(old), "sha256": digest(old.read_bytes()), "revision": args.legacy_revision,
                   "source_archive": str(archive), "source_archive_sha256": digest(archive.read_bytes()),
                   "surface": "old original general_large_window_probe"},
        "round_trips": 0, "legacy_wire_checks": 0, "profile_wire_checks": 0, "exact_cap_checks": 0,
        "one_below_checks": 0, "zero_cap_checks": 0, "output_preserved": 0, "same_path_checks": 0,
        "aliases_equal": 0, "measurements": [], "invocations": [],
        "scope": "two existing complete-input stored CLI commands; encoder heap only, borrowed input and caller I/O excluded",
    }
    if args.legacy_binding:
        binding = json.loads(args.legacy_binding.read_text())
        assert binding["revision"] == args.legacy_revision
        assert binding["archive_sha256"] == report["legacy"]["source_archive_sha256"]
        assert binding["general_probe_sha256"] == report["legacy"]["sha256"]
        (folder / "legacy-binding.json").write_text(json.dumps(binding, indent=2) + "\n")
        report["legacy"]["binding_sha256"] = digest(args.legacy_binding.read_bytes())
    corpus = cases()
    paths = {}
    for case in corpus:
        paths[case["name"]] = folder / (case["name"] + ".raw")
        paths[case["name"]].write_bytes(case["payload"])
    output = folder / "output.br"

    def run(binary, command, positional, flags=()):
        argv = [str(binary)] + ([command] if command else []) + [str(value) for value in positional] + list(flags)
        result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=args.timeout)
        log = folder / f"call-{len(report['invocations']):03d}"
        log.with_suffix(".stdout").write_bytes(result.stdout)
        log.with_suffix(".stderr").write_bytes(result.stderr)
        report["invocations"].append({"argv": argv, "returncode": result.returncode, "log_prefix": log.name})
        return result

    def success(command, case, flags, source=None, destination=output):
        positions = (source or paths[case["name"]], destination) if command.endswith("file") else (case["payload"].decode(),)
        result = run(cli, command, positions, flags)
        assert result.returncode == 0, (command, flags, result.stderr.decode(errors="replace"))
        encoded = destination.read_bytes() if command.endswith("file") else bytes.fromhex(result.stdout.decode().splitlines()[0])
        reference.decode(encoded, case["payload"], case["large"])
        assert header(encoded) == (case["width"], case["large"]), (header(encoded), case)
        assert (b"br_memory_profile " in result.stdout) == ("--memory-profile" in flags)
        assert b"br_hq_profile " not in result.stdout, "stored instrumentation selected HQ"
        report["round_trips"] += 1
        return encoded, result.stdout

    def failure(command, flags, error, same_path=False, absent=False, case=None):
        sentinel = b"preserve source and output on stored resource rejection\n"
        destination = folder / "same-path.raw" if same_path else output
        destination.write_bytes(sentinel)
        source = destination if same_path else folder / "absent.raw" if absent else paths[case["name"] if case else "standard10"]
        payload = case["payload"].decode() if case else "stored rejection payload"
        positions = (source, destination) if command.endswith("file") else (payload,)
        result = run(cli, command, positions, flags)
        assert result.returncode != 0 and error.encode() in result.stderr, (command, flags, result.stderr)
        assert destination.read_bytes() == sentinel, (command, flags, "output changed after rejection")
        if command.endswith("file"):
            report["output_preserved"] += 1
        if same_path:
            report["same_path_checks"] += 1

    try:
        reference = Reference()
        report["reference_brotli_version"] = reference.version
        # All baseline bytes originate in the independently built original old public probe.
        frozen = []
        for case in corpus:
            config = folder / ("legacy-" + case["name"] + ".json")
            config.write_text(json.dumps({"codec": "stored", "api": "one_shot", "window_bits": case["width"],
                                          "large_window": case["large"], "metadata": case["metadata"], "total_profile_enabled": False}) + "\n")
            wire = folder / ("legacy-" + case["name"] + ".br")
            result = run(old, None, (paths[case["name"]], wire, config))
            assert result.returncode == 0 and json.loads(result.stdout)["error"] is None, result.stdout
            encoded = wire.read_bytes()
            reference.decode(encoded, case["payload"], case["large"])
            if case["large"]:
                reference.decode(encoded, case["payload"], large=True, strict=True)
            frozen.append({"name": case["name"], "input_bytes": len(case["payload"]), "input_sha256": digest(case["payload"]),
                           "wire": wire.name, "wire_bytes": len(encoded), "wire_sha256": digest(encoded)})
        (folder / "legacy-wire.json").write_text(json.dumps(frozen, indent=2) + "\n")

        for command in COMMANDS:
            for case, row in zip(corpus, frozen):
                plain, _ = success(command, case, case["flags"])
                measured, log = success(command, case, case["flags"] + ("--memory-profile",))
                assert digest(plain) == row["wire_sha256"] and len(plain) == row["wire_bytes"], row
                assert measured == plain, "memory profile changed stored wire"
                report["legacy_wire_checks"] += 2
                report["profile_wire_checks"] += 1
                sample = memory_profile(log)
                assert sample["available"] and sample["peak_requested_bytes"] > 0 and sample["live_requested_bytes"] == 0 and sample["limit"] is None, sample
                boundary = sample["peak_requested_bytes"]
                capped, capped_log = success(command, case, case["flags"] + (f"--max-total-memory={boundary}", "--memory-profile"))
                exact = memory_profile(capped_log)
                assert capped == plain and exact["available"] and exact["peak_requested_bytes"] == boundary and exact["live_requested_bytes"] == 0 and exact["limit"] == boundary, exact
                report["exact_cap_checks"] += 1
                failure(command, case["flags"] + (f"--max-total-memory={boundary - 1}",), "WorkingMemoryLimitExceeded", case=case)
                report["one_below_checks"] += 1
                failure(command, case["flags"] + ("--max-total-memory=0",), "WorkingMemoryLimitExceeded", case=case)
                report["zero_cap_checks"] += 1
                report["measurements"].append({"command": command, "case": case["name"], "B": boundary, "B_success": True,
                                               "B_minus_1_failure": True, "zero_failure": True, "profile": sample})

            bad = (("--max-total-memory", "MissingBrotliOptionValue"), ("--max-total-memory=", "InvalidCharacter"),
                   ("--max-total-memory=-1", "Overflow"), ("--quality=0", "UnsupportedBrotliStoredOption"),
                   ("--hq", "UnsupportedBrotliStoredOption"), ("--profile", "UnsupportedBrotliStoredOption"),
                   ("--window-bits=30", "InvalidBlockPlan"), ("--dictionary=absent", "UnknownBrotliOption"))
            for flag, error in bad:
                failure(command, (flag,), error, absent=command.endswith("file"))
            failure(command, ("--max-total-memory=0", "--max-total-memory=1"), "DuplicateBrotliOption")
            failure(command, ("--memory-profile", "--memory-profile"), "DuplicateBrotliOption")
            failure(command, ("--max-input-len=0",), "UnsupportedBrotliStoredOption")

        # Named and positional aliases preserve metadata/window wire; resource flag order is independent.
        case = corpus[2]
        named = ("--memory-profile", "--max-total-memory", "4294967295", "--window-bits", "10", "--metadata", "legacy metadata")
        for command in COMMANDS:
            encoded, log = success(command, case, named)
            assert digest(encoded) == frozen[2]["wire_sha256"]
            assert memory_profile(log)["limit"] == 4294967295
            report["aliases_equal"] += 1
        same = folder / "same-success.raw"
        same.write_bytes(case["payload"])
        success(COMMANDS[0], case, case["flags"] + ("--memory-profile",), source=same, destination=same)
        report["same_path_checks"] += 1
        failure(COMMANDS[0], ("--max-total-memory=0",), "WorkingMemoryLimitExceeded", same_path=True)
        failure(COMMANDS[0], ("--quality=0", "--memory-profile"), "UnsupportedBrotliStoredOption", same_path=True)
        omitted = run(cli, COMMANDS[1], (), ("--memory-profile",))
        assert omitted.returncode == 0, omitted.stderr
        reference.decode(bytes.fromhex(omitted.stdout.decode().splitlines()[0]), b"")
        assert memory_profile(omitted.stdout)["live_requested_bytes"] == 0
        report["round_trips"] += 1
        report["status"] = "passed"
    except Exception as error:
        report["status"] = "failed"
        report["failure"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        (folder / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({key: report[key] for key in ("status", "round_trips", "legacy_wire_checks", "profile_wire_checks", "exact_cap_checks", "one_below_checks", "zero_cap_checks", "output_preserved", "same_path_checks")}))


if __name__ == "__main__":
    main()
