#!/usr/bin/env python3
"""Bounded public LZMA one-shot differentials with independent liblzma input.

Python/system liblzma generates unknown-size Alone and raw ZIP EOS payloads.
An existing local liblzma 5.8.x generates proper known/no-EOS Alone and
MicroLZMA; both known and Micro streams are independently decoded. Only a
small compatibility helper is compiled, never a Vort CLI or reference library.
"""
from __future__ import annotations

import argparse
import base64
from collections import Counter
import ctypes
import importlib.util
import json
import lzma
from pathlib import Path
import random
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("lzma_contract_support", ROOT / "tools/lzma/contract_diff.py")
support = importlib.util.module_from_spec(spec)
spec.loader.exec_module(support)
require, sha, command, cpu, sources = support.require, support.sha, support.command, support.cpu, support.sources

BRIDGE = r'''
#define main micro_main
#include "@MICRO_SOURCE@"
#undef main

static int known(const char *input_path, const char *output_path,
                 uint32_t dict, uint32_t lc, uint32_t lp, uint32_t pb) {
  uint8_t *input=NULL,*output=NULL; size_t size,position=13,capacity;
  lzma_options_lzma options; int status=1;
  if(read_file(input_path,&input,&size)) goto done;
  capacity=size*2+256; output=malloc(capacity);
  if(!output || lzma_lzma_preset(&options,6)) goto done;
  options.dict_size=dict;options.lc=lc;options.lp=lp;options.pb=pb;options.ext_flags=0;
  output[0]=(pb*5+lp)*9+lc;
  for(size_t i=0;i<4;i++) output[1+i]=(uint8_t)(dict>>(8*i));
  for(size_t i=0;i<8;i++) output[5+i]=(uint8_t)((uint64_t)size>>(8*i));
  lzma_filter filters[]={{LZMA_FILTER_LZMA1EXT,&options},{LZMA_VLI_UNKNOWN,NULL}};
  if(lzma_raw_buffer_encode(filters,NULL,input,size,output,&position,capacity)!=LZMA_OK) goto done;
  if(write_file(output_path,output,position)) goto done;
  status=0;
done: free(input);free(output);return status;
}
static int raw_decode(const char *input_path,const char *output_path,size_t expected,
                      uint32_t dict,uint32_t lc,uint32_t lp,uint32_t pb) {
  uint8_t *input=NULL,*output=NULL;size_t size,ip=0,op=0;int status=1;
  lzma_options_lzma options;
  if(read_file(input_path,&input,&size)) goto done;
  output=malloc(expected?expected:1);
  if(!output || lzma_lzma_preset(&options,6)) goto done;
  options.dict_size=dict;options.lc=lc;options.lp=lp;options.pb=pb;options.ext_flags=0;
  lzma_set_ext_size(options,expected);
  lzma_filter filters[]={{LZMA_FILTER_LZMA1EXT,&options},{LZMA_VLI_UNKNOWN,NULL}};
  if(lzma_raw_buffer_decode(filters,NULL,input,&ip,size,output,&op,expected)!=LZMA_OK || ip!=size || op!=expected) goto done;
  if(write_file(output_path,output,expected)) goto done;
  status=0;
done: free(input);free(output);return status;
}
int main(int argc,char **argv) {
  if(argc==2 && !strcmp(argv[1],"version")) {puts(lzma_version_string());return 0;}
  if(argc==8 && !strcmp(argv[1],"known"))
    return known(argv[2],argv[3],strtoul(argv[4],NULL,10),strtoul(argv[5],NULL,10),strtoul(argv[6],NULL,10),strtoul(argv[7],NULL,10));
  if(argc==9 && !strcmp(argv[1],"raw-decode"))
    return raw_decode(argv[2],argv[3],strtoull(argv[4],NULL,10),strtoul(argv[5],NULL,10),strtoul(argv[6],NULL,10),strtoul(argv[7],NULL,10),strtoul(argv[8],NULL,10));
  return micro_main(argc,argv);
}
'''


def helper(work, source, build):
    micro_source = ROOT / "tools/microlzma/xz_probe.c"
    bridge = BRIDGE.replace("@MICRO_SOURCE@", str(micro_source))
    path, executable = work / "lzma_one_shot_reference.c", work / "lzma_one_shot_reference"
    path.write_text(bridge)
    compile_command = ["cc", "-O2", "-I" + str(source / "src/liblzma/api"), path,
                       "-L" + str(build), "-Wl,-rpath," + str(build), "-llzma", "-o", executable]
    command(*compile_command)
    return executable, {"compile_command": [str(x) for x in compile_command], "source_sha256": sha(bridge.encode()),
                        "included_source": str(micro_source), "included_source_sha256": sha(micro_source.read_bytes()),
                        "sha256": sha(executable.read_bytes()), "version": command(executable, "version").decode().strip()}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--probe", type=Path)
    p.add_argument("--report", type=Path)
    p.add_argument("--work-dir", type=Path)
    p.add_argument("--prepare-only", action="store_true")
    p.add_argument("--baseline-probe", type=Path, help="parent-built public oracle against pinned old main")
    p.add_argument("--xz-source", type=Path, default=Path("/tmp/vort-xz-ref.vVVDxq/xz"))
    p.add_argument("--xz-build", type=Path, default=Path("/tmp/vort-xz-ref.vVVDxq/build"))
    args = p.parse_args()
    require(args.prepare_only or args.probe, "--probe is required unless --prepare-only")
    temporary = tempfile.TemporaryDirectory(prefix="vort-lzma-one-shot-") if args.work_dir is None else None
    work = Path(temporary.name) if temporary else args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    before, driver_sha = sources(), sha(Path(__file__).read_bytes())
    oracle, oracle_info = helper(work, args.xz_source, args.xz_build)
    xz = shutil.which("xz")
    rng = random.Random(0x1A2A0164)
    cases, corpus, rows = [], [], []
    payloads = [("empty", b""), ("tiny", b"bounded LZMA\n"), ("repeat", b"no whole decoded heap staging\n" * 3072),
                ("random", rng.randbytes(16387)), ("binary", bytes(range(256)) * 257),
                ("source", (ROOT / "src/root.zig").read_bytes()[:16384])]
    properties = [(4096, 3, 0, 2), (65536, 2, 2, 2), (8192, 0, 4, 0)]

    def add(format, name, wire, plain, origin, dictionary, lc, lp, pb, end_marker=False):
        cases.append({"format": format, "name": name, "wire": wire, "plain": plain, "dictionary": dictionary,
                      "lc": lc, "lp": lp, "pb": pb, "end_marker": end_marker})
        corpus.append({"format": format, "name": name, "origin": origin, "dictionary": dictionary, "lc": lc, "lp": lp, "pb": pb,
                       "end_marker": end_marker, "compressed_bytes": len(wire), "output_bytes": len(plain),
                       "compressed_sha256": sha(wire), "output_sha256": sha(plain)})

    for dictionary, lc, lp, pb in properties:
        opts = {"id": lzma.FILTER_LZMA1, "dict_size": dictionary, "lc": lc, "lp": lp, "pb": pb, "preset": 6}
        for name, plain in payloads:
            label = f"{name}-d{dictionary}-lc{lc}-lp{lp}-pb{pb}"
            eos = lzma.compress(plain, format=lzma.FORMAT_ALONE, filters=[opts])
            require(lzma.decompress(eos, format=lzma.FORMAT_ALONE) == plain, "Python Alone EOS reference")
            if xz:
                require(command(xz, "--format=lzma", "-dc", data=eos) == plain, "xz Alone EOS reference")
            add("alone", label + "-eos", eos, plain, "Python/system liblzma Alone encoder; Python + xz independently decoded", dictionary, lc, lp, pb, True)
            src, dst, decoded = work / "reference-plain", work / "reference-encoded", work / "reference-decoded"
            src.write_bytes(plain)
            command(oracle, "known", src, dst, dictionary, lc, lp, pb)
            known = dst.read_bytes()
            require(lzma.decompress(known, format=lzma.FORMAT_ALONE) == plain, "proper known/no-EOS Python decode")
            if xz:
                require(command(xz, "--format=lzma", "-dc", data=known) == plain, "proper known/no-EOS xz decode")
            add("alone", label + "-known", known, plain, "liblzma LZMA1EXT no-EOPM raw encoder + standard known-size Alone header; Python/xz decoded", dictionary, lc, lp, pb)
            command(oracle, "encode", src, dst, dictionary, lc, lp, pb)
            micro = dst.read_bytes()
            command(oracle, "decode", dst, decoded, len(plain), dictionary)
            require(decoded.read_bytes() == plain, "independent liblzma Micro encode/decode")
            add("micro", label, micro, plain, "liblzma microlzma encoder and decoder", dictionary, lc, lp, pb)
            props = bytes([(pb * 5 + lp) * 9 + lc]) + dictionary.to_bytes(4, "little")
            for marker, body in ((True, eos[13:]), (False, known[13:])):
                raw = work / "reference-raw"
                raw.write_bytes(body)
                if marker:
                    require(lzma.decompress(body, format=lzma.FORMAT_RAW, filters=[opts]) == plain, "ZIP EOS raw oracle")
                else:
                    command(oracle, "raw-decode", raw, decoded, len(plain), dictionary, lc, lp, pb)
                    require(decoded.read_bytes() == plain, "ZIP no-EOS LZMA1EXT oracle")
                zip_payload = b"\x09\x04\x05\x00" + props + body
                add("zip", label + ("-eos" if marker else "-known"), zip_payload, plain,
                    "standard ZIP method-14 properties envelope around independent liblzma raw payload; raw oracle decoded", dictionary, lc, lp, pb, marker)
    fixture = ROOT / "src/lzma/testdata/microlzma-small.bin.b64"
    plain_fixture = (ROOT / "src/lzms/testdata/lzms-small.txt").read_bytes()
    pinned = base64.b64decode(fixture.read_text())
    pin, pinout = work / "pinned-micro", work / "pinned-output"
    pin.write_bytes(pinned)
    command(oracle, "decode", pin, pinout, len(plain_fixture), 32768)
    require(pinout.read_bytes() == plain_fixture, "existing pinned Micro independent decode")
    add("micro", "pinned-micro", pinned, plain_fixture, str(fixture), 32768, 3, 0, 2)
    if not args.prepare_only:
        run_matrix(args.probe.resolve(), work, cases, rows, args.baseline_probe.resolve() if args.baseline_probe else None)
    if not args.prepare_only:
        require(before == sources(), "source changed during final differential; rebuild after freeze")
    require(driver_sha == sha(Path(__file__).read_bytes()), "driver changed during differential")
    from datetime import datetime, timezone
    library = (args.xz_build / "liblzma.so.5").resolve()
    report = {"schema": "vort.lzma_bounded_one_shot", "schema_version": 1,
              "status": "reference_prepared" if args.prepare_only else "ok", "utc": datetime.now(timezone.utc).isoformat(),
              "cpu": cpu(), "python": sys.version, "xz": command(xz, "--version").decode().splitlines()[0] if xz else None,
              "zig": command("zig", "version").decode().strip(), "command": sys.argv, "sources": before,
              "driver_sha256": driver_sha, "support_driver_sha256": sha((ROOT / "tools/lzma/contract_diff.py").read_bytes()),
              "reference": {"helper": oracle_info, "library": str(library), "library_sha256": sha(library.read_bytes())},
              "probe": {"path": str(args.probe.resolve()), "sha256": sha(args.probe.read_bytes())} if args.probe else None,
              "baseline": {"path": str(args.baseline_probe.resolve()), "sha256": sha(args.baseline_probe.read_bytes()),
                           "source": "tools/one_shot/legacy_probe.zig", "source_sha256": sha((ROOT / "tools/one_shot/legacy_probe.zig").read_bytes()),
                           "module_revision": "4d0a93f0", "build_mode": "ReleaseSafe"} if args.baseline_probe else None,
              "corpus": corpus, "cases": rows,
              "summary": {"streams": len(corpus), "runs": len(rows), "formats": dict(Counter(c["format"] for c in corpus)),
                          "errors": dict(Counter(r["error"] for r in rows if r["error"]))}}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], **report["summary"]}, sort_keys=True))
    if temporary:
        temporary.cleanup()


def run_matrix(probe, work, cases, rows, baseline):
    def check(case, name=None, api="workspace", operation="into", error=None, baseline_compare=True, **options):
        index = len(rows)
        inp, expected, out, cfg, old_report = (work / f"{index}-{suffix}" for suffix in ("input", "expected", "output", "config.json", "old.json"))
        wire, plain = case["wire"], case["plain"]
        inp.write_bytes(wire)
        expected.write_bytes(plain)
        config = {"format": case["format"], "api": api, "operation": operation, "dictionary": case["dictionary"],
                  "end_marker": case["end_marker"], **options}
        if operation == "count":
            config.setdefault("max_output_len", len(plain))
        old = None
        if baseline and baseline_compare and api != "alloc" and not config.get("allow_partial", False):
            mode = "size" if operation == "count" else {"alone": "into", "micro": "micro", "zip": "zip-eos" if case["end_marker"] else "zip-known"}[case["format"]]
            capacity = config.get("max_output_len", len(plain)) if operation == "count" else config.get("output_capacity", len(plain))
            command(baseline, mode, inp, config.get("expected_size", len(plain)), config.get("max_dictionary_size", case["dictionary"]) if case["format"] == "zip" else case["dictionary"], capacity, old_report)
            old = json.loads(old_report.read_text())
            if error == "baseline":
                require(old["error"] is not None, (name, "baseline expected rejection"))
                error = old["error"]
        if error == "baseline":
            error = ("InvalidLzmaStream", "TruncatedFrame", "SizeMismatch", "OutputTooSmall", "OutputLimitExceeded", "TrailingData")
        cfg.write_text(json.dumps(config) + "\n")
        try:
            result = json.loads(command(probe, inp, expected, out, cfg))
        except Exception as exc:
            raise RuntimeError(f"one-shot case {name or case['name']}: {config}") from exc
        actual = out.read_bytes()
        if error is None:
            require(result["error"] is None, (name, result["error"]))
            require(result["count"] == len(plain) if operation == "count" else actual == plain, (name, "full output/size"))
        else:
            require(result["error"] in ([error] if isinstance(error, str) else error), (name, error, result["error"]))
            require(result["unchanged_on_error"], (name, "atomic caller error"))
        require(not result["allocation_after_output"] and result["live_after_deinit"] == 0, (name, "allocation boundary/free"))
        if api == "workspace":
            require(result["retained_decoded_capacity"] == 0, (name, "no decoded heap stage"))
            require(result["peak_working_bytes"] <= config.get("max_working_memory", 2**64 - 1), (name, "work budget"))
            require(result["retained_dictionary_capacity"] <= case["dictionary"], (name, "bounded dictionary"))
        if old is not None:
            require(old["error"] == result["error"], (name, "old/new error priority", old, result["error"]))
            if old["error"] is None:
                require(old["count"] == (result["count"] if operation == "count" else result["output_written"]), (name, "old/new count"))
                if old["decoded_sha256"] is not None:
                    old_sha = old["decoded_sha256"] if isinstance(old["decoded_sha256"], str) else bytes(old["decoded_sha256"]).decode()
                    require(old_sha == sha(actual), (name, "old/new output SHA"))
            else:
                require(old["unchanged"] == result["unchanged_on_error"], (name, "legacy caller atomicity"))
        rows.append({"name": name or case["name"], "config": config, "compressed_sha256": sha(wire),
                     "expected_sha256": sha(plain), "output_sha256": sha(actual), "baseline": old, **result})
        return result

    for case in cases:
        check(case, api="legacy")
        check(case, warm=True, check_count=case["format"] == "alone")
        if case["format"] == "alone":
            check(case, api="legacy", operation="count")
            check(case, operation="count", warm=True)
    representatives = [next(c for c in cases if c["format"] == f and c["name"].startswith("repeat-d4096")
                            and (f == "micro" or c["end_marker"])) for f in ("alone", "micro", "zip")]
    for case in representatives:
        base = check(case, "bounded-memory-lifecycle", warm=True, lifecycle=True, oom=True, baseline_compare=False)
        require(base["warm_calls"] == 2 and base["warm_allocation_attempts"] == 0 and base["lifecycle_checks"] == 4
                and base["oom_failure_cases"] > 0, "warm/reset/move/OOM coverage")
        require(base["max_allocation_request"] < len(case["plain"]), "large output must not allocate whole plain")
        limit = base["peak_working_bytes"]
        check(case, "working-exact", max_working_memory=limit, baseline_compare=False)
        check(case, "working-below", error="WorkingMemoryLimitExceeded", max_working_memory=limit - 1, baseline_compare=False)
        check(case, "dictionary-exact", max_dictionary_size=case["dictionary"], baseline_compare=False)
        check(case, "dictionary-below", error="OutputLimitExceeded", max_dictionary_size=case["dictionary"] - 1, baseline_compare=False)
        check(case, "output-option-exact", max_output_len=len(case["plain"]), baseline_compare=False)
        check(case, "output-option-below", error="OutputLimitExceeded", max_output_len=len(case["plain"]) - 1, baseline_compare=False)
        check(case, "caller-output-below", error="baseline", output_capacity=len(case["plain"]) - 1)
        check(case, "legacy-allocation-failures", api="legacy", oom=True, baseline_compare=False)
        alias = check(case, "aliased-input-output", alias_offset=0, warm=True, oom=True, baseline_compare=False)
        require(alias["retained_input_copy_capacity"] <= len(case["wire"]), "copy only coded input")
        check(case, "shifted-aliased-input-output", alias_offset=3, baseline_compare=False)
        if case["format"] == "alone":
            check(case, "new-options-into", api="with_options", max_working_memory=limit, baseline_compare=False)
            check(case, "new-options-count", api="with_options", operation="count", max_working_memory=limit, baseline_compare=False)
            allocated = check(case, "allocated-result-budget-baseline", api="alloc", baseline_compare=False)
            peak = allocated["peak_live_bytes"]
            check(case, "allocated-result-budget-exact", api="alloc", max_working_memory=peak, baseline_compare=False)
            check(case, "allocated-result-budget-below", api="alloc", max_working_memory=peak - 1, error="WorkingMemoryLimitExceeded", baseline_compare=False)
        if case["format"] == "micro":
            partial = dict(case, plain=case["plain"][:37])
            check(partial, "micro-partial-clipped-match", allow_partial=True, output_capacity=37, baseline_compare=False)
        if case["format"] == "zip":
            check(case, "zip-short-eos-ceiling", expected_size=len(case["plain"]) + 7, output_capacity=len(case["plain"]) + 7)
    for f in ("alone", "micro", "zip"):
        case = next(c for c in cases if c["format"] == f and c["name"].startswith("tiny-d4096") and (f == "micro" or c["end_marker"]))
        for cut in (0, 1, 4, len(case["wire"]) - 1):
            bad = dict(case, wire=case["wire"][:cut])
            check(bad, f"truncated-{f}-{cut}", error="baseline")
        offset = {"alone": 0, "micro": 0, "zip": 4}[f]
        bad = bytearray(case["wire"])
        bad[offset] = 0 if f == "micro" else 255
        check(dict(case, wire=bytes(bad)), "bad-properties-" + f, error="InvalidLzmaHeader")
        tail = dict(case, wire=case["wire"] + b"outer-extra\0\xff")
        check(tail, "strict-trailing-" + f, error="baseline")
    for f in ("alone", "zip"):
        known = next(c for c in cases if c["format"] == f and c["name"].startswith("repeat-d4096") and not c["end_marker"])
        tail = dict(known, wire=known["wire"] + bytes(range(256)) * 32)
        result = check(tail, "known-ignored-tail-alias-" + f, alias_offset=0, baseline_compare=False)
        require(result["retained_input_copy_capacity"] <= len(known["wire"]), "ignored tail must not inflate alias copy")
    z = next(c for c in cases if c["format"] == "zip" and c["name"].startswith("tiny-d4096") and c["end_marker"])
    invalid = dict(z, wire=z["wire"][:2] + b"\x04\0" + z["wire"][4:])
    check(invalid, "zip-property-length", error="InvalidLzmaHeader")
    check(z, "zip-expected-ceiling-below", expected_size=len(z["plain"]) - 1, error="baseline")


if __name__ == "__main__":
    main()
