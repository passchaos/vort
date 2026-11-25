"""Count native routed entries under GDB; do not use its durations as timings."""
import argparse
import json
import os
from pathlib import Path
import subprocess

from evidence import require, validate_manifest
from matrix import arguments


TARGET = "brotli/mozilla/full/11"
ROWS = (TARGET, "brotli/mozilla/full/6", "brotli/mozilla/1048576/11", "brotli/x-ray/65536/11")
OUTLIERS = ("brotli/mr/full/6", "brotli/samba/full/6", "brotli/samba/full/11", "brotli/ooffice/full/11")
MARKER = "VORT_PACKED_WIDE10_ROUTE"


def check(options):
    probe = options.probe.resolve()
    frozen = validate_manifest(json.loads(options.frozen_manifest.read_text()))
    refs = frozen["references"]
    fixtures = {fixture["key"]: fixture for fixture in frozen["fixtures"]}
    config = {**frozen["config"], "rounds": 2, "warmup": 0}
    env = {**os.environ, "LD_LIBRARY_PATH": str(Path(refs["brotli"]["common"]).parent)}
    nm = subprocess.check_output(["nm", "--defined-only", "--format=posix", str(probe)], text=True)
    names = [line.split()[0] for line in nm.splitlines() if line.startswith("br.processWideDistanceReusePayload")]
    require(len(names) == 1, f"Expected one routed outer symbol: {names}")
    options.output.mkdir(parents=True, exist_ok=False)
    commands = f"""set pagination off
set disable-randomization off
break '{names[0]}'
commands
silent
printf \"{MARKER}\\n\"
continue
end
run
"""
    (options.output / "commands.gdb").write_text(commands)
    counts = {}
    for i, key in enumerate(OUTLIERS if options.outliers else ROWS):
        task = {"fixture": fixtures[key], "lifecycle": "cold", "iterations": 1}
        argv = ["taskset", "-c", "4,12", "gdb", "-nx", "--batch", "--return-child-result", "-x",
                str((options.output / "commands.gdb").resolve()), "--args"] + arguments(probe, task, refs, config)
        result = subprocess.run(argv, env=env, check=True, text=True, capture_output=True, timeout=45)
        (options.output / f"{i}.stdout").write_text(result.stdout)
        (options.output / f"{i}.stderr").write_text(result.stderr)
        count = sum(line == MARKER for line in result.stdout.splitlines())
        require((count > 0) == (key == TARGET), f"Unexpected routed entry count {count}: {key}")
        counts[key] = count
    print(json.dumps(counts, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ("probe", "frozen-manifest", "output"):
        parser.add_argument(f"--{arg}", type=Path, required=True)
    parser.add_argument("--outliers", action="store_true", help="Verify the four additional full-file control rows")
    check(parser.parse_args())
