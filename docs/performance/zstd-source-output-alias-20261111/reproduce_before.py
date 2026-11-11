"""Reproduce the successful-but-corrupt source decode at the pinned baseline."""
import argparse
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile

BASELINE = "5425a37b0c36ce8b4193b8ea8d09dd638403d1ab"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, default=Path.cwd())
    args = parser.parse_args()
    evidence = Path(__file__).resolve().parent
    workspace = Path(tempfile.mkdtemp(prefix="vort-zstd-alias-before-"))
    archive = subprocess.check_output(
        ["git", "archive", BASELINE, "src"], cwd=args.repository
    )
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        source.extractall(workspace, filter="data")
    root = workspace / "src/zstd.zig"
    with root.open("a") as target:
        target.write((evidence / "before_test.zig.fragment").read_text())
    result = subprocess.run(
        ["zig", "test", str(root), "-OReleaseSafe", "--test-filter",
         "source history alias reproduction"],
        cwd=args.repository, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, text=True,
    )
    (workspace / "before.log").write_text(result.stdout)
    print(result.stdout)
    print(f"workspace={workspace}")
    print(f"baseline_exit_code={result.returncode}")
    # This reproducer succeeds only if the exact corruption was observed.
    if result.returncode != 1 or "abddef" not in result.stdout:
        raise SystemExit("Pinned silent-corruption counterexample was not reproduced")


if __name__ == "__main__":
    main()
