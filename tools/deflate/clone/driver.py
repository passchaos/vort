#!/usr/bin/env python3
"""Exercise real root-public stream forks and independently decode every byte.

The corpus is bounded. A seeded >2**32 case proves logical count storage only;
it does not claim that four GiB of physical data were encoded or decoded.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import random
import subprocess
import sys
import zlib

sys.dont_write_bytecode = True
from reference import ZlibLibrary, decode_wire

ROOT = Path(__file__).resolve().parents[3]
RESET = b"reset keeps owned branch storage independent"
ENCODERS = ("raw_stored", "raw_fixed", "raw_best", "zlib_fixed", "zlib_best", "gzip_fixed", "gzip_best")


def require(condition, detail):
    if not condition:
        raise RuntimeError(detail)


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as file:
        while chunk := file.read(65536):
            digest.update(chunk)
    return digest.hexdigest()


def wbits(fmt, bits):
    return -bits if fmt == "raw" else bits + 16 if fmt == "gzip" else bits


def fork_wire(prefix, a, b, fmt, bits, dictionary, level=6):
    kwargs = dict(level=level, wbits=wbits(fmt, bits))
    if dictionary:
        kwargs["zdict"] = dictionary
    compressor = zlib.compressobj(**kwargs)
    shared = compressor.compress(prefix) + compressor.flush(zlib.Z_SYNC_FLUSH)
    left, right = compressor.copy(), compressor.copy()
    return shared + left.compress(a) + left.flush(), shared + right.compress(b) + right.flush(), len(shared)


def prepare(directory):
    rng = random.Random(73651)
    phrase = b"clone dictionary shared phrase : abcdefghijklmnopqrstuvwxyz 0123456789\n"
    prefix = (phrase * 800)[:43521]
    tail_a = (b"branch A owns its pending state : " + phrase) * 91 + b"A END"
    tail_b = (b"branch B survives reset and free : " + phrase) * 87 + b"B END"
    dictionary = phrase * 31
    random_prefix = bytes(rng.randrange(128) for _ in range(60000))
    cases, refs = [], []

    def file(name, data):
        path = directory / name
        path.write_bytes(data)
        return str(path.resolve())

    def case(direction, family, stage, p=prefix, a=tail_a, b=tail_b, bits=15, d=b"", flush="partial", **extra):
        name = f"{direction}-{family}-{stage}-w{bits}"
        if d:
            name += "-dictionary"
        if name in {item["name"] for item in cases}:
            name += "-" + flush
        config = dict(direction=direction, family=family, stage=stage,
                      prefix_path=file(name + ".prefix", p), tail_a_path=file(name + ".a.plain", a),
                      tail_b_path=file(name + ".b.plain", b), wire_a_path=str((directory / (name + ".a.wire")).resolve()),
                      wire_b_path=str((directory / (name + ".b.wire")).resolve()),
                      reset_path=str((directory / (name + ".decoded")).resolve()),
                      report_path=str((directory / (name + ".probe.json")).resolve()),
                      window_bits=bits, flush=flush, **extra)
        if d:
            config["dictionary_path"] = file(name + ".dictionary", d)
        fmt = family.split("_")[0]
        if direction == "decode":
            wire_a, wire_b, shared = fork_wire(p, a, b, fmt, bits, d, level=0 if config.get("history_len") == 0 else 6)
            Path(config["wire_a_path"]).write_bytes(wire_a)
            Path(config["wire_b_path"]).write_bytes(wire_b)
            header = 0 if fmt == "raw" else 2 if fmt == "zlib" else 10
            config.setdefault("fork_output_limit", 7 if stage in ("match", "semantic") else 65536)
            config["fork_input"] = 1 if stage == "header" else header + 3 if stage == "dynamic" else len(wire_a) - 1 if stage == "trailer" else shared
        else:
            refs.append(dict(name=name, format=fmt, window_bits=bits, prefix_path=Path(config["prefix_path"]).name,
                             tail_a_path=Path(config["tail_a_path"]).name, tail_b_path=Path(config["tail_b_path"]).name,
                             dictionary_path=Path(config["dictionary_path"]).name if d else None,
                             flush="none" if stage in ("header", "params", "trailer") else flush,
                             copy_stage="header" if stage in ("header", "params") and fmt != "raw" else "prefix",
                             level=0 if family == "raw_stored" else 1 if stage == "params" else 6,
                             **(dict(params_level=9, params_strategy=0) if stage == "params" else {})))
        cases.append(dict(name=name, config=config, expected=(p + a, p + b), dictionary=d, format=fmt))

    for family in ENCODERS:
        case("encode", family, "pending")
        case("encode", family, "bits", p=b"A" * 260 + b"\xff")
    for family in ENCODERS[3:]:
        case("encode", family, "header", flush="none")
        case("encode", family, "trailer", a=b"", b=b"", flush="none")
    for family in ("raw_best", "zlib_best", "gzip_best"):
        case("encode", family, "params", flush="none")
    for family in ("raw_fixed", "raw_best", "zlib_fixed", "zlib_best"):
        for bits in (9, 15):
            case("encode", family, "pending", bits=bits, d=dictionary)
    for mode in ("block", "sync", "full"):
        case("encode", "raw_best", "pending", flush=mode)
    case("encode", "raw_best", "pending", logical_counter_base=1 << 32)
    for fmt in ("raw", "zlib", "gzip"):
        case("decode", fmt, "header", p=random_prefix)
        case("decode", fmt, "dynamic", p=random_prefix)
        case("decode", fmt, "match", p=b"R" * 20000)
        case("decode", fmt, "semantic", p=random_prefix, semantic=True, history_len=65536)
        case("decode", fmt, "trailer", a=b"", b=b"")
    case("decode", "raw", "pending", history_len=0)
    for fmt in ("raw", "zlib"):
        for bits in (9, 15):
            case("decode", fmt, "match", p=b"R" * 20000, bits=bits, d=dictionary)
    (directory / "manifest.json").write_text(json.dumps(dict(cases=refs), indent=2) + "\n")
    return cases


def execute(args, label, probe, bits, item, directory, library):
    config = dict(item["config"])
    for key in ("wire_a_path", "wire_b_path", "reset_path", "report_path"):
        if config["direction"] == "decode" and key.startswith("wire_"):
            continue
        config[key] = str((directory / Path(config[key]).name).resolve())
    stale = [Path(config["report_path"]), Path(config["reset_path"])]
    if config["direction"] == "encode":
        stale += [Path(config["wire_a_path"]), Path(config["wire_b_path"])]
    else:
        stale += [Path(config["reset_path"] + ".reset"), Path(config["reset_path"] + ".b")]
    for output in stale:
        output.unlink(missing_ok=True)
    path = directory / (item["name"] + ".config.json")
    if label == "wasm":
        # All immutable input and outputs live below the single preopened dir.
        config = {key: "/work/" + str(Path(value).resolve().relative_to(args.output_dir.resolve())) if key.endswith("_path") and value is not None else value for key, value in config.items()}
        command = ["node", str(Path(__file__).with_name("wasm_gate.js")), "--work-dir", str(args.output_dir.resolve()), "--config", str(path.resolve()), str(probe.resolve())]
    else:
        command = [str(probe.resolve()), str(path.resolve())]
    path.write_text(json.dumps(config) + "\n")
    run = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
    (directory / (item["name"] + ".stderr.log")).write_bytes(run.stderr)
    (directory / (item["name"] + ".stdout.log")).write_bytes(run.stdout)
    require(run.returncode == 0, (item["name"], label, run.returncode, (run.stderr or run.stdout).decode(errors="replace")[-4096:]))
    report_path = directory / Path(item["config"]["report_path"]).name
    report = json.loads(report_path.read_text())
    receipt = report["receipt"]
    require(report["schema"] == "vort.deflate.clone-probe.v1" and report["pointer_bits"] == bits and report["counter_bits"] == 64, "public target widths")
    require(receipt["source_destroyed_first"] and receipt["branch_a_reset_before_b"] and receipt["heap_live_after_free"] == 0, "clone lifetime/ownership")
    if item["config"]["direction"] == "encode":
        outputs = [directory / Path(item["config"][f"wire_{branch}_path"]).name for branch in ("a", "b")]
        reset = directory / Path(item["config"]["reset_path"]).name
        reset_plain, _ = decode_wire(reset.read_bytes(), item["format"], item["config"]["window_bits"], item["dictionary"] or None, library)
        require(reset_plain == RESET, "independent reset wire")
    else:
        first = directory / Path(item["config"]["reset_path"]).name
        outputs = [first, Path(str(first) + ".b")]
        require(Path(str(first) + ".reset").read_bytes() == item["expected"][0], "independent decoder reset")
    branches = []
    for index, output in enumerate(outputs):
        data = output.read_bytes()
        expected = item["expected"][index]
        oracle = None
        if item["config"]["direction"] == "encode":
            data, oracle = decode_wire(data, item["format"], item["config"]["window_bits"], item["dictionary"] or None, library)
        require(data == expected, (item["name"], label, "all actual decoded bytes"))
        branch = receipt["branches"][index]
        require(branch["eof"] and branch["crc32"] == zlib.crc32(expected) and branch["calls"] > 0, "EOF/checksum/steps")
        actual_len = branch["actual_input"] if item["config"]["direction"] == "encode" else branch["actual_output"]
        require(actual_len == len(expected), "exact delivered/accepted plaintext")
        branches.append(dict(artifact=str(output), sha256=sha(output), decoded_bytes=len(data), decoded_sha256=hashlib.sha256(data).hexdigest(), oracle=oracle))
    fork = receipt["fork"]
    stage = item["config"]["stage"]
    if stage == "bits":
        require(fork["pending_bits"] > 0 and not fork["flushing"], "partial encoder bits at clone")
    if stage == "pending" and item["config"]["direction"] == "encode":
        require(fork["pending_output"] > 0, "actual undrained encoder output at clone")
    if stage == "dynamic":
        require("dynamic" in fork["raw_phase"] and not fork["semantic_active"], "actual partial dynamic header at clone")
    if stage == "params":
        require(fork["params_queued"], "actual queued runtime params at clone")
    if stage == "header" and item["config"]["direction"] == "encode":
        require(fork["input_read"] == 0 and fork["output_written"] == 1 and fork["pending_output"] > 0, "actual partial wrapper header at clone")
    if stage == "trailer" and item["config"]["direction"] == "encode":
        require(fork["footer_written"] and fork["pending_output"] > 0, "actual partial wrapper trailer at clone")
    if stage == "match" and not item["dictionary"]:
        require(fork["match_remaining"] > 0, "actual half-match at clone")
    if stage == "semantic":
        require(fork["semantic_active"] and fork["history_len"] == 65536 and fork["semantic_generated"] > fork["semantic_delivered"], "actual active semantic workspace at clone")
    result = dict(name=item["name"], label=label, exit_code=run.returncode, command=command, probe_sha256=sha(probe), report=report, branches=branches)
    (directory / (item["name"] + ".result.json")).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(dict(status="ok", case=item["name"], target=label, fork=fork)), flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=Path, required=True)
    parser.add_argument("--probe-x86", type=Path)
    parser.add_argument("--probe-wasm", type=Path)
    parser.add_argument("--library", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--only", choices=("all", "encode", "decode"), default="all")
    parser.add_argument("--only-case", action="append")
    parser.add_argument("--skip-reference", action="store_true")
    parser.add_argument("--preflight", action="store_true", help="Run one pending case per encoder and one half-match case per decoder")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "report.json").unlink(missing_ok=True)
    corpus = args.output_dir / "corpus"
    corpus.mkdir(exist_ok=True)
    cases = prepare(corpus)
    if args.preflight:
        cases = [case for case in cases if not case["dictionary"] and not case["config"].get("logical_counter_base") and
                 ((case["config"]["direction"] == "encode" and case["config"]["stage"] == "pending" and case["config"]["flush"] == "partial") or
                  (case["config"]["direction"] == "decode" and case["config"]["stage"] == "match"))]
    cases = [case for case in cases if (args.only == "all" or case["config"]["direction"] == args.only) and (not args.only_case or case["name"] in args.only_case)]
    require(cases, "empty case selection")
    library = ZlibLibrary(str(args.library) if args.library else None)
    reference = None
    if not args.skip_reference:
        reference_dir = args.output_dir / "reference"
        manifest = json.loads((corpus / "manifest.json").read_text())
        selected_names = {case["name"] for case in cases}
        manifest["cases"] = [case for case in manifest["cases"] if case["name"] in selected_names]
        (corpus / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        command = [sys.executable, str(Path(__file__).with_name("reference.py")), "--input-dir", str(corpus.resolve()), "--output-dir", str(reference_dir.resolve())]
        if args.library:
            command += ["--library", str(args.library.resolve())]
        if manifest["cases"]:
            subprocess.run(command, cwd=ROOT, check=True, timeout=180)
            reference = json.loads((reference_dir / "receipt.json").read_text())
        else:
            reference = dict(status="not_run", reason="no encoder copy cases selected; every decoder fixture still uses the independent libz utility")
    probes = [("native", args.probe_native, 64)]
    if args.probe_x86:
        probes.append(("x86", args.probe_x86, 32))
    if args.probe_wasm:
        probes.append(("wasm", args.probe_wasm, 32))
    events = []
    for label, probe, bits in probes:
        directory = args.output_dir / label
        directory.mkdir(exist_ok=True)
        events.extend(execute(args, label, probe, bits, case, directory, library) for case in cases)
    by_name = {(event["label"], event["name"]): event for event in events}
    for label, _, _ in probes[1:]:
        for case in cases:
            left, right = by_name[("native", case["name"])], by_name[(label, case["name"])]
            require([branch["sha256"] for branch in left["branches"]] == [branch["sha256"] for branch in right["branches"]], (label, case["name"], "deterministic artifacts"))
    report = dict(schema="vort.deflate.clone-gate.v1", status="ok", utc=datetime.now(timezone.utc).isoformat(),
                  command=[sys.executable, *sys.argv], actual_fixtures_bounded=True, physical_four_gib_decoded=False,
                  logical_model_scope="only raw_best counts are seeded; every reported physical byte is independently decoded",
                  python_version=sys.version, zlib_runtime_version=zlib.ZLIB_RUNTIME_VERSION,
                  driver_sha256=sha(__file__), reference_sha256=sha(Path(__file__).with_name("reference.py")),
                  preflight=args.preflight, cases=len(events), events=events, reference=reference, reference_wire_equality_required=False)
    (args.output_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(dict(status="ok", cases=len(events), report=str((args.output_dir / "report.json").resolve()))))


if __name__ == "__main__":
    main()
