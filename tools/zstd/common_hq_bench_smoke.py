#!/usr/bin/env python3
"""Bounded public common-HQ benchmark and evidence/CLI integration contracts."""

from __future__ import annotations

import argparse
import csv
import ctypes as C
import hashlib
import itertools
import json
from pathlib import Path
import random
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "tools/codec_bench"))
from sample_gate import validate
from zstd_common_parameters_smoke import negative_contracts, dictionary_negative_contracts


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def train_dictionary(library: Path, directory: Path) -> tuple[Path, Path]:
    """A small independent standard dictionary; no existing /tmp state needed."""
    runtime = C.CDLL(str(library))
    train = runtime.ZDICT_trainFromBuffer
    train.argtypes = [C.c_void_p, C.c_size_t, C.c_void_p, C.POINTER(C.c_size_t), C.c_uint]
    train.restype = C.c_size_t
    is_error = runtime.ZDICT_isError
    is_error.argtypes = [C.c_size_t]
    is_error.restype = C.c_uint
    samples = [(f"service=vort region={i % 7} status=complete key={i} message=bounded common HQ dictionary\n" * 6).encode()
               for i in range(64)]
    joined = b"".join(samples)
    sizes = (C.c_size_t * len(samples))(*map(len, samples))
    output = C.create_string_buffer(1024)
    count = train(output, len(output), joined, sizes, len(samples))
    assert not is_error(count), f"dictionary training failed: {count}"
    dictionary = directory / "standard.dict"
    dictionary.write_bytes(output.raw[:count])
    source = directory / "standard-source.bin"
    source.write_bytes((samples[31] * 3)[:1536])
    return dictionary, source


def fixtures(library: Path, directory: Path) -> dict:
    first = directory / "plain-512.bin"
    second = directory / "plain-2048.bin"
    source = (ROOT / "src/zstd/match/hq_parser/prices.zig").read_bytes()
    first.write_bytes(source[:512])
    second.write_bytes(source[:2048])
    raw = directory / "raw.dict"
    raw_bytes = random.Random(0x5A737464).randbytes(1536)
    raw.write_bytes(raw_bytes)
    raw_source = directory / "raw-source.bin"
    raw_source.write_bytes(raw_bytes[256:1280])
    full, full_source = train_dictionary(library, directory)
    return {"plain": [first, second], "raw": (raw, raw_source), "full": (full, full_source)}


def run_case(executable: Path, library: Path, directory: Path, name: str, paths: list[Path],
             strategy: str, window: int, checksum: bool, fcs: bool, dictionary: Path | None = None) -> tuple:
    csv_path, json_path = directory / f"{name}.csv", directory / f"{name}.json"
    command = [str(executable), "--match-hq", "--strategy", strategy, "--window-log", str(window),
               "--content-checksum", str(checksum).lower(), "--content-size", str(fcs).lower(),
               "--iterations", "1", "--rounds", "2", "--csv", str(csv_path),
               "--samples-json", str(json_path), "--libzstd", str(library)]
    for path in paths:
        command += ["--path", str(path)]
    if dictionary is not None:
        command += ["--dictionary", str(dictionary)]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, (name, result.stdout, result.stderr)
    report = json.loads(json_path.read_text())
    with csv_path.open(newline="") as handle:
        csv_rows = list(csv.DictReader(handle))
    manifest = {"input_sets": [{"frozen_path": str(path), "input_bytes": path.stat().st_size,
                                "input_sha256": digest(path.read_bytes())} for path in paths]}
    if dictionary is not None:
        manifest["dictionary_sets"] = [{"frozen_path": str(dictionary),
                                        "dictionary_bytes": dictionary.stat().st_size,
                                        "dictionary_sha256": digest(dictionary.read_bytes())}]
    (directory / f"{name}.manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    checked = validate(report, manifest, csv_rows=csv_rows, executable=executable, require_explicit_references=True)
    assert checked["rounds"] == len(paths) * 2
    assert len(report["rows"]) == len(paths)
    assert report["provenance"]["codec_thread_policy"] == "single"
    assert report["provenance"]["benchmark_threads"] == 1
    for row in report["rows"]:
        settings = row["settings"]
        params = settings["reference"]["requested_parameters"]
        assert params["hash_log"] == params["chain_log"] == 0  # Default sentinels, not table sizes.
        assert params["strategy"] == {"btopt": 7, "btultra2": 9}[strategy]
        assert params["window_log"] == window and params["search_log"] == 6
        assert params["min_match"] == 3 and params["target_length"] == 64 and params["workers"] == 0
        assert params["checksum"] == int(checksum) and params["content_size"] == int(fcs)
        assert settings["resolved_primary"]["control_profile_enabled"] is False
        assert settings["vort_profile"]["hq_used"] is True
        if dictionary is not None:
            assert settings["dictionary_sha256"] == digest(dictionary.read_bytes())
            assert settings["dictionary_bytes"] == dictionary.stat().st_size
    return report, manifest, csv_rows


def cli_rejections(executable: Path, library: Path, directory: Path, source: Path) -> int:
    base = ["--match-hq", "--strategy", "btopt", "--window-log", "15", "--path", str(source),
            "--iterations", "1", "--rounds", "2", "--libzstd", str(library)]
    invalid = [
        ([], ["--strategy", "btultra2"]),
        ([], ["--hq-search-depth", "1"]),
        ([], ["--hq-search-depth", "65"]),
        ([], ["--hq-min-match", "5"]),
        ([], ["--block-size", "4096"]),
        ([], ["--fast-acceleration", "1"]),
        ([], ["--native-selection", "fast_compressed"]),
        (["--strategy", "btopt"], []),
        (["--libzstd", str(library)], []),
        (["--samples-json"], []),
    ]
    flags = [("--window-log", "15"), ("--block-size", "32768"), ("--hq-search-depth", "64"),
             ("--hq-nice-len", "64"), ("--hq-min-match", "3"), ("--content-checksum", "false"),
             ("--content-size", "false"), ("--dictionary", str(source))]
    invalid += [(["--match-hq", "--window-log", "15"], list(flag)) for flag in flags]
    for index, (removed, extra) in enumerate(invalid):
        csv_path, json_path = directory / f"invalid-{index}.csv", directory / f"invalid-{index}.json"
        command = base + ["--csv", str(csv_path), "--samples-json", str(json_path)]
        for option in removed:
            if option == "--samples-json":
                at = command.index(option)
                del command[at:at + 2]
                continue
            command.remove(option)
        command += extra
        before = b"existing output sentinel\n"
        if index % 2 == 0:
            csv_path.write_bytes(before)
            json_path.write_bytes(before)
        else:
            csv_path.unlink(missing_ok=True)
            json_path.unlink(missing_ok=True)
        result = subprocess.run([str(executable), *command], cwd=ROOT, capture_output=True, timeout=30)
        assert result.returncode != 0, (index, command, result.stdout, result.stderr)
        if index % 2 == 0:
            assert csv_path.read_bytes() == json_path.read_bytes() == before, (index, "failed CLI wrote output")
        else:
            assert not csv_path.exists() and not json_path.exists(), (index, "failed CLI created output")
    return len(invalid)


def alias_rejections(executable: Path, library: Path, directory: Path, source: Path, dictionary: Path) -> int:
    # Exercise library aliases against a private copy, preserving the actual
    # installed reference even if the benchmark's rejection were to regress.
    private_library = directory / "alias-reference.so"
    private_library.write_bytes(library.read_bytes())
    protected = (("source", source), ("dictionary", dictionary), ("library", private_library))
    checked = 0
    for kind, path in protected:
        before = path.read_bytes()
        for output in ("--csv", "--samples-json"):
            other = directory / f"alias-{kind}-{output[2:]}.new"
            other.unlink(missing_ok=True)
            command = [str(executable), "--match-hq", "--strategy", "btopt", "--window-log", "15",
                       "--path", str(source), "--dictionary", str(dictionary),
                       "--libzstd", str(private_library), "--iterations", "1", "--rounds", "2",
                       "--csv", str(path if output == "--csv" else other),
                       "--samples-json", str(path if output == "--samples-json" else other)]
            result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=30)
            assert result.returncode != 0, (kind, output, result.stdout, result.stderr)
            assert path.read_bytes() == before and not other.exists(), (kind, output, "alias wrote output")
            checked += 1
    same = directory / "alias-csv-json.new"
    same.unlink(missing_ok=True)
    command = [str(executable), "--match-hq", "--strategy", "btopt", "--path", str(source),
               "--libzstd", str(private_library), "--csv", str(same), "--samples-json", str(same)]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=30)
    assert result.returncode != 0 and not same.exists(), "CSV/JSON alias created output"
    return checked + 1


def campaign(executable: Path, library: Path, directory: Path) -> dict:
    data = fixtures(library, directory)
    commands = 0
    anchor = None
    for strategy, window, flag in itertools.product(("btopt", "btultra2"), (15, 17), (False, True)):
        report = run_case(executable, library, directory, f"plain-{strategy}-{window}-{flag}",
                          data["plain"], strategy, window, flag, flag)
        anchor = anchor or report
        commands += 1
    for checksum, fcs in ((True, False), (False, True)):
        run_case(executable, library, directory, f"mixed-flags-{checksum}", data["plain"][:1],
                 "btopt", 15, checksum, fcs)
        commands += 1
    dictionary_refs = 0
    dictionary_rejections = 0
    for kind in ("raw", "full"):
        dictionary, source = data[kind]
        for strategy, window in (("btopt", 15), ("btultra2", 17)):
            report, manifest, rows = run_case(executable, library, directory, f"{kind}-{strategy}", [source],
                                            strategy, window, True, True, dictionary)
            assert report["rows"][0]["settings"]["dictionary_kind"] == ("raw_content" if kind == "raw" else "standard_full")
            dictionary_refs += report["rows"][0]["settings"]["vort_profile"]["dictionary_sequences"]
            if strategy == "btopt":
                dictionary_rejections += dictionary_negative_contracts(report, manifest, rows)
            commands += 1
    assert dictionary_refs > 0, "dictionary fixtures emitted no actual dictionary references"
    return {"status": "ok", "commands": commands, "rows": 22, "dictionary_references": dictionary_refs,
            "cli_rejections": cli_rejections(executable, library, directory, data["plain"][0])
                              + alias_rejections(executable, library, directory, data["plain"][0], data["raw"][0]),
            "dictionary_evidence_rejections": dictionary_rejections,
            "evidence_rejections": negative_contracts(*anchor)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("--libzstd", type=Path)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    library = args.libzstd or Path.home() / "Work/zstd/lib/libzstd.so.1.6.0"
    if args.libzstd is None and not library.is_file():
        library = Path("/lib/x86_64-linux-gnu/libzstd.so.1")
    library = library.resolve(strict=True)
    executable = args.executable.resolve(strict=True)
    if args.output_dir:
        directory = args.output_dir.resolve()
        directory.mkdir(parents=True, exist_ok=True)
        summary = campaign(executable, library, directory)
        (directory / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    else:
        with tempfile.TemporaryDirectory(prefix="vort-zstd-common-hq-") as temporary:
            summary = campaign(executable, library, Path(temporary))
    print("zstd_common_hq_bench_smoke=" + json.dumps(summary, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
