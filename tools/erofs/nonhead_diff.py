import base64
import struct
from pathlib import Path
from configuration_diff import refresh


def verify_nonhead_chains(cli, reader, oracle, temp, run):
    if reader is None or oracle is None:
        return 0, 0
    valid = 0
    malformed = 0
    fixtures = Path(__file__).resolve().parents[2] / "src/erofs/testdata"

    def check_valid(label, data, nid, expected, windows):
        image = temp / f"nonhead-{label}.erofs"
        image.write_bytes(data)
        for start, length in windows:
            reference = run(oracle, image, nid, start, length).stdout
            if reference != expected[start:start + length]:
                raise AssertionError(f"reference chain output mismatch: {label}/{start}")
            for mode in ("slice", "source"):
                output = temp / f"nonhead-{label}-{mode}-{start}.out"
                run(reader, image, nid, start, length, output, mode)
                if output.read_bytes() != reference:
                    raise AssertionError(f"Vort chain output mismatch: {label}/{mode}/{start}")
        return len(windows)

    def check_bad(label, data, nid, start, entry, size):
        refresh(data)
        image = temp / f"nonhead-{label}.erofs"
        image.write_bytes(data)
        reference = run(oracle, image, nid, start, 31, check=False)
        if reference.returncode == 0:
            raise AssertionError(f"positional oracle accepted corrupt chain: {label}")
        # fsck whole-file extraction can skip the corrupt backward links;
        # use the positional API to force the requested NONHEAD path.
        commands = [
            (mode, [reader, image, nid, start, 31]) for mode in ("slice", "source")
        ]
        if cli is not None:
            commands.append(("cli", [cli, "extract-erofs-file", image, entry]))
        for mode, command in commands:
            output = temp / f"nonhead-{label}-{mode}.out"
            output.write_bytes(b"preserve previous output")
            before = set(temp.iterdir())
            command.append(output)
            command.extend([size, "--output-chunk-size=17"] if mode == "cli" else [mode])
            result = run(*command, check=False)
            if result.returncode == 0 or b"InvalidErofs" not in result.stderr:
                raise AssertionError(f"missing InvalidErofs for {label}/{mode}: {result.stderr!r}")
            if output.read_bytes() != b"preserve previous output" or before != set(temp.iterdir()):
                raise AssertionError(f"corrupt chain changed output or leaked temporary data: {label}/{mode}")
        return 1

    for layout in ("full", "compact"):
        original = bytearray(base64.b64decode((fixtures / f"lz4-{layout}-final-big.erofs.b64").read_bytes()))
        image = temp / f"nonhead-{layout}-original.erofs"
        image.write_bytes(original)
        expected = run(oracle, image, 40, 0, 16384).stdout
        if len(expected) != 16384:
            raise AssertionError("range oracle did not return the complete fixture")
        chain = bytearray(original)
        if layout == "full":
            struct.pack_into("<H", chain, 1348, 1)
            struct.pack_into("<H", chain, 1356, 1)
        else:
            struct.pack_into("<H", chain, 1328, 0x2001)
        refresh(chain)
        windows = ((0, 16384), (4093, 31), (8192, 31), (12288, 31))
        valid += check_valid(f"{layout}-original", original, 40, expected, windows)
        valid += check_valid(f"{layout}-linked", chain, 40, expected, windows)
        for label, delta in (("zero", 0), ("oversized", 0x7ff)):
            data = bytearray(original)
            offset = 1356 if layout == "full" else 1328
            struct.pack_into("<H", data, offset, delta | (0 if layout == "full" else 0x2000))
            malformed += check_bad(f"{layout}-{label}", data, 40, 12288, "tail.bin", 16384)

    original = bytearray(base64.b64decode((fixtures / "lz4-compact-big.erofs.b64").read_bytes()))
    image = temp / "nonhead-compact-two-byte.erofs"
    image.write_bytes(original)
    expected = run(oracle, image, 39, 0, 250000).stdout
    if len(expected) != 250000:
        raise AssertionError("range oracle did not return the two-byte fixture")
    windows = [(0, 250000)] + [(start, 31) for start in (6 * 4096 - 3, 21 * 4096, 22 * 4096 - 3, 53 * 4096, 54 * 4096 - 3)]
    valid += check_valid("compact-two-byte", original, 39, expected, windows)
    # Index 20 precedes pack-final index 21. Both paths must reject its bad
    # delta even though index 21 stores only a lookahead distance on disk.
    for label, delta in (("zero", 0), ("oversized", 0x7ff)):
        data = bytearray(original)
        for bit in range(14):
            position = 14 * 14 + bit
            mask = 1 << (position % 8)
            byte = 1312 + position // 8
            data[byte] = (data[byte] & ~mask) | (((0x2000 | delta) >> bit & 1) * mask)
        malformed += check_bad(f"compact-two-byte-{label}", data, 39, 21 * 4096, "big.bin", 250000)
    return valid, malformed
