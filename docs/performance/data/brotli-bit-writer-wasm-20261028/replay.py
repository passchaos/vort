"""Replay the frozen modules, rebuild the frozen source, and compare fingerprints."""
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
args = parser.parse_args()
package = Path(__file__).resolve().parent
output = args.output or Path(tempfile.mkdtemp(prefix="vort-br-bit-writer-replay-"))
output.mkdir(parents=True, exist_ok=True)
if any(output.iterdir()):
    parser.error("--output must be an empty directory")
evidence = json.loads((package / "evidence.json").read_text())
epoch = json.loads((package / "source_epoch.json").read_text())
for name, expected in evidence["source_sha256"].items():
    assert hashlib.sha256((package / "sources" / name).read_bytes()).hexdigest() == expected, name
shutil.copytree(package / "sources" / "src", output / "src")
shutil.copyfile(package / "sources" / "bit_writer_wasm_gate.js", output / "gate.js")
(output / "logs").mkdir()
prefix = ["taskset", "-c", args.cpus]
results = {}


def run(name, command):
    argv = prefix + command
    result = subprocess.run(argv, cwd=output, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)
    (output / "logs" / (name + ".log")).write_text(
        "$ " + shlex.join(argv) + "\n" + result.stdout +
        "\nexit_code=" + str(result.returncode) + "\n")
    results[name] = result.returncode
    assert result.returncode == 0, (name, result.stdout)
    return result.stdout


def run_wasm(name, module):
    stdout = run(name, ["node", "gate.js", module, "src/br/encoder/bit_writer.zig"])
    report = json.loads(next(line for line in stdout.splitlines() if line.startswith("{")))
    assert report["fingerprint"] == int(evidence["fingerprint_hex"], 16)
    assert report["writer_source_sha256"] == evidence["source_sha256"]["src/br/encoder/bit_writer.zig"]


for mode, optimize in [("debug", "Debug"), ("releasefast", "ReleaseFast")]:
    frozen = lzma.decompress((package / "modules" / (mode + ".wasm.xz")).read_bytes())
    assert hashlib.sha256(frozen).hexdigest() == epoch[mode + "_wasm_sha256"]
    (output / ("frozen-" + mode + ".wasm")).write_bytes(frozen)
    run_wasm("frozen-" + mode, "frozen-" + mode + ".wasm")
    run("build-" + mode, ["zig", "build-exe", "-fno-entry", "-rdynamic", "--stack", "1048576",
                         "-fsingle-threaded", "-O" + optimize, "-target", "wasm32-wasi",
                         "-Mroot=src/probe_root.zig", "-femit-bin=" + mode + ".wasm"])
    run_wasm("rebuilt-" + mode, mode + ".wasm")
native = run("native-test", ["zig", "test", "-OReleaseFast", "-Mroot=src/probe_root.zig",
                             "--test-filter", "Brotli bit writer wasm probe"])
assert "All 1 tests passed." in native
assert "fingerprint=" + evidence["fingerprint_hex"] in native
(output / "exit_codes.json").write_text(json.dumps(results, indent=2) + "\n")
print(json.dumps({"output": str(output), "exit_codes": results,
                  "fingerprint_hex": evidence["fingerprint_hex"]}, sort_keys=True))
