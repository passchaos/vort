import subprocess


def run(*args, check=True):
    return subprocess.run([str(arg) for arg in args], check=check, capture_output=True)


def verify(cli, temp, runner=run):
    plain = b"LZMS CLI match payload 0123456789\n" * 1000
    source = temp / "match-cli-input.bin"
    source.write_bytes(plain)
    valid = 0
    failures = 0
    for name, flags in (
        ("greedy", []), ("literals", ["--strategy=literals"]),
        ("lz-only", ["--no-delta"]), ("hash8", ["--hash-log=8"]),
        ("distance128", ["--max-distance=128"]),
    ):
        encoded = temp / f"match-cli-{name}.lzms"
        output = temp / f"match-cli-{name}.out"
        report = runner(cli, "encode-lzms-file", source, encoded, *flags).stdout
        if b"lz_matches=" not in report or b"peak_working_bytes=" not in report:
            raise AssertionError("CLI did not report match/memory metrics")
        runner(cli, "decode-lzms-file", encoded, output, len(plain))
        if output.read_bytes() != plain:
            raise AssertionError(f"CLI match output mismatch: {name}")
        valid += 1
    for name, flags, error in (
        ("strategy", ["--strategy=unknown"], b"InvalidLzms"),
        ("hash", ["--hash-log=7"], b"InvalidLzms"),
        ("history", ["--max-distance=0"], b"InvalidLzms"),
        ("memory", ["--working-memory-limit=1"], b"WorkingMemoryLimitExceeded"),
        ("output", ["--output-limit=1"], b"OutputLimitExceeded"),
    ):
        encoded = temp / f"match-cli-bad-{name}.lzms"
        encoded.write_bytes(b"keep existing output")
        before = set(temp.iterdir())
        result = runner(cli, "encode-lzms-file", source, encoded, *flags, check=False)
        if result.returncode == 0 or error not in result.stderr:
            raise AssertionError(f"CLI missing {error!r}: {result.stderr!r}")
        if encoded.read_bytes() != b"keep existing output" or before != set(temp.iterdir()):
            raise AssertionError(f"CLI failure changed output or leaked temporary files: {name}")
        failures += 1
    same = temp / "match-cli-same-path.bin"
    same.write_bytes(plain)
    runner(cli, "encode-lzms-file", same, same)
    output = temp / "match-cli-same-path.out"
    runner(cli, "decode-lzms-file", same, output, len(plain))
    if output.read_bytes() != plain:
        raise AssertionError("LZMS same-path atomic encoding lost source")
    valid += 1
    return valid, failures
