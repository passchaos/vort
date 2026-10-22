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
        run(*command)
        output = temp / f"file-source-{number}.out"
        run(cli, "extract-erofs-file", image, "dir/payload", output, len(payload))
        if output.read_bytes() != payload:
            raise AssertionError(f"file-source self decode mismatch for {codec}/{extent}/{capacity}")
        if fsck is not None:
            destination = temp / f"file-source-{number}-fsck"
            run(fsck, f"--extract={destination}", "--no-preserve", image)
            if (destination / "dir/payload").read_bytes() != payload:
                raise AssertionError(f"file-source oracle mismatch for {codec}/{extent}/{capacity}")
    return len(modes)
