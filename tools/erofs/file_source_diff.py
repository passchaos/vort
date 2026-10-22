def verify_file_sources(cli, fsck, temp, payload, run):
    source = temp / "file-source-input.bin"
    source.write_bytes(payload)
    modes = [("stored", 4096, None)]
    for codec in ("lz4", "lzma", "deflate", "zstd"):
        modes.extend(((codec, 4096, None), (codec, 65536, None), (codec, 65536, 4096)))
    for number, (codec, extent, capacity) in enumerate(modes):
        image = temp / f"file-source-{number}.erofs"
        command = [cli, "create-erofs-file", image, "dir/payload", source, codec, extent]
        if capacity is not None:
            command.append(capacity)
        report = run(*command).stdout
        if b"peak_working_bytes=" not in report:
            raise AssertionError("file writer did not report Sink working-memory accounting")
        output = temp / f"file-source-{number}.out"
        run(cli, "extract-erofs-file", image, "dir/payload", output, len(payload))
        if output.read_bytes() != payload:
            raise AssertionError(f"file-source self decode mismatch for {codec}/{extent}/{capacity}")
        if fsck is not None:
            destination = temp / f"file-source-{number}-fsck"
            run(fsck, f"--extract={destination}", "--no-preserve", image)
            if (destination / "dir/payload").read_bytes() != payload:
                raise AssertionError(f"file-source oracle mismatch for {codec}/{extent}/{capacity}")
    # A rejected working budget must leave an existing output intact and
    # remove the temporary file used by the CLI's atomic replacement.
    image = temp / "file-sink-failure.erofs"
    image.write_bytes(b"keep existing output")
    before = set(temp.iterdir())
    failed = run(cli, "create-erofs-file", image, "payload", source, "lz4", 4096, 4096, 1, check=False)
    if failed.returncode == 0 or b"WorkingMemoryLimitExceeded" not in failed.stderr:
        raise AssertionError("file sink working-budget rejection was not reported")
    if image.read_bytes() != b"keep existing output" or set(temp.iterdir()) != before:
        raise AssertionError("failed file sink replaced output or leaked a temporary file")
    # Reading and replacing the same pathname must preserve source bytes
    # until encoding has completed.
    same_path = temp / "file-sink-same-path.bin"
    same_path.write_bytes(payload)
    run(cli, "create-erofs-file", same_path, "payload", same_path, "lz4")
    output = temp / "file-sink-same-path.out"
    run(cli, "extract-erofs-file", same_path, "payload", output, len(payload))
    if output.read_bytes() != payload:
        raise AssertionError("file sink truncated its input before encoding")
    return len(modes)
