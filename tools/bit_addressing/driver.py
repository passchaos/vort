#!/usr/bin/env python3
"""Six public API calls and one actual fast-reader call per target over real sparse files."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import mmap
import os
from pathlib import Path
import resource
import subprocess
import sys

sys.dont_write_bytecode = True
import fixture

ROOT = Path(__file__).resolve().parents[2]
AS_LIMIT = 768 * 1024 * 1024
RSS_LIMIT_KIB = 128 * 1024


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def restrict():
    resource.setrlimit(resource.RLIMIT_AS, (AS_LIMIT, AS_LIMIT))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def execute(argv, directory, name):
    log = directory / (name + ".stdout")
    errors = directory / (name + ".stderr")
    record = directory / (name + "-execution.json")
    if record.exists():
        result = json.loads(record.read_text())
        assert result["argv"] == [str(x) for x in argv] and result["exit_code"] == 0
        assert result["stdout_sha256"] == sha(log) and result["stderr_sha256"] == sha(errors)
        assert result["peak_rss_kib"] <= RSS_LIMIT_KIB
        report = json.loads(log.read_text());assert report["status"] == "ok"
        return {"execution": result, "report": report}
    assert not log.exists() and not errors.exists(), "existing unrecorded process output requires explicit preservation before retry"
    with log.open("wb") as out, errors.open("wb") as err:
        child = subprocess.Popen([str(x) for x in argv], cwd=ROOT, stdout=out, stderr=err, preexec_fn=restrict)
        _, status, usage = os.wait4(child.pid, 0)
        child.returncode = code = os.waitstatus_to_exitcode(status)
    result = {"argv": [str(x) for x in argv], "exit_code": code, "peak_rss_kib": usage.ru_maxrss,
              "executable_sha256": sha(Path(argv[0])),
              "minor_faults": usage.ru_minflt, "major_faults": usage.ru_majflt,
              "address_space_limit_bytes": AS_LIMIT, "rss_limit_kib": RSS_LIMIT_KIB,
              "stdout_sha256": sha(log), "stderr_sha256": sha(errors)}
    record.write_text(json.dumps(result, indent=2) + "\n")
    assert code == 0, (name, errors.read_text(), log.read_text())
    assert usage.ru_maxrss <= RSS_LIMIT_KIB, (name, "actual RSS exceeded bounded campaign budget", result)
    report = json.loads(log.read_text())
    assert report["status"] == "ok", (name, report)
    return {"execution": result, "report": report}


def sparse_geometry(manifest):
    result = {}
    for name in ("metadata_only", "compressed_tail"):
        item = manifest[name]
        assert item["logical_bytes"] > 1 << 29
        proof = fixture.verify(item, manifest["metadata_headers"])
        # Establish a genuine mapping independently before passing that exact
        # file to the public Probe. Read only header/tail pages, never a made-up slice.
        with Path(item["file"]).open("rb") as source:
            with mmap.mmap(source.fileno(), 0, access=mmap.ACCESS_READ) as view:
                assert len(view) == item["logical_bytes"]
                for region in item["write_regions"]:
                    raw = bytes.fromhex(region["hex"])
                    assert view[region["offset"]:region["offset"] + len(raw)] == raw
                proof["python_actual_mapped_bytes"] = len(view)
        result[name] = proof
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--probe", type=Path, required=True)
    p.add_argument("--fast-probe", type=Path, required=True)
    p.add_argument("--fixture-manifest", type=Path, required=True)
    p.add_argument("--reference-probe", type=Path, required=True)
    p.add_argument("--modern-decoder", type=Path, required=True)
    p.add_argument("--system-decoder", type=Path, required=True)
    p.add_argument("--output-dir", type=Path, required=True)
    args = p.parse_args()
    for name in vars(args):setattr(args, name, getattr(args, name).resolve())
    args.output_dir.mkdir(parents=True, exist_ok=True)
    manifest_bytes = args.fixture_manifest.read_bytes()
    manifest = json.loads(manifest_bytes)
    assert manifest["metadata_bytes"] == 536870913 and manifest["metadata_blocks"] == 33
    assert manifest["window_bits"] == 16 and not manifest["large_window"]
    before = sparse_geometry(manifest)
    (args.output_dir / "fixture-before.json").write_text(json.dumps(before, indent=2) + "\n")
    calls = [("metadata_only", "alloc"), ("metadata_only", "summary"),
             ("compressed_tail", "alloc"), ("compressed_tail", "into"),
             ("compressed_tail", "size"), ("compressed_tail", "headers"),
             ("compressed_tail", "fast")]
    public = []
    for kind, api in calls:
        item = manifest[kind];expected = item["tail"]["expected_output_bytes"]
        argv = [args.fast_probe if api == "fast" else args.probe, item["file"], api, expected]
        if api == "fast":argv.append(manifest["prefix_bytes"])
        row = execute(argv, args.output_dir, kind + "-" + api)
        report = row["report"]
        assert report["mapped_input_bytes"] == item["logical_bytes"] and report["physical_mapping"]
        assert report["actual_input_bits"] == item["logical_bytes"] * 8 > 1 << 32
        assert report["output_bytes"] == expected and report["guards_verified"]
        assert not report["large_window_enabled"]
        if api in ("alloc", "into"):
            assert report["output_sha256"] == hashlib.sha256(b"R" * expected).hexdigest()
        if api == "summary":
            summary = report["summary"]
            assert summary["metadata_bytes"] == 536870913 and summary["metadata_meta_block_count"] == 33
            assert summary["decoded_bytes"] == 0 and summary["window_bits"] == 16 and not summary["large_window"]
        if api == "headers":
            assert report["header_profile"]["compressed_meta_block_count"] == 1
            assert manifest[kind]["tail"]["absolute_compressed_header_start_bit"] > 1 << 32
        if api == "fast":
            tail = bytes.fromhex(item["write_regions"][-1]["hex"])
            position, values, positions = 0, [], []
            for width in (3, 5, 9, 1, 17, 24, 7, 2):
                values.append(fixture.get(tail, position, width));position += width
                positions.append(manifest["prefix_bytes"] * 8 + position)
            assert report["direct_fast_reader_fields"] == values
            assert report["direct_fast_reader_positions"] == positions
            assert report["direct_fast_reader_start_bit"] == manifest["prefix_bytes"] * 8 > 1 << 32
            assert report["direct_fast_reader_final_bit"] == positions[-1]
            assert report["direct_fast_reader_physical_reads_verified"]
        public.append({"kind": kind, "api": api, **row})
    references = []
    for label, decoder, version in (("modern", args.modern_decoder, 0x1002000), ("system", args.system_decoder, 0x1000009)):
        for kind in ("metadata_only", "compressed_tail"):
            item = manifest[kind];expected = item["tail"]["expected_output_bytes"]
            name = label + "-" + kind
            checkpoint = args.output_dir / (name + "-execution.json")
            # Completed reference calls keep the exact prior executable whose
            # receipt is archived, when a resource-only helper repair follows.
            executable = Path(json.loads(checkpoint.read_text())["argv"][0]) if checkpoint.exists() else args.reference_probe
            row = execute([executable, decoder, item["file"], expected], args.output_dir, name)
            report = row["report"]
            assert report["decoder_version"] == version
            assert Path(report["decoder_library"]).resolve() == decoder
            assert report["input_read"] == report["mapped_input_bytes"] == item["logical_bytes"]
            assert report["output_written"] == expected and bytes.fromhex(report["output_hex"]) == b"R" * expected
            assert report["feed_bytes"] == 65536 and report["guards_verified"] and not report["large_window_enabled"]
            references.append({"reference": label, "kind": kind, "decoder_library_sha256": sha(decoder),
                               "output_sha256": hashlib.sha256(bytes.fromhex(report["output_hex"])).hexdigest(), **row})
    after = sparse_geometry(manifest)
    assert before == after and args.fixture_manifest.read_bytes() == manifest_bytes, "physical fixtures changed during campaign"
    (args.output_dir / "fixture-after.json").write_text(json.dumps(after, indent=2) + "\n")
    report = {"schema": "vort-real-wide-bit-reference-v1", "status": "ok", "utc": datetime.now(timezone.utc).isoformat(),
              "public_calls": public, "actual_public_calls": sum(x["api"] != "fast" for x in public),
              "actual_direct_fast_reader_calls": sum(x["api"] == "fast" for x in public),
              "actual_probe_calls": len(public), "reference_calls": references,
              "actual_reference_calls": len(references), "fixture_manifest": str(args.fixture_manifest),
              "fixture_manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(), "fixture_before_after_equal": True,
              "probe_path": str(args.probe), "probe_sha256": sha(args.probe),
              "fast_probe_path": str(args.fast_probe), "fast_probe_sha256": sha(args.fast_probe),
              "reference_probe_path": str(args.reference_probe), "reference_probe_sha256": sha(args.reference_probe),
              "resource_limits": {"address_space_bytes": AS_LIMIT, "observed_peak_rss_kib_limit": RSS_LIMIT_KIB,
                                  "input_mapping": "each process maps one real >512MiB sparse file; mapping length, allocated disk bytes and actual RSS are reported separately"},
              "public_decode_fast_kernel_invocation_observed": False,
              "direct_fast_reader_physical_reads_verified": True,
              "scope": "six public complete-input decode/header calls plus one direct fast-reader reservoir call using actual mapped high-offset bytes and independent bit oracle; ordinary RLE decode has no public fast-invocation counter; no giant-output writer or joined-chunks allocation claim",
              "whole_file_sha256": None, "whole_file_digest_scope": "sparse allocated extents and all headers/tails are hashed; no full payload-hole scan or claimed whole-file digest"}
    out = args.output_dir / "wide-bit-report.json";out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": "ok", "public_calls": 6, "direct_fast_reader_calls": 1, "probe_calls": len(public), "reference_calls": len(references), "report": str(out)}))


if __name__ == "__main__":main()
