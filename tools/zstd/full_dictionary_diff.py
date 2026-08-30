#!/usr/bin/env python3
"""Train a deterministic standard dictionary and run the Zig/libzstd diff."""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: full_dictionary_diff.py <probe>")
    zstd = shutil.which("zstd")
    if not zstd:
        raise SystemExit("zstd CLI is required")
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        samples = []
        for index in range(40):
            path = root / f"sample-{index:03d}.json"
            path.write_text(
                f'{{"kind":"event","service":"vort","id":{index},'
                f'"message":"standard dictionary sample {index % 7}"}}\n'
            )
            samples.append(path)
        dictionary = root / "dictionary.zdict"
        subprocess.run(
            [zstd, "--train", "--dictID=1180675969", *map(str, samples), "-o", str(dictionary)],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        generated = root / "vort-generated.zdict"
        output = subprocess.check_output([sys.argv[1], str(dictionary), str(generated)], text=True)
        if not output.startswith("zstd_full_dictionary_diff=ok version="):
            raise SystemExit(f"unexpected probe output: {output!r}")
        if "id=1180675969" not in output:
            raise SystemExit(f"dictionary id mismatch: {output!r}")
        if "generated=yes" not in output or not generated.is_file():
            raise SystemExit(f"Vort dictionary generation was not exercised: {output!r}")
        fields = dict(field.split("=", 1) for field in output.split() if "=" in field)
        trained_size = int(fields.get("trained", 0))
        if trained_size >= int(fields.get("baseline", 0)):
            raise SystemExit(f"trained dictionary entropy did not improve the control: {output!r}")
        # Literal-only training produced 508 bytes on this deterministic
        # control. Keep slack over the current 502-byte result while requiring
        # the corpus-derived sequence tables to remain beneficial.
        if trained_size > 507:
            raise SystemExit(f"trained sequence entropy regressed: {output!r}")
        if int(fields.get("sequence_entropy", 0)) <= 0:
            raise SystemExit(f"trained sequence entropy was not reported: {output!r}")
        generated_bytes = generated.read_bytes()
        if generated_bytes[:4] != bytes.fromhex("37a430ec"):
            raise SystemExit("Vort generated dictionary has bad magic")
        if int.from_bytes(generated_bytes[4:8], "little") != 1180675970:
            raise SystemExit("Vort generated dictionary id mismatch")
        # The probe already performed both directions of libzstd/Vort frame
        # interoperability using this exact file. Keep the Python side focused
        # on proving the generated artifact, magic, and requested ID survived
        # the process boundary.
        print(output, end="")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
