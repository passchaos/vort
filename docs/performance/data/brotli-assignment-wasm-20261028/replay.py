"""Verify the frozen assignment epoch; execute or rebuild only when requested."""
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
parser.add_argument("--execute", action="store_true")
parser.add_argument("--rebuild", action="store_true")
parser.add_argument("--repo", type=Path)
parser.add_argument("--cpus", default="0,1,3-9,11-15")
args = parser.parse_args()
package = Path(__file__).resolve().parent
output = args.output or Path(tempfile.mkdtemp(prefix="vort-br-assignment-replay-"))
output.mkdir(parents=True, exist_ok=True)
if any(output.iterdir()):
    parser.error("--output must be empty")
evidence = json.loads((package / "evidence.json").read_text())
prefix = ["taskset", "-c", args.cpus]
exits = {}


def run(name, argv):
    command = prefix + argv
    result = subprocess.run(command, cwd=output, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)
    (output / (name + ".log")).write_text(
        "$ " + shlex.join(command) + "\n" + result.stdout +
        "\nexit_code=" + str(result.returncode) + "\n")
    exits[name] = result.returncode
    assert result.returncode == 0, (name, result.stdout)


if args.rebuild:
    repo = args.repo or package.parents[3]
    archive = output / "base.tar"
    subprocess.run(["git", "archive", "--output=" + str(archive), evidence["base_commit"], "src", "tools"],
                   cwd=repo, check=True)
    subprocess.run(["tar", "-xf", str(archive), "-C", str(output)], check=True)
for name, entry in evidence["source_files"].items():
    if "package_path" not in entry:
        if args.rebuild:
            assert hashlib.sha256((output / name).read_bytes()).hexdigest() == entry["sha256"]
        continue
    content = (package / entry["package_path"]).read_bytes()
    if entry["compression"] == "xz":
        content = lzma.decompress(content)
    assert hashlib.sha256(content).hexdigest() == entry["sha256"], name
    target = output / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)
for name, sha in evidence["module_sha256"].items():
    raw = lzma.decompress((package / "modules" / (name + ".wasm.xz")).read_bytes())
    assert hashlib.sha256(raw).hexdigest() == sha, name
    (output / (name + "-frozen.wasm")).write_bytes(raw)
shutil.copyfile(package / "modules" / "public-q8-baseline.wasm.br", output / "baseline.wasm.br")
if args.execute:
    run("frozen-kernel", ["node", "tools/br/assignment_costs_wasm_gate.js",
                           "wasm32-wasi-generic-frozen.wasm", "wasm32-wasi-simd128-frozen.wasm"])
    run("frozen-public-q8", ["node", "tools/br/prepared_command_distance_wasm_gate.js",
                              "baseline.wasm.br", "public-q8-frozen.wasm"])
if args.rebuild:
    for name, cpu in [("generic", "baseline"), ("simd128", "baseline+simd128")]:
        run("build-kernel-" + name, ["zig", "test", "-OReleaseFast", "-target", "wasm32-wasi",
                                    "-mcpu=" + cpu, "-fsingle-threaded", "--test-no-exec",
                                    "-Mroot=src/br/encoder/assignment_costs.zig", "-femit-bin=" + name + ".wasm"])
    run("rebuilt-kernel", ["node", "tools/br/assignment_costs_wasm_gate.js", "generic.wasm", "simd128.wasm"])
    # The original public gate linked the normal Debug record object into its
    # ReleaseFast public consumer, as recorded in the preserved build source.
    run("record-object", ["zig", "build-obj", "-ODebug", "-target", "wasm32-wasi",
                          "-Mroot=src/br/encoder/record_optimal_object.zig", "-femit-bin=record.o"])
    run("build-public-q8", ["zig", "build-exe", "record.o", "-fno-entry", "-rdynamic",
                            "--stack", "8388608", "-fsingle-threaded", "-OReleaseFast", "-target", "wasm32-wasi",
                            "-Mroot=src/br_prepared_command_distance_wasm.zig", "-femit-bin=public-q8.wasm"])
    run("rebuilt-public-q8", ["node", "tools/br/prepared_command_distance_wasm_gate.js",
                              "baseline.wasm.br", "public-q8.wasm"])
(output / "result.json").write_text(json.dumps({"verified": True, "exit_codes": exits}, indent=2) + "\n")
print(json.dumps({"output": str(output), "verified": True, "exit_codes": exits}, sort_keys=True))
