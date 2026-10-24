def fix_checksum(image):
    block_size = 1 << image[1024 + 12]
    image[1028:1032] = b"\x00" * 4
    state = 0xFFFFFFFF
    for byte in image[1024:block_size]:
        state ^= byte
        for _ in range(8):
            state = (state >> 1) ^ (0x82F63B78 if state & 1 else 0)
    image[1028:1032] = state.to_bytes(4, "little")


def verify_source_readers(cli, temp, run):
    payload = b"source reader sparse image payload"
    source = temp / "source-reader-input"
    source.write_bytes(payload)
    base = temp / "source-reader-base.erofs"
    run(cli, "create-erofs-file", base, "payload", source, "stored")
    sparse = temp / "source-reader-sparse.erofs"
    image = bytearray(base.read_bytes())
    sparse_size = 512 * 1024 * 1024 + 4096
    image[1060:1064] = (sparse_size // 4096).to_bytes(4, "little")
    fix_checksum(image)
    sparse.write_bytes(image)
    with sparse.open("r+b") as stream:
        stream.truncate(sparse_size)
    if b"payload" not in run(cli, "list-erofs-file", sparse).stdout:
        raise AssertionError("Source reader failed to list a sparse image over 512 MiB")
    output = temp / "source-reader-sparse.out"
    report = run(cli, "extract-erofs-file", sparse, "payload", output, len(payload), "--working-memory-limit=65536").stdout
    if output.read_bytes() != payload or b"peak_working_bytes=" not in report:
        raise AssertionError("Source reader sparse extraction or working-memory reporting mismatch")

    output.write_bytes(b"keep output")
    before = set(temp.iterdir())
    failed = run(cli, "extract-erofs-file", sparse, "payload", output, len(payload), "--working-memory-limit=1", check=False)
    if failed.returncode == 0 or b"WorkingMemoryLimitExceeded" not in failed.stderr:
        raise AssertionError("Source reader failed to report a rejected working budget")
    if output.read_bytes() != b"keep output" or set(temp.iterdir()) != before:
        raise AssertionError("Source reader budget failure replaced output or leaked a temporary file")

    same = temp / "source-reader-same-path.erofs"
    same.write_bytes(base.read_bytes())
    run(cli, "extract-erofs-file", same, "payload", same, len(payload))
    if same.read_bytes() != payload:
        raise AssertionError("Source reader same-path extraction truncated its input")

    damaged_source = temp / "source-reader-damaged-input"
    damaged_payload = b"source reader corruption payload pattern\n" * 512
    damaged_source.write_bytes(damaged_payload)
    damaged = temp / "source-reader-damaged.erofs"
    run(cli, "create-erofs-file", damaged, "payload", damaged_source, "lz4")
    image = bytearray(damaged.read_bytes())
    image[-4096:] = b"\x00" * 4096
    damaged.write_bytes(image)
    before = set(temp.iterdir())
    failed = run(cli, "extract-erofs-file", damaged, "payload", output, len(damaged_payload), check=False)
    if failed.returncode == 0 or b"InvalidErofs" not in failed.stderr:
        raise AssertionError("Source reader did not reject a corrupt final pcluster")
    if output.read_bytes() != b"keep output" or set(temp.iterdir()) != before:
        raise AssertionError("Source reader late decode failure replaced output or leaked a temporary file")
    failed = run(cli, "extract-erofs-file", damaged, "payload", output, len(damaged_payload), "--output-chunk-size=0", check=False)
    if failed.returncode == 0 or b"OutputTooSmall" not in failed.stderr:
        raise AssertionError("Source reader did not reject an empty output chunk")

    # Expand a real external device without materializing its unused padding.
    primary = temp / "writer-chunk-external.erofs"
    original_device = temp / "writer-chunk-external.blob"
    sparse_device = temp / "source-reader-sparse-device.blob"
    sparse_device.write_bytes(original_device.read_bytes())
    with sparse_device.open("r+b") as stream:
        stream.truncate(sparse_size)
    image = bytearray(primary.read_bytes())
    slot = int.from_bytes(image[1112:1114], "little") * 128
    image[slot + 64:slot + 68] = (sparse_size // 4096).to_bytes(4, "little")
    fix_checksum(image)
    external = temp / "source-reader-sparse-device.erofs"
    external.write_bytes(image)
    report = run(cli, "extract-erofs-file", external, "large.bin", output, 512 * 1024 * 1024, sparse_device, "--working-memory-limit=65536").stdout
    expected = b"EROFS writer probe multi-block payload 0123456789\n" * 4096
    if output.read_bytes() != expected or b"peak_working_bytes=" not in report:
        raise AssertionError("Source reader failed to extract from an external device over 512 MiB")
    return 6
