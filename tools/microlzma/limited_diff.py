import re


def consumed(result) -> int:
    values = re.findall(rb"(?:^|\s)consumed=([0-9]+)(?=\s|$)", result.stdout)
    if len(values) != 1:
        raise AssertionError(f"missing or duplicate consumed progress: {result.stdout!r}")
    return int(values[0])


def verify_limits(cli, probe, source, temp, plain, dictionary, lc, lp, pb, run):
    capacities = sorted({6, 7, 8, 16, 32, 64, 256, 4096, len(plain) * 2 + 64})
    writer_cases = 0
    reference_cases = 0
    output = temp / "limited.out"
    native = temp / "limited-native.microlzma"
    reference = temp / "limited-reference.microlzma"
    for mode in ("literal-only", "greedy", "lazy"):
        previous_consumed = 0
        for capacity in capacities:
            progress = consumed(run(cli, "encode-microlzma-prefix-file", source, native,
                                    capacity, dictionary, lc, lp, pb, mode))
            if progress < previous_consumed or progress > len(plain) or (plain and progress == 0):
                raise AssertionError(f"invalid Vort prefix progress for {source.name}/{mode}/{capacity}")
            previous_consumed = progress
            if len(native.read_bytes()) > capacity:
                raise AssertionError(f"Vort prefix exceeds capacity {capacity}")
            run(cli, "decode-microlzma-file", native, output, progress, dictionary)
            if output.read_bytes() != plain[:progress]:
                raise AssertionError(f"Vort prefix round trip mismatch for {source.name}/{mode}/{capacity}")
            run(probe, "decode", native, output, progress, dictionary)
            if output.read_bytes() != plain[:progress]:
                raise AssertionError(f"XZ Utils prefix mismatch for {source.name}/{mode}/{capacity}")
            writer_cases += 1

    for capacity in capacities:
        progress = consumed(run(probe, "encode-limit", source, reference,
                                dictionary, lc, lp, pb, capacity))
        if progress > len(plain) or (plain and progress == 0):
            raise AssertionError(f"invalid XZ Utils prefix progress for {source.name}/{capacity}")
        if len(reference.read_bytes()) > capacity:
            raise AssertionError(f"XZ Utils prefix exceeds capacity {capacity}")
        run(probe, "decode", reference, output, progress, dictionary)
        if output.read_bytes() != plain[:progress]:
            raise AssertionError(f"XZ Utils prefix round trip mismatch for {source.name}/{capacity}")
        run(cli, "decode-microlzma-file", reference, output, progress, dictionary)
        if output.read_bytes() != plain[:progress]:
            raise AssertionError(f"Vort reference prefix mismatch for {source.name}/{capacity}")
        reference_cases += 1
    return writer_cases, reference_cases
