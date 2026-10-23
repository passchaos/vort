#!/usr/bin/env python3
"""CLI LZFSE flag and atomic-output checks using cached public executables."""

import argparse
from contextlib import nullcontext
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import random
import re
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("lzfse_wire", ROOT / "tools/lzfse/diff.py")
wire_format = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wire_format)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def run(*args, success=True):
    result = subprocess.run([str(value) for value in args], cwd=ROOT, capture_output=True)
    if success and result.returncode:
        raise RuntimeError(f"command failed: {' '.join(map(str, args))}\n{result.stderr.decode(errors='replace')}")
    if not success and result.returncode == 0:
        raise AssertionError(f"unexpected command success: {args}")
    return result


def snapshot(directory):
    return {str(path.relative_to(directory)): ("dir" if path.is_dir() else sha256(path.read_bytes()))
            for path in directory.rglob("*")}


def resolve_cli(path, report):
    if path:
        return path.resolve()
    expected = json.loads(report.read_text())["cli_sha256"]
    matches = [candidate for candidate in (ROOT / ".zig-cache/o").glob("*/vort")
               if sha256(candidate.read_bytes()) == expected]
    require(bool(matches), "cached CLI matching --cli-report SHA-256 is unavailable")
    return matches[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", type=Path)
    parser.add_argument("--cli-report", type=Path, default=Path("/tmp/vort-lzfse-cli-diff.json"))
    parser.add_argument("--probe", type=Path, required=True,
                        help="cached public lzfse module probe used to check exact option routing")
    parser.add_argument("--lzfse", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--work-dir", type=Path)
    args = parser.parse_args()
    cli = resolve_cli(args.cli, args.cli_report)
    args.probe, args.lzfse = args.probe.resolve(), args.lzfse.resolve()
    if args.work_dir:
        args.work_dir = args.work_dir.resolve()
        args.work_dir.mkdir(parents=True, exist_ok=True)
        require(not any(args.work_dir.iterdir()), "--work-dir must be empty")
    workspace = nullcontext(str(args.work_dir)) if args.work_dir else tempfile.TemporaryDirectory(prefix="vort-lzfse-cli-flags-")
    rows = []
    rng = random.Random(0xC115E)
    payload = b"\n".join(f'{{"id":{i},"kind":"cli-fse","bucket":{i % 31}}}'.encode() for i in range(2000))
    with workspace as directory:
        temp = Path(directory)

        def verify(output, expected):
            native, apple = temp / "native-restored", temp / "apple-restored"
            run(cli, "decode-lzfse-file", output, native, len(expected))
            run(args.lzfse, "-decode", "-i", output, "-o", apple)
            require(native.read_bytes() == apple.read_bytes() == expected, "CLI/Apple decode equality")

        def successful(name, data, mode="auto", version="v2", block_size=65536, hash_log=15, distance=262139,
                       same_path=False, exact_limits=False, default_mode=False):
            index = len(rows)
            case_dir = temp / f"case-{index}"
            case_dir.mkdir()
            source, output = case_dir / "input", case_dir / "output"
            source.write_bytes(data)
            if same_path:
                output = source
            else:
                output.write_bytes(b"existing output must be atomically replaced")
            reference = temp / "api-expected"
            api = json.loads(run(args.probe, "encode", source, reference, mode, version,
                                 block_size, hash_log, distance).stderr)
            expected = reference.read_bytes()
            before_names = set(snapshot(case_dir))
            command = [cli, "encode-lzfse-file", source, output]
            if not default_mode:
                command += [block_size, mode]
            command += [f"--fse-version={version}", f"--hash-log={hash_log}", f"--max-distance={distance}"]
            if exact_limits:
                command += [f"--output-limit={len(expected)}", f"--working-memory-limit={api['peak_working_bytes']}"]
            result = run(*command)
            wire = output.read_bytes()
            require(wire == expected, (name, "CLI flags/public API exact wire equality"))
            require(set(snapshot(case_dir)) == before_names, (name, "atomic temporary file leaked"))
            stats = {key: int(value) for key, value in re.findall(
                r"(lzfse_input_bytes|compressed_bytes|block_size|v1|v2|peak_working_bytes)=(\d+)",
                result.stdout.decode())}
            require(stats.get("lzfse_input_bytes") == len(data) and stats.get("compressed_bytes") == len(wire),
                    (name, "CLI summary accounting"))
            require(stats.get("v1") == api["fse_v1_blocks"] and stats.get("v2") == api["fse_v2_blocks"],
                    (name, "version summary"))
            require(f"mode={mode}" in result.stdout.decode(), (name, "strategy summary"))
            if version == "v1":
                require(not any(kind == "v2" for kind, _, _, _ in wire_format.scan(wire)), (name, "V1 flag"))
            if mode in ("stored", "lzvn"):
                require(not api["fse_v1_blocks"] and not api["fse_v2_blocks"], (name, "explicit strategy"))
            verify(output, data)
            rows.append({"case": name, "result": "success", "mode": mode, "version": version,
                         "block_size": block_size, "hash_log": hash_log, "max_match_distance": distance,
                         "same_input_output_path": same_path, "exact_limits": exact_limits,
                         "input_sha256": sha256(data), "output_sha256": sha256(wire), **stats})
            return api

        for mode in ("auto", "fse", "lzvn", "stored"):
            for version in ("v1", "v2"):
                successful(f"{mode}-{version}", payload, mode, version)
                successful(f"same-path-{mode}-{version}", payload, mode, version, same_path=True)
        successful("default-mode", payload, default_mode=True)
        for hash_log in (8, 20):
            successful(f"hash-log-{hash_log}", payload, "fse", hash_log=hash_log)
        word = rng.randbytes(512)
        far = word + b"\0" * (262139 - len(word)) + word
        for distance in (1, 31, 262139):
            api = successful(f"distance-{distance}", far, "fse", distance=distance)
            require(api["max_fse_distance"] <= distance, "distance flag match bound")
            if distance == 262139:
                require(api["max_fse_distance"] == distance, "maximum distance flag actual matching")
        successful("block-size-count-driven", payload, "fse", block_size=131072)
        successful("exact-resource-limits", payload, "fse", exact_limits=True)

        baseline_source, baseline_output = temp / "limit-input", temp / "limit-output"
        baseline_source.write_bytes(payload)
        api = json.loads(run(args.probe, "encode", baseline_source, baseline_output, "fse", "v2", 65536, 15, 262139).stderr)
        failures = [
            ("output-limit", [65536, "fse", f"--output-limit={api['encoded'] - 1}"], "OutputLimitExceeded"),
            ("working-limit", [65536, "fse", f"--working-memory-limit={api['peak_working_bytes'] - 1}"], "WorkingMemoryLimitExceeded"),
            ("working-zero", [65536, "fse", "--working-memory-limit=0"], "WorkingMemoryLimitExceeded"),
            ("unknown-flag", [65536, "fse", "--no-such-option=1"], "InvalidBlockPlan"),
            ("invalid-version", [65536, "fse", "--fse-version=v3"], "InvalidBlockPlan"),
            ("invalid-mode", [65536, "no-such-mode"], "InvalidBlockPlan"),
            ("extra-positional", [65536, "fse", "unexpected"], "InvalidBlockPlan"),
            ("hash-low", [65536, "fse", "--hash-log=7"], "InvalidLzfseStream"),
            ("hash-high", [65536, "fse", "--hash-log=21"], "InvalidLzfseStream"),
            ("hash-noninteger", [65536, "fse", "--hash-log=abc"], "InvalidCharacter"),
            ("distance-zero", [65536, "fse", "--max-distance=0"], "InvalidLzfseStream"),
            ("distance-noninteger", [65536, "fse", "--max-distance=abc"], "InvalidCharacter"),
            ("block-zero", [0, "fse"], "InvalidLzfseStream"),
            ("block-overflow", [4294967296, "fse"], "InvalidLzfseStream"),
        ]
        for name, flags, diagnostic in failures:
            for same_path in (False, True):
                case_dir = temp / f"case-{len(rows)}"
                case_dir.mkdir()
                source, output = case_dir / "input", case_dir / "output"
                source.write_bytes(payload)
                if same_path:
                    output = source
                else:
                    output.write_bytes(b"existing-output-guard\x00\xff")
                before = snapshot(case_dir)
                result = run(cli, "encode-lzfse-file", source, output, *flags, success=False)
                require(diagnostic.encode() in result.stderr, (name, "expected CLI error", result.stderr))
                require(snapshot(case_dir) == before, (name, same_path, "failure modified output or leaked temporary"))
                rows.append({"case": name, "result": "expected_failure", "same_input_output_path": same_path,
                             "diagnostic": diagnostic, "returncode": result.returncode,
                             "output_sha256": sha256(output.read_bytes()), "directory_unchanged": True})

        case_dir = temp / "atomic-replace-failure"
        case_dir.mkdir()
        source, output = case_dir / "input", case_dir / "output"
        source.write_bytes(payload)
        output.mkdir()
        (output / "guard").write_bytes(b"nonempty output directory")
        before = snapshot(case_dir)
        result = run(cli, "encode-lzfse-file", source, output, 65536, "fse", success=False)
        require(snapshot(case_dir) == before, "atomic replace error must remove temporary and preserve destination")
        rows.append({"case": "atomic-replace-failure", "result": "expected_failure",
                     "returncode": result.returncode, "diagnostic": result.stderr.decode(errors="replace").splitlines()[0],
                     "directory_unchanged": True})

        report = {"schema": "vort-lzfse-cli-flags-atomic-v1",
                  "claim": "public CLI option routing, atomic output, functional interoperability and sizes; no throughput claim",
                  "created_utc": datetime.now(timezone.utc).isoformat(), "invocation": sys.argv,
                  "repository_commit": run("git", "rev-parse", "HEAD").stdout.decode().strip(),
                  "cli_path": str(cli), "cli_sha256": sha256(cli.read_bytes()),
                  "public_probe_sha256": sha256(args.probe.read_bytes()),
                  "reference_probe_sha256": sha256(args.lzfse.read_bytes()),
                  "reference_git": run("git", "-C", args.lzfse.parent, "rev-parse", "HEAD").stdout.decode().strip(),
                  "source_sha256": {str(path.relative_to(ROOT)): sha256(path.read_bytes()) for path in
                                    [ROOT / "examples/cli/lzfse.zig", ROOT / "src/lzfse.zig",
                                     *sorted((ROOT / "src/lzfse").rglob("*.zig")), Path(__file__).resolve()]},
                  "rows": rows}
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        successes = sum(row["result"] == "success" for row in rows)
        print(f"lzfse_cli_flags_cases={len(rows)} success={successes} protected_failures={len(rows) - successes} "
              f"same_path={sum(row.get('same_input_output_path', False) for row in rows)} "
              f"atomic_cleanup=ok Apple=ok cli_sha256={report['cli_sha256']}")


if __name__ == "__main__":
    main()
