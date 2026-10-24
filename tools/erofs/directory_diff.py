def verify_directory_streams(cli, writer, fsck, temp, run):
    if writer is None:
        return 0
    modes = (("stored", 10000, 32768), ("lz4", 10000, 131072), ("metabox", 1000, 1048576))
    for mode, count, work in modes:
        image = temp / f"directory-stream-{mode}.erofs"
        run(writer, image, count, mode)
        listing = run(cli, "list-erofs-file", image, f"--working-memory-limit={work}", "--max-directory-bytes=1048576").stdout
        lines = listing.splitlines()[1:]
        names = [line.split(b"\t")[1] for line in lines]
        expected = [f"f{index:05}".encode() for index in range(count)]
        if names != expected:
            raise AssertionError(f"streaming directory listing mismatch for {mode}")
        output = temp / f"directory-stream-{mode}.out"
        run(cli, "extract-erofs-file", image, expected[-1].decode(), output, 0, f"--working-memory-limit={work}")
        if output.read_bytes() != b"":
            raise AssertionError(f"streaming directory lookup mismatch for {mode}")
        if fsck is not None:
            run(fsck, image)
    return len(modes)
