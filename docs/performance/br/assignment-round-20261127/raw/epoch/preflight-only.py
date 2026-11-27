#!/usr/bin/env python3
"""Warm-only primary/public/small initial wires and pinned external decode."""
import ctypes
import importlib.util
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OLD = Path("/tmp/vort-br-original-command-split-reuse-ab.egqd38jr")
spec = importlib.util.spec_from_file_location("build_support", ROOT / "build-only.py")
support = importlib.util.module_from_spec(spec)
spec.loader.exec_module(support)
sha, read, write = support.sha, support.read, support.write


def decoder():
    pins = json.loads((OLD / "libbrotli-direct/library-paths.json").read_text())["libraries"]
    for item in pins.values():
        if sha(Path(item["path"])) != item["sha256"]:
            raise RuntimeError("Pinned libbrotli identity drift")
    common = ctypes.CDLL(pins["libbrotlicommon.so.1.2.0"]["path"], mode=ctypes.RTLD_GLOBAL)
    encoder = ctypes.CDLL(pins["libbrotlienc.so.1.2.0"]["path"], mode=ctypes.RTLD_LOCAL)
    dec = ctypes.CDLL(pins["libbrotlidec.so.1.2.0"]["path"], mode=ctypes.RTLD_LOCAL)
    encoder.BrotliEncoderVersion.restype = dec.BrotliDecoderVersion.restype = ctypes.c_uint32
    if encoder.BrotliEncoderVersion() != 0x1002000 or dec.BrotliDecoderVersion() != 0x1002000:
        raise RuntimeError("Pinned actual version must be1.2.0")
    maps = Path("/proc/self/maps").read_text()
    mapped = {line.split(maxsplit=5)[5] for line in maps.splitlines() if "libbrotli" in line}
    if mapped != {p["path"] for p in pins.values()}:
        raise RuntimeError("Pinned Brotli dependency closure mismatch")
    dec.BrotliDecoderDecompress.argtypes = (ctypes.c_size_t, ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p)
    dec.BrotliDecoderDecompress.restype = ctypes.c_int
    write(ROOT / "decoder-receipt.json", {"actual_version": "1.2.0", "libraries": pins, "proc_self_maps": maps, "mapped_brotli_paths": sorted(mapped)})
    return common, encoder, dec


def decode(dec, wire, plain):
    out = ctypes.create_string_buffer(len(plain))
    size = ctypes.c_size_t(len(plain))
    encoded = ctypes.create_string_buffer(wire)
    if dec.BrotliDecoderDecompress(len(wire), encoded, ctypes.byref(size), out) != 1 or size.value != len(plain) or out.raw != plain:
        raise RuntimeError("External complete wire decode mismatch")


def main():
    ready = read("BUILD_SOURCE_READY.json")
    builds = read("build-results.json")
    if not ready["BUILD_SOURCE_READY"] or not builds["completed"] or not builds["success"]:
        raise RuntimeError("Root source-ready and successful builds required")
    if (ROOT / "preflight-results.json").exists():
        raise RuntimeError("Preflight attempt exists; no retry/overwrite")
    for built in builds["stages"]:
        if sha(Path(built["output"])) != built["output_sha256"]:
            raise RuntimeError("Built artifact identity drift")
    status = read("execution-status.json")
    status.update({"HEAVY": 1, "terminal": False, "stage": "untimed-preflight"})
    write(ROOT / "execution-status.json", status)
    rows, attempts = [], []
    report = {"completed": False, "success": False, "rows": rows, "attempts": attempts, "timed_samples": 0, "full_gate_passed": False}
    write(ROOT / "preflight-results.json", report)
    handles = None

    def process(family, fixture, variant, control=None):
        before = support.source_state(ready)
        exe = OLD / "bin/candidate" if family == "main" and variant == "baseline" else ROOT / "bin" / ("candidate" if family == "main" else variant + "-controls")
        revision = ready["baseline_actual_git_revision"] if variant == "baseline" else ready["candidate_revision"]
        stem = ROOT / "preflight" / family / (fixture["case"] + ("-" + control if control else "") + "-" + variant)
        stem.parent.mkdir(parents=True, exist_ok=True)
        output, wirepath, stdout, stderr = (stem.with_suffix(s) for s in (".json", ".br", ".stdout", ".stderr"))
        if any(p.exists() for p in (output, wirepath, stdout, stderr)):
            raise RuntimeError("Attempt output already exists")
        command = ["taskset", "-c", "2", str(exe), "--input", fixture["path"], "--output", str(output), "--source-revision", revision, "--iterations", "0", "--window", "16", "--wire-output", str(wirepath)]
        if control:
            command += ["--control", control]
        with stdout.open("wb") as out, stderr.open("wb") as err:
            result = subprocess.run(command, cwd=ROOT, stdout=out, stderr=err)
        attempt = {"family": family, "case": fixture["case"], "control": control, "variant": variant, "argv": command, "actual_exit_code": result.returncode, "output": str(output), "wire": str(wirepath), "stdout": str(stdout), "stdout_sha256": sha(stdout), "stderr": str(stderr), "stderr_sha256": sha(stderr), "executable_sha256": sha(exe), "source_before": before}
        attempts.append(attempt)
        write(ROOT / "preflight-results.json", report)
        attempt["source_after"] = support.source_state(ready)
        write(ROOT / "preflight-results.json", report)
        if result.returncode:
            print(stderr.read_text(), flush=True)
            raise RuntimeError("Untimed process failed; retain attempt and stop")
        value = json.loads(output.read_text())
        if value["iterations"] != 0 or value["samples"] or value["warmup_owned_encode_free_calls"] != 1:
            raise RuntimeError("Untimed owning lifecycle changed")
        status["owning_warmup_calls"] += 1
        wire, plain = wirepath.read_bytes(), Path(fixture["path"]).read_bytes()
        if value["input_sha256"] != fixture["sha256"] or sha(Path(fixture["path"])) != fixture["sha256"] or len(plain) != fixture["bytes"]:
            raise RuntimeError("Fixture changed")
        if sha(wirepath) != value["warm_wire_sha256"] or len(wire) != value["warm_wire_bytes"] or value["requested_window_bits"] != 16:
            raise RuntimeError("Initial wire/window changed")
        info = value["provenance"]
        expected = {"optimize": "ReleaseFast", "target_arch": "x86_64", "target_os": "linux", "target_abi": "gnu", "target_cpu": "skylake+pku+sgx", "cpu_affinity": "2", "affinity_cpu_count": 1, "benchmark_threads": 1, "codec_thread_policy": "single", "executable_sha256": sha(exe)}
        if any(info[k] != v for k, v in expected.items()):
            raise RuntimeError("Matched target/CPU/thread/ELF changed")
        quality = {"q4": 4, "q6": 6, "q10-default": 10, "q11-default": 11, "q11-cap8": 11, "ratio": None, "q8": 8}.get(control, 8)
        if value["quality"] != quality or value["mode"] != "generic":
            raise RuntimeError("Quality/mode changed")
        if control and (value["control"] != control or value["command_state_limit_explicit"] != (control == "q11-cap8")):
            raise RuntimeError("Default/explicit cap caller changed")
        if control == "q11-cap8" and value["actual_options"]["command_state_max_input_kib"] != 8:
            raise RuntimeError("Explicit q11 cap8 changed")
        if control == "ratio" and value["actual_options"]["level"] != "ratio":
            raise RuntimeError("Null-quality ratio caller changed")
        decode(handles[2], wire, plain)
        status["external_decode_calls"] += 1
        row = {"family": family, "case": fixture["case"], "control": control, "variant": variant, "wire_bytes": len(wire), "wire_sha256": sha(wirepath), "wire_path": str(wirepath), "actual_options": value.get("actual_options"), "input_sha256": fixture["sha256"], "complete_external_decode": True, "iterations": 0, "samples": 0}
        rows.append(row)
        write(ROOT / "preflight-results.json", report)
        write(ROOT / "execution-status.json", status)
        print("preflight", family, fixture["case"], control or "q8", variant, len(wire), flush=True)
        return wire, row["actual_options"]

    try:
        handles = decoder()
        for fixture in read("fixtures-method.json"):
            a, _ = process("main", fixture, "baseline")
            b, _ = process("main", fixture, "candidate")
            if a != b or a != Path(fixture["golden_path"]).read_bytes():
                raise RuntimeError("Main baseline/candidate/gold memcmp failed")
        for row in read("protocols/public-controls.json")["rows"]:
            a, ao = process("public", row["input"], "baseline", row["control"])
            b, bo = process("public", row["input"], "candidate", row["control"])
            if a != b or ao != bo:
                raise RuntimeError("Public wire or actual default options differ")
        for fixture in read("small-fixtures-method.json"):
            a, ao = process("small", fixture, "baseline", "q8")
            b, bo = process("small", fixture, "candidate", "q8")
            if a != b or ao != bo:
                raise RuntimeError("Small wire/options memcmp failed")
        report.update({"completed": True, "success": True, "processes": len(attempts), "all_wire_peer_memcmp_and_external_decode_passed": True, "default_q10_q11_actual_options_equal": True, "generic_small_same_ELFs": True, "source_after": support.source_state(ready), "completed_utc": datetime.now(timezone.utc).isoformat()})
        write(ROOT / "preflight-results.json", report)
    except BaseException as error:
        report.update({"completed": True, "success": False, "failure": str(error)})
        write(ROOT / "preflight-results.json", report)
        raise
    finally:
        status.update({"HEAVY": 0, "terminal": True, "sampling_released": False})
        write(ROOT / "execution-status.json", status)


if __name__ == "__main__":
    main()
