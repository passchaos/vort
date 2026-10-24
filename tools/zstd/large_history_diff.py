#!/usr/bin/env python3
"""Versioned public large-history contracts; far execution is explicit opt-in."""
import argparse
import ctypes as C
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone

sys.dont_write_bytecode = True
from large_history_wire import frame_header, inspect_far, require

ROOT = Path(__file__).resolve().parents[2]
BASE_REVISION = "fa35a843"
DISTANCE = 64 * 1024 * 1024 + 8


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sources():
    paths = [ROOT / "src/root.zig", ROOT / "src/zstd.zig", ROOT / "build.zig"]
    paths += sorted((ROOT / "src/zstd").rglob("*.zig"))
    paths += sorted((ROOT / "tools/zstd").glob("large_history*"))
    paths += [ROOT / "tools/zstd/far_history_probe.zig"]
    return {str(path.relative_to(ROOT)):digest(path.read_bytes()) for path in paths if path.is_file()}


class Reference:
    def __init__(self, path):
        self.path = Path(path).resolve()
        loader = C.CDLL("libdl.so.2")
        open_isolated = loader.dlmopen
        open_isolated.argtypes = [C.c_long,C.c_char_p,C.c_int]
        open_isolated.restype = C.c_void_p
        handle = open_isolated(-1,str(self.path).encode(),2)
        require(handle, "isolated reference namespace")
        self.library = C.CDLL(str(self.path),handle=handle)
        def bind(name, result, *args):
            value=getattr(self.library,name)
            value.restype=result
            value.argtypes=list(args)
            return value
        self.header_version=bind("zlh_header_version",C.c_uint32)()
        self.runtime_version=bind("zlh_runtime_version",C.c_uint32)()
        self.version_string=bind("ZSTD_versionString",C.c_char_p)().decode()
        require(self.header_version == self.runtime_version,"reference header/runtime version")
        self.runtime_path=Path(bind("zlh_runtime_path",C.c_char_p)().decode()).resolve()
        self.error=bind("ZSTD_isError",C.c_uint,C.c_size_t)
        self.error_name=bind("ZSTD_getErrorName",C.c_char_p,C.c_size_t)
        self.bound=bind("ZSTD_compressBound",C.c_size_t,C.c_size_t)
        self.encode_fn=bind("zlh_encode",C.c_size_t,C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t,C.c_int,C.c_int)
        self.decode_fn=bind("zlh_decode",C.c_size_t,C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t,C.c_int,C.POINTER(C.c_size_t),C.POINTER(C.c_size_t))
        self.decode_dictionary_fn=bind("zlh_decode_dictionary",C.c_size_t,C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t,C.c_int,C.POINTER(C.c_size_t),C.POINTER(C.c_size_t))

    def verify(self, wire, expected, maximum_window_log=27, dictionary=b""):
        capacity=len(expected)+1
        output=C.create_string_buffer(b"\xa5"*(capacity+16),capacity+16)
        consumed,written=C.c_size_t(),C.c_size_t()
        if dictionary:
            code=self.decode_dictionary_fn(wire,len(wire),dictionary,len(dictionary),C.byref(output,8),capacity,maximum_window_log,C.byref(consumed),C.byref(written))
        else:
            code=self.decode_fn(wire,len(wire),C.byref(output,8),capacity,maximum_window_log,C.byref(consumed),C.byref(written))
        require(not self.error(code),self.error_name(code).decode())
        require(code == 0 and consumed.value == len(wire) and written.value == len(expected),"reference complete stream progress")
        require(output.raw[8:8+written.value] == expected,"reference decoded bytes")
        require(output.raw[:8] == b"\xa5"*8 and output.raw[8+len(expected):] == b"\xa5"*(capacity+8-len(expected)),"reference output guards")
        return {"status":"ok","input_read":consumed.value,"output_written":written.value,"decoder_window_log_max":maximum_window_log}

    def encode(self, payload):
        output=C.create_string_buffer(self.bound(len(payload)))
        code=self.encode_fn(payload,len(payload),output,len(output),3,17)
        require(not self.error(code),self.error_name(code).decode())
        return output.raw[:code]

    def provenance(self):
        checkout=Path.home()/"Work/zstd"
        checkout_revision=None
        if checkout in self.runtime_path.parents and (checkout/".git").exists():
            checkout_revision=subprocess.check_output(["git","rev-parse","HEAD"],cwd=checkout,text=True).strip()
        return {"header_version":self.header_version,"runtime_version":self.runtime_version,"version_string":self.version_string,
                "reference_checkout_revision":checkout_revision,
                "helper_path":str(self.path),"helper_sha256":digest(self.path.read_bytes()),
                "runtime_path":str(self.runtime_path),"runtime_sha256":digest(self.runtime_path.read_bytes())}


def call(probe, directory, name, payload, config, expected_error=None, input_path=None):
    source=Path(input_path) if input_path else directory/(name+".input")
    if input_path is None:source.write_bytes(payload)
    output=directory/(name+".wire")
    output.write_bytes(b"preserve-existing-output")
    settings=directory/(name+".json")
    settings.write_text(json.dumps(config))
    result=subprocess.run([str(probe),str(source),str(output),str(settings)],cwd=ROOT,capture_output=True)
    (directory/(name+".stderr")).write_bytes(result.stderr)
    require(result.returncode == 0,(name,result.stderr.decode(errors="replace")))
    report=json.loads(result.stdout)
    (directory/(name+".report.json")).write_text(json.dumps(report,indent=2))
    require(report["error"] == expected_error,(name,report))
    if expected_error:
        require(output.read_bytes() == b"preserve-existing-output","output changed on failure")
    return output.read_bytes(),report


def prepare_baseline(args, directory):
    require(args.baseline_probe,"prepare requires a probe compiled against unchanged fa35a843 sources")
    payload=b"large history unchanged default wire abcdefghabcdefgh\n"*5
    rows=[]
    configs=[{}, {"window_log":27}, {"window_log":26,"max_match_history_len":64*1024*1024},
             {"strategy":"fast"},{"strategy":"double_fast"},
             {"api":"incremental","window_log":27,"max_match_history_len":64*1024*1024,"strategy":"fast"},
             {"content_size":True,"checksum":True}]
    for index,config in enumerate(configs):
        config={"api":"one_shot","content_size":False,"memory_profile_enabled":False,**config}
        name="base-"+str(index)
        wire,report=call(args.baseline_probe,directory,name,payload,config)
        rows.append({"name":name,"config":config,"input":name+".input","wire":name+".wire","input_sha256":digest(payload),"wire_sha256":digest(wire)})
    data={"schema":"vort-zstd-large-history-legacy-v1","source_revision":BASE_REVISION,
          "probe_sha256":digest(Path(args.baseline_probe).read_bytes()),"rows":rows}
    (directory/"baseline.json").write_text(json.dumps(data,indent=2))


def small(args, directory, references):
    baseline=json.loads((directory/"baseline.json").read_text())
    results=[]
    for row in baseline["rows"]:
        payload=(directory/row["input"]).read_bytes()
        expected=(directory/row["wire"]).read_bytes()
        require(digest(payload)==row["input_sha256"] and digest(expected)==row["wire_sha256"],"frozen baseline bytes")
        wire,report=call(args.probe,directory,"current-"+row["name"],payload,row["config"])
        require(wire == expected,"default/within-old-cap wire changed")
        results.append({"case":row["name"],"status":"same_frozen_wire"})
    payload=b"public large history controls keep bounded small inputs\n"*8
    for width in (10,24,26,27,41):
        cap=min((1<<width),64*1024*1024+8)
        config={"window_log":width,"max_match_history_len":cap,"strategy":"fast","content_size":False}
        wire,report=call(args.probe,directory,"window-"+str(width),payload,config)
        require(frame_header(wire)["window_size"] == 1<<width,"advertised descriptor")
        quiet,_=call(args.probe,directory,"window-quiet-"+str(width),payload,{**config,"memory_profile_enabled":False,"control_profile_enabled":False})
        require(quiet == wire,"profile changed wire")
        decoded,_=call(args.probe,directory,"window-decode-"+str(width),wire,{"operation":"decode"})
        require(decoded == payload,"public decode small frame")
        memory=report["memory_profile"]
        require(memory["available"] and memory["live_requested_bytes"] == 0,"total profile release")
        peak=memory["peak_requested_bytes"]
        exact,_=call(args.probe,directory,"window-exact-"+str(width),payload,{**config,"max_total_working_memory":peak})
        require(exact == wire,"exact quota wire")
        call(args.probe,directory,"window-below-"+str(width),payload,{**config,"max_total_working_memory":peak-1},"WorkingMemoryLimitExceeded")
        if width<=27:
            for ref in references:ref.verify(wire,payload,width)
        results.append({"window_log":width,"requested_history":cap,"advertised_window":1<<width,
                        "actual_history":report["observation"],"requested_heap_peak":peak,
                        "reference_scope":"decoded" if width<=27 else "header/public decode only; advertised 41 does not imply 2 TiB matcher"})
    supported=min((1<<64)-1,(1<<32)-1)-1-128*1024
    # Requested history is intersected with the advertised window. A large
    # metadata setting must not cause that much storage to be eagerly allocated.
    clamped_payload=bytes(range(256))*16
    clamped_config={"window_log":10,"max_match_history_len":1<<27,"strategy":"fast","flush_at":2048,
                    "block_size":1024,"input_chunk":257,"output_chunk":257}
    clamped,clamped_report=call(args.probe,directory,"requested-history-clamped-to-window",clamped_payload,clamped_config)
    require(clamped_report["observation"]["history_before_flush_tail"]==1024,"history intersects advertised window")
    require(frame_header(clamped)["window_size"]==1024,"clamped frame window")
    for reference in references:reference.verify(clamped,clamped_payload,10)
    results.append({"case":"requested_history_window_intersection","requested_history":1<<27,
                    "actual_retained_history":1024,"advertised_window":1024})
    maximum,maximum_report=call(args.probe,directory,"maximum-coordinate-cap-small-input",payload,
                                {"window_log":41,"max_match_history_len":supported,"strategy":"double_fast"})
    require(frame_header(maximum)["window_size"]==1<<41,"maximum advertised descriptor")
    require(maximum_report["memory_profile"]["peak_requested_bytes"]<64*1024*1024,"small input does not allocate maximum history")
    results.append({"case":"maximum_coordinate_cap_small_input","requested_history":supported,
                    "advertised_window":1<<41,"requested_heap_peak":maximum_report["memory_profile"]["peak_requested_bytes"],
                    "scope":"metadata capability and small actual storage; no claim of a 2 TiB matcher"})
    invalid=[{"window_log":9},{"window_log":42},{"max_match_history_len":1024},
             {"window_log":27,"max_match_history_len":1023},
             {"window_log":41,"max_match_history_len":supported+1}]
    for index,config in enumerate(invalid):call(args.probe,directory,"invalid-"+str(index),payload,config,"InvalidBlockPlan")
    call(args.probe,directory,"zero-total",payload,{"window_log":27,"max_total_working_memory":0},"WorkingMemoryLimitExceeded")
    for index,ref in enumerate(references):
        decoded,_=call(args.probe,directory,"reference-small-"+str(index),ref.encode(payload),{"operation":"decode"})
        require(decoded == payload,"public decoder on independent reference frame")
    return results


def far(args, directory, references):
    require(args.far_generator,"far requires generator executable")
    input_path=directory/"far.input"
    if not args.reuse_far_input:
        generation=subprocess.run([str(args.far_generator),str(input_path)],cwd=ROOT,capture_output=True)
        require(generation.returncode == 0,generation.stderr.decode())
        (directory/"far-generation.json").write_bytes(generation.stdout)
    else:
        require(input_path.is_file() and (directory/"far-generation.json").is_file(),"explicit reuse requires prior actual generated input and metadata")
    payload=input_path.read_bytes()
    require(len(payload)==DISTANCE+2048 and payload[DISTANCE:]==payload[:2048],"real far source bytes")
    base={"window_log":27,"max_match_history_len":DISTANCE,"flush_at":DISTANCE,"content_size":False,
          "max_input_size":len(payload),"max_output_size":len(payload)+65536}
    rows=[]
    for strategy in ("fast","double_fast"):
        config={**base,"strategy":strategy}
        if strategy == "fast" and args.reuse_far_fast:
            report_path=directory/"far-fast.report.json"
            wire_path=directory/"far-fast.wire"
            require(report_path.is_file() and wire_path.is_file(),"reuse requires a successful actual fast operation")
            report=json.loads(report_path.read_text())
            require(report["error"] is None and report["input_bytes"]==len(payload),"successful completed fast input accounting")
            require(all(report["requested"][key]==value for key,value in config.items()),"same fast config for reuse")
            wire=wire_path.read_bytes()
            require(len(wire)==report["output_bytes"],"completed fast wire accounting")
        else:
            wire,report=call(args.probe,directory,"far-"+strategy,payload,config,input_path=input_path)
        parsed=inspect_far(wire)
        require(parsed["header"]["window_size"]==1<<27,"actual far window")
        require(parsed["final_sequence"]["distance"]==DISTANCE,"actual far sequence distance")
        require(report["observation"]["history_before_flush_tail"]==DISTANCE,"actual retained prefix")
        require(report["profile"]["resolved_strategy"]==strategy,"actual public parser strategy")
        require(report["profile"]["history_sequences"]>0 and report["profile"]["max_distance"]==DISTANCE,"published history reference profile")
        require(parsed["decoded_bytes"]==len(payload),"frame byte progress")
        for reference in references:reference.verify(wire,payload,27)
        memory=report["memory_profile"]
        require(memory["live_requested_bytes"]==0,"far total profile release")
        rows.append({"strategy":strategy,"input_sha256":digest(payload),"wire_sha256":digest(wire),"parsed":parsed,
                     "requested_heap_peak":memory["peak_requested_bytes"],"profile":report["profile"],"observation":report["observation"]})
        if strategy=="fast":
            exact,_=call(args.probe,directory,"far-exact",payload,{**config,"max_total_working_memory":memory["peak_requested_bytes"]},input_path=input_path)
            require(exact == wire,"same-input far exact quota")
            near,near_report=call(args.probe,directory,"far-one-byte-history-below",payload,{**config,"max_match_history_len":DISTANCE-1},input_path=input_path)
            near_shape=inspect_far(near)
            require(not near_shape["final_sequence"] or near_shape["final_sequence"]["distance"]<DISTANCE,"below history emitted prohibited distance")
            require(near_report["observation"]["history_before_flush_tail"]==DISTANCE-1,"near prefix truncation")
            require(near_report["observation"]["history_absolute_start_before_flush_tail"]==1,"below history discarded origin")
            for reference in references:reference.verify(near,payload,27)
    if args.run_dictionary:
        dictionary=payload[:DISTANCE]
        dictionary_path=directory/"far.dictionary"
        dictionary_path.write_bytes(dictionary)
        plain=payload[:2048]
        config={**base,"api":"one_shot","strategy":"fast","flush_at":None,"dictionary_path":str(dictionary_path)}
        wire,report=call(args.probe,directory,"far-dictionary",plain,config)
        parsed=inspect_far(wire)
        require(parsed["final_sequence"]["distance"]==DISTANCE,"actual large preset dictionary distance")
        require(report["profile"]["dictionary_sequences"]>0,"selected dictionary reference")
        for reference in references:reference.verify(wire,plain,27,dictionary)
        rows.append({"case":"large_preset_dictionary_small_plaintext","dictionary_bytes":DISTANCE,"plaintext_bytes":len(plain),
                     "dictionary_sha256":digest(dictionary),"wire_sha256":digest(wire),"parsed":parsed,"profile":report["profile"]})
    return rows


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--probe",type=Path,required=True)
    parser.add_argument("--baseline-probe",type=Path)
    parser.add_argument("--far-generator",type=Path)
    parser.add_argument("--modern-helper",type=Path)
    parser.add_argument("--system-helper",type=Path)
    parser.add_argument("--output-dir",type=Path,required=True)
    parser.add_argument("--prepare-only",action="store_true")
    parser.add_argument("--preliminary",action="store_true",help="record source deltas while other test-only work is still being frozen")
    parser.add_argument("--run-far",action="store_true")
    parser.add_argument("--reuse-far-input",action="store_true",help="continue with the same real generated far.input after a tooling-stage failure")
    parser.add_argument("--reuse-far-fast",action="store_true",help="validate and retain completed fast output after an inspector-stage failure")
    parser.add_argument("--run-dictionary",action="store_true",help="with --run-far, also verify the real large preset dictionary")
    args=parser.parse_args()
    args.output_dir.mkdir(parents=True,exist_ok=True)
    before=sources()
    if args.prepare_only:
        prepare_baseline(args,args.output_dir)
        return
    require(args.modern_helper and args.system_helper,"versioned modern and system reference helpers required")
    references=[Reference(path) for path in (args.modern_helper,args.system_helper)]
    result={"schema":"vort-zstd-large-history-v1","utc":datetime.now(timezone.utc).isoformat(),
            "probe_sha256":digest(args.probe.read_bytes()),"references":[r.provenance() for r in references],
            "small":small(args,args.output_dir,references),"far":far(args,args.output_dir,references) if args.run_far else [],
            "scope":"Requested encoder-owned heap; borrowed fixtures and output collector are separate. No RSS or throughput claim."}
    after=sources()
    if not args.preliminary:
        require(before==after,"source changed during final campaign")
    result["source_before"]=before
    result["source_after"]=after
    result["changed_sources"]=[path for path in sorted(set(before)|set(after)) if before.get(path)!=after.get(path)]
    result["status"]="preliminary_passed" if args.preliminary else "ok"
    (args.output_dir/"large-history-report.json").write_text(json.dumps(result,indent=2))
    print(json.dumps({"status":result["status"],"small_cases":len(result["small"]),"far_strategies":len(result["far"]),"changed_sources":result["changed_sources"]}))


if __name__=="__main__":main()
