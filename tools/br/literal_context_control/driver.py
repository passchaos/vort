#!/usr/bin/env python3
"""Inspect complete wire literal context maps using a matching upstream decoder."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import threading

sys.dont_write_bytecode = True
from reference import Library
from reference_preflight import fixtures

ROOT = Path(__file__).resolve().parents[3]
LOCK = threading.Lock()
APIS = ("alloc", "reuse_alloc", "into", "reuse", "chunks_alloc", "chunks_append", "chunks_into", "reuse_chunks", "incremental")


def require(ok, detail):
    if not ok:
        raise AssertionError(detail)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def emit(value):
    with LOCK:
        print(json.dumps(value), flush=True)


def matrix(folder, preflight):
    sources = fixtures()
    for name, payload in sources.items():
        (folder / (name + ".payload")).write_bytes(payload)
    cases, seen = [], set()
    def add(api, quality=None, level="fast", fixture="json", large=False, hq=False, nested=False):
        for disabled in (False, True):
            name = "-".join((api, "q" + str(quality) if quality is not None else level, fixture,
                             "large" if large else "standard", "hq-nested" if nested else "hq" if hq else "normal",
                             "disabled" if disabled else "default"))
            if name in seen:
                continue
            seen.add(name)
            cases.append(dict(name=name, config=dict(api=api, quality=quality, level=level,
                         payload_path=str((folder / (fixture + ".payload")).resolve()), disable=disabled,
                         large=large, hq=hq, nested_only=nested), payload_sha256=sha(folder / (fixture + ".payload"))))
    if preflight:
        for api in APIS:
            add(api, 11)
        add("alloc", 0); add("alloc", level="ratio"); add("incremental", 5, large=True)
        add("reuse", 11, hq=True, nested=True)
    else:
        for quality in range(12):
            for fixture in sources:
                add("alloc", quality, fixture=fixture)
        for quality in (0, 5, 11):
            for api in APIS:
                add(api, quality)
        for level in ("fast", "balanced", "ratio"):
            for api in ("alloc", "reuse", "incremental"):
                add(api, level=level)
        for quality in (0, 5, 11):
            for api in ("alloc", "chunks_alloc", "incremental"):
                add(api, quality, large=True)
        for quality in (10, 11):
            for api in ("alloc", "reuse", "incremental"):
                add(api, quality, hq=True); add(api, quality, hq=True, nested=True)
    archived = ROOT / "src/tests/br_total_memory_helpers.zig"
    text = archived.read_text()
    literal = re.search(r'pub const plain = ("(?:[^"\\]|\\.)*") \*\* 2;', text).group(1)
    path = folder / "archived-default.payload"; path.write_bytes(json.loads(literal).encode() * 2)
    goldens = re.findall(r'\.api = \.one_shot, \.setting = \.(fast|balanced|ratio|q\d+), \.hex = "([0-9a-f]+)"', text)
    if preflight:
        goldens = goldens[:1]
    for setting, wire in goldens:
        cases.append(dict(name="archived-default-" + setting, config=dict(api="alloc",
                          quality=int(setting[1:]) if setting.startswith("q") else None,
                          level="fast" if setting.startswith("q") else setting,
                          payload_path=str(path.resolve()), disable=False, defaults=True),
                          expected_wire_hex=wire, payload_sha256=sha(path),
                          archive_commit="997fe5e56eb03ca21e7e66885d84f368d94ccc4e",
                          baseline_fixture_sha256=sha(archived)))
    return cases


def invoke(args, label, probe, bits, case):
    name = label + "-" + case["name"]
    config = dict(case["config"])
    wire = args.output_dir / (name + ".br")
    config["wire_path"] = str(wire.resolve())
    path = args.output_dir / (name + ".config.json"); path.write_text(json.dumps(config) + "\n")
    command = [str(probe.resolve()), str(path.resolve())]
    with (args.output_dir / (name + ".stderr.log")).open("wb") as error:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=error, cwd=ROOT)
    require(result.returncode == 0, (name, result.returncode, str(error.name)))
    report = json.loads(result.stdout)
    require(report["pointer_bits"] == bits and report["completed"], (name, "probe completion/target"))
    data = wire.read_bytes()
    require(report["wire_bytes"] == len(data), (name, "actual wire receipt"))
    if "expected_wire_hex" in case:
        require(data.hex() == case["expected_wire_hex"], (name, "archived default bytes changed"))
    return dict(name=name, command=command, probe_sha256=sha(probe), case=case, report=report,
                wire_sha256=sha(wire), wire_path=str(wire.resolve()), exit_code=0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-native", type=Path, required=True)
    parser.add_argument("--probe-x86", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--reference-br", type=Path)
    parser.add_argument("--preflight", action="store_true")
    parser.add_argument("--jobs", type=int, default=1)
    args = parser.parse_args()
    require(args.jobs > 0, "positive jobs")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    library = Library(args.reference_br)
    cases = matrix(args.output_dir, args.preflight)
    probes = [("native", args.probe_native, 64)]
    if args.probe_x86:
        probes.append(("x86", args.probe_x86, 32))
    tasks = [(args, label, probe, bits, case) for label, probe, bits in probes for case in cases]
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        events = list(pool.map(lambda values: invoke(*values), tasks))
    # Inspect serially so the upstream observer never shares callback state.
    false_context_witnesses = []
    for event in events:
        observation = library.inspect(Path(event["wire_path"]).read_bytes())
        config = event["case"]["config"]
        require(observation["reference_decoded"] and observation["decoded_sha256"] == event["case"]["payload_sha256"], (event["name"], "independent complete content"))
        require(observation["compressed_metablocks"] > 0 and observation["literal_map_entries_checked"] > 0, (event["name"], "stored fallback is not a control proof"))
        if config["disable"]:
            require(observation["literal_maps_constant"], (event["name"], "nonconstant literal map with flag"))
        elif observation["nonconstant_literal_maps"]:
            false_context_witnesses.append(event["name"])
        observation.pop("decoded_base64", None); observation.pop("decoded_utf8", None)
        event["observation"] = observation
        (args.output_dir / (event["name"] + ".result.json")).write_text(json.dumps(event, indent=2) + "\n")
        emit(dict(case=event["name"], status="ok", literal_entries=observation["literal_map_entries_checked"],
                  literal_maps_constant=observation["literal_maps_constant"]))
    require(false_context_witnesses, "an actual Vort false fixture must use literal contexts")
    with (args.output_dir / "events.jsonl").open("w") as output:
        for event in events: output.write(json.dumps(event) + "\n")
    report = dict(schema="vort.br.literal-context-control-gate.v1", status="ok", utc=datetime.now(timezone.utc).isoformat(),
                  actual_command=[sys.executable, *sys.argv], preflight=args.preflight, cases=len(events),
                  events=events, false_context_witnesses=false_context_witnesses, reference=library.identity())
    path = args.output_dir / "report.json"; path.write_text(json.dumps(report, indent=2) + "\n")
    emit(dict(status="ok", cases=len(events), report=str(path.resolve())))


if __name__ == "__main__":main()
