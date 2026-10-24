import base64
import struct
from pathlib import Path
from configuration_diff import refresh


def build(logical_bits, count, two_byte):
    fixture = Path(__file__).resolve().parents[2] / "src/erofs/testdata/lz4-compact-big.erofs.b64"
    original = base64.b64decode(fixture.read_bytes())
    image = bytearray((count + 1) * 4096)
    image[:4096] = original[:4096]
    struct.pack_into("<I", image, 1060, count + 1)
    struct.pack_into("<I", image, 39 * 32 + 8, count * (1 << logical_bits))
    struct.pack_into("<I", image, 39 * 32 + 16, count)
    struct.pack_into("<H", image, 1284, int(two_byte))
    image[1287] = logical_bits - 12
    image[1288:1544] = bytes(256)
    initial = 6
    middle = (count - initial) // 16 * 16 if two_byte and count > initial else 0
    logical = 0
    position = 1288
    while logical < count:
        compact = initial <= logical < initial + middle
        size, items, bits = (32, 16, 14) if compact else (8, 2, 16)
        actual = min(items, count - logical)
        for item in range(actual):
            for i in range(bits):
                bit = item * bits + i
                image[position + bit // 8] |= (((1 << logical_bits) >> i) & 1) << (bit % 8)
        struct.pack_into("<I", image, position + size - 4, logical)
        logical += actual
        position += size
    extensions, rest = divmod((1 << logical_bits) - 25, 255)
    encoded = bytes([0x1f, 0, 1, 0]) + bytes([255]) * extensions + bytes([rest, 0x50, 0, 0, 0, 0, 0])
    for block in range(1, count + 1):
        image[(block + 1) * 4096 - len(encoded):(block + 1) * 4096] = encoded
    refresh(image)
    return image


def verify_compact_widths(cli, reader, oracle, temp, run):
    if reader is None or oracle is None:
        return 0, 0
    valid = 0
    malformed = 0
    for bits, count, flag in ((12, 22, False), (12, 22, True), (13, 22, False), (14, 22, False), (13, 4, True), (14, 4, True)):
        label = f"{bits}-{count}-{int(flag)}"
        image = temp / f"compact-width-{label}.erofs"
        image.write_bytes(build(bits, count, flag))
        size = count << bits
        for start, length in ((0, size), (0, 31), ((1 << bits) - 3, 31), (1 << bits, 31), (size - 31, 31)):
            expected = run(oracle, image, 39, start, length).stdout
            if expected != bytes(length):
                raise AssertionError(f"compact-width reference output mismatch: {label}/{start}")
            for mode in ("slice", "source"):
                output = temp / f"compact-width-{label}-{mode}-{start}.out"
                run(reader, image, 39, start, length, output, mode)
                if output.read_bytes() != expected:
                    raise AssertionError(f"compact-width Vort output mismatch: {label}/{start}/{mode}")
            valid += 1
    for bits in (13, 14):
        image = temp / f"compact-width-bad-{bits}.erofs"
        image.write_bytes(build(bits, 22, True))
        # A valid initial four-byte pack proves that the reference rejection
        # comes from the later two-byte shape, not from its LZ4 payload.
        if run(oracle, image, 39, 0, 31).stdout != bytes(31):
            raise AssertionError("initial four-byte reference control failed")
        start = 6 << bits
        reference = run(oracle, image, 39, start, 31, check=False)
        if reference.returncode == 0 or b"reference_error=-95" not in reference.stderr:
            raise AssertionError(f"reference did not reject unsupported item width: {reference.stderr!r}")
        commands = [(mode, [reader, image, 39, start, 31]) for mode in ("slice", "source")]
        if cli is not None:
            commands.append(("cli", [cli, "extract-erofs-file", image, "big.bin"]))
        for mode, command in commands:
            output = temp / f"compact-width-bad-{bits}-{mode}.out"
            output.write_bytes(b"preserve previous output")
            before = set(temp.iterdir())
            command.append(output)
            command.extend([22 << bits, "--output-chunk-size=17"] if mode == "cli" else [mode])
            result = run(*command, check=False)
            if result.returncode == 0 or b"UnsupportedErofsFeature" not in result.stderr:
                raise AssertionError(f"missing width error: {bits}/{mode}: {result.stderr!r}")
            if output.read_bytes() != b"preserve previous output" or before != set(temp.iterdir()):
                raise AssertionError(f"width rejection changed output or leaked temporary files: {bits}/{mode}")
        malformed += 1
    return valid, malformed
