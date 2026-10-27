"""Replay frozen q8 modules and optionally rebuild their complete source snapshots."""
import argparse
import hashlib
import json
import lzma
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path)
parser.add_argument("--cpus", default="0,1,3-9,11-15")
parser.add_argument("--rebuild", action="store_true")
args = parser.parse_args()
package = Path(__file__).resolve().parent
output = args.output or Path(tempfile.mkdtemp(prefix="vort-br-prepared-wasm-replay-"))
output.mkdir(parents=True, exist_ok=True)
if any(output.iterdir()):
    parser.error("--output must be empty")
epoch = json.loads((package / "source_epoch.json").read_text())
evidence = json.loads((package / "evidence.json").read_text())
(output / "logs").mkdir()
results = {}
prefix = ["taskset", "-c", args.cpus]


def run(name, argv):
    command = prefix + argv
    result = subprocess.run(command, cwd=output, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)
    (output / "logs" / (name + ".log")).write_text(
        "$ " + shlex.join(command) + "\n" + result.stdout +
        "\nexit_code=" + str(result.returncode) + "\n")
    results[name] = result.returncode
    assert result.returncode == 0, (name, result.stdout)
    return result.stdout


for variant in ("baseline", "candidate"):
    archive = package / "sources" / (variant + "-src.tar.xz")
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == evidence["source_archives"][variant]["sha256"]
    subprocess.run(["tar", "-xJf", str(archive), "-C", str(output)], check=True)
    raw_manifest = lzma.decompress((package / "sources" / (variant + "-manifest.json.xz")).read_bytes())
    assert hashlib.sha256(raw_manifest).hexdigest() == evidence["source_archives"][variant]["manifest_sha256"]
    for name, sha in json.loads(raw_manifest).items():
        assert hashlib.sha256((output / name).read_bytes()).hexdigest() == sha, name
    raw = lzma.decompress((package / "modules" / (variant + ".wasm.xz")).read_bytes())
    assert hashlib.sha256(raw).hexdigest() == epoch["result"][variant]["wasm_sha256"]
    (output / (variant + "-frozen.wasm")).write_bytes(raw)
for gate in ("gate-frozen.js", "gate-ci.js"):
    hash_field = "gate_frozen_sha256" if gate == "gate-frozen.js" else "gate_ci_sha256"
    assert hashlib.sha256((package / gate).read_bytes()).hexdigest() == evidence[hash_field]
    shutil.copyfile(package / gate, output / gate)
assert hashlib.sha256((package / "modules" / "baseline-ci.wasm.br").read_bytes()).hexdigest() == evidence["ci_compressed_baseline_sha256"]
shutil.copyfile(package / "modules" / "baseline-ci.wasm.br", output / "baseline-ci.wasm.br")
for name in ("input.bin", "baseline.br", "candidate.br"):
    raw = lzma.decompress((package / "wires" / (name + ".xz")).read_bytes())
    expected = epoch["result"]["baseline"]["input_sha256" if name == "input.bin" else "wire_sha256"]
    assert hashlib.sha256(raw).hexdigest() == expected
    (output / ("expected-" + name)).write_bytes(raw)


def wire_gate(name, gate, baseline, candidate):
    stdout = run(name, ["node", gate, baseline, candidate, name + "-wires"])
    report = json.loads(next(line for line in stdout.splitlines() if line.startswith("{")))
    assert report["full_wire_equal"]
    for variant in ("baseline", "candidate"):
        actual = report[variant]
        expected = epoch["result"][variant]
        if name != "rebuilt":
            assert actual["wasm_sha256"] == expected["wasm_sha256"]
        for field in ("input_bytes", "input_sha256", "wire_bytes", "wire_sha256", "wire_crc32",
                      "command_count", "command_active_entries", "complex_command_trees",
                      "recent_copy_count", "shared_candidate_groups"):
            assert actual[field] == expected[field], (variant, field)


wire_gate("frozen", "gate-frozen.js", "baseline-frozen.wasm", "candidate-frozen.wasm")
wire_gate("ci-compressed-baseline", "gate-ci.js", "baseline-ci.wasm.br", "candidate-frozen.wasm")
if args.rebuild:
    source = "candidate/src/br/encoder/record_optimal_object.zig"
    run("record-wasm", ["zig", "build-obj", "-OReleaseFast", "-target", "wasm32-wasi",
                        "-Mroot=" + source, "-femit-bin=record-wasm.o"])
    run("record-native", ["zig", "build-obj", "-OReleaseFast", "-Mroot=" + source,
                          "-femit-bin=record-native.o"])
    for variant in ("baseline", "candidate"):
        run("build-" + variant, ["zig", "build-exe", "record-wasm.o", "-fno-entry", "-rdynamic",
                                 "--stack", "8388608", "-fsingle-threaded", "-OReleaseFast",
                                 "-target", "wasm32-wasi", "-Mroot=" + variant + "/src/prepared_wasm_root.zig",
                                 "-femit-bin=" + variant + ".wasm"])
    wire_gate("rebuilt", "gate-frozen.js", "baseline.wasm", "candidate.wasm")
    native = run("native", ["zig", "test", "record-native.o", "-OReleaseFast",
                             "-Mroot=candidate/src/prepared_wasm_root.zig", "--test-filter",
                             "Brotli prepared public wasm fixture"])
    assert "prepared probe status=0 commands=1299 entries=88 complex=1 recent=152 groups=2" in native
    assert "All 25 tests passed." in native
(output / "exit_codes.json").write_text(json.dumps(results, indent=2) + "\n")
print(json.dumps({"output": str(output), "exit_codes": results,
                  "full_wire_sha256": epoch["result"]["candidate"]["wire_sha256"]}, sort_keys=True))
