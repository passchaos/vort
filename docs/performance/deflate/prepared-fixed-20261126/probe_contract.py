"""Exact public-probe policy and record contracts; callable only on package data."""
from datetime import datetime
import json

from package_io import require

TIMER = "clearRetainingCapacity, complete public append, and length mix only"
ALLOCATOR = "plain std.process.Init.gpa; no memory profile or allocator observer"
MEMORY = "allocation contract is independently validated, not measured by this timer"
LZ77 = {"window_len": 16384, "min_match": 4, "max_chain": 32, "nice_len": 16, "max_match": 128, "max_candidates": 2}


def utc(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def policy(manifest):
    require(manifest["build_mode"] == "ReleaseFast" and manifest["target"] == "x86_64-linux-gnu" and
            manifest["cpu_features"] == "skylake+pku+sgx" and manifest["affinity"] == [2] and
            manifest["parser"] == "hash" and manifest["lz77_options"] == LZ77, "Declared build/hash/LZ77 policy differs")
    require(manifest["allocator"] == "plain std.process.Init.gpa, no observer/profile" and
            manifest["memory_scope"] == "timing only; zero heap contract is validated separately" and
            manifest["api_policy_correction"]["timer_scope"] == "each clearRetainingCapacity + full public append + length mix" and
            manifest["api_policy_correction"]["corrected_before_sampling"], "Declared lifecycle/allocator scope differs")


def check(record, manifest, spec, which, mode, iterations, builds, wire_path=None, wire_input=False):
    policy(manifest)
    argv = ["taskset", "-c", "2", manifest["base"] + "/build/" + which + "-probe", "--mode", mode,
            "--input", spec["input"], "--iterations", str(iterations)]
    if wire_path is not None:
        argv += ["--wire-in" if wire_input else "--wire-out", wire_path]
    require(record["argv"] == argv and record["which"] == which and record["mode"] == mode and
            record["row"] == spec["id"] and record["returncode"] == 0 and record["elf_sha256"] == builds[which]["elf_sha256"],
            "Record argv/source/mode/row/exit/ELF differs")
    probe = record["probe"]
    api = "codec.decodeRawAuto" if mode == "verify" else manifest["api_policy_correction"]["prepared_api" if mode == "prepared" else "legacy_control_api"]
    require(probe["schema"] == "vort.deflate.prepared-fixed-probe.v1" and probe["status"] == "ok" and
            probe["mode"] == mode and probe["api"] == api and probe["argv"] == argv[3:] and
            probe["input_path"] == spec["input"] and probe["input_bytes"] == spec["size"] and
            probe["input_sha256"] == spec["sha256"] and probe["iterations"] == iterations, "Probe API/argv/input/iteration differs")
    require(probe["build_mode"] == "ReleaseFast" and (probe["target_arch"], probe["target_os"], probe["target_abi"], probe["pointer_bits"]) ==
            ("x86_64", "linux", "gnu", 64) and probe["parser"] == manifest["parser"] and probe["lz77_options"] == manifest["lz77_options"],
            "Probe target/hash/LZ77 parameters differ")
    require(probe["prepare_capacity"] == (spec["size"] if mode == "prepared" else 0) and
            probe["caller_output_capacity"] == (9 * spec["size"] + 17) // 8 and
            probe["warm_encode_count"] == (0 if mode == "verify" else 1), "Probe prepared/output capacity or warm count differs")
    require(probe["timer_scope"] == TIMER and probe["allocator"] == ALLOCATOR and probe["memory_scope"] == MEMORY,
            "Actual timer/allocator/memory scope differs")
    sample = probe["sample"]
    require(sample["length_mix"] == probe["wire_bytes"] * iterations and sample["written"] ==
            (0 if mode == "verify" else probe["wire_bytes"]), "Probe written/length mix differs")
    require(sample["elapsed_ns"] > 0 if iterations else sample["elapsed_ns"] == 0, "Timed/untimed elapsed value differs")
    require(json.loads(record["stdout"]) == probe and utc(record["ended_utc"]) >= utc(record["started_utc"]), "Raw output or wall interval differs")
    require(record["monotonic_end_ns"] - record["monotonic_start_ns"] == record["wall_ns"] >= sample["elapsed_ns"],
            "Monotonic elapsed/timed interval differs")
    return probe


def sampling_after_terminal(benchmark, validation):
    from package_io import load
    terminal, command = load(validation, "final-full-exit.json"), load(validation, "final-full.command.json")
    require(terminal["exit_code"] == 0 and terminal["status"] not in ("pending", "running") and
            terminal["session_id"] == command["session_id"] == 46721 and terminal["argv"] == command["argv"] and
            "-Doptimize=ReleaseSafe" in command["argv"], "Actual full terminal/command/session differs")
    release = load(benchmark, "sampling-release.json")
    require(utc(release["utc"]) > utc(terminal["observed_utc"]), "Sampling release is not after actual final-full terminal")
    return terminal, release
