import struct
import os


def verify_metadata_zones(cli, writer, fsck, dump, temp, run):
    if writer is None:
        return 0
    cases = 0
    expected = b"metadata-zone payload 0123456789\n" * 500
    attr = b"xattr\tuser.vort.zone\t" + b"directory-zone-attribute".hex().encode() + b"\n"
    names = [f"dir/item-{index:03}-with-long-metadata-zone-name".encode() for index in range(200)]
    for codec in ("stored", "lz4", "lzma", "deflate", "zstd"):
        for metabox in (False, True):
            mode = codec + ("-metabox" if metabox else "")
            image = temp / f"metadata-zone-{mode}.erofs"
            run(writer, image, mode)
            listing = run(cli, "list-erofs-file", image).stdout
            actual = [line.split(b"\t")[1] for line in listing.splitlines()[1:] if line.split(b"\t")[1].startswith(b"dir/item-")]
            if actual != names:
                raise AssertionError(f"metadata-zone directory mismatch for {mode}")
            for path in ("/", "dir", "file"):
                if attr not in run(cli, "list-erofs-xattrs", image, path).stdout:
                    raise AssertionError(f"metadata-zone attributes missing for {mode}/{path}")
            output = temp / f"metadata-zone-{mode}.out"
            run(cli, "extract-erofs-file", image, "file", output, len(expected), "--output-chunk-size=17")
            if output.read_bytes() != expected:
                raise AssertionError(f"metadata-zone extraction mismatch for {mode}")
            data = image.read_bytes()
            if not metabox:
                root = struct.unpack_from("<H", data, 1038)[0]
                root_at = struct.unpack_from("<I", data, 1064)[0] * 4096 + root * 32
                # Probe uses extended inodes. The first regular payload lies
                # beyond the contiguous primary metadata/directory reservation.
                if (struct.unpack_from("<H", data, root_at)[0] >> 1) & 7 not in (0, 2):
                    raise AssertionError(f"metadata-zone root is not a flat directory for {mode}")
            if fsck is not None:
                restored = temp / f"metadata-zone-{mode}-fsck"
                run(fsck, f"--extract={restored}", "--no-preserve", "--xattrs", image)
                actual = (restored / "file").read_bytes()
                if mode == "stored-metabox":
                    # erofs-utils 1.9.4's fsck raw-data path reads the inline
                    # metabox tail as primary bytes. dump uses the metadata
                    # reader and supplies an independent complete-file oracle.
                    if dump is None:
                        raise AssertionError("dump.erofs is required to verify stored metabox inline tails")
                    full_blocks = len(expected) // 4096 * 4096
                    if actual[:full_blocks] != expected[:full_blocks] or len(actual) != len(expected):
                        raise AssertionError(f"fsck metadata-zone physical data mismatch for {mode}")
                    if run(dump, "--cat", "--path=/file", image).stdout != expected:
                        raise AssertionError(f"dump metadata-zone full extraction mismatch for {mode}")
                elif actual != expected:
                    raise AssertionError(f"fsck metadata-zone extraction mismatch for {mode}")
                if sorted(path.name for path in (restored / "dir").iterdir()) != [name.decode().split("/")[-1] for name in names]:
                    raise AssertionError(f"fsck metadata-zone directory mismatch for {mode}")
                for entry in (restored, restored / "dir", restored / "file"):
                    if os.getxattr(entry, b"user.vort.zone") != b"directory-zone-attribute":
                        raise AssertionError(f"fsck metadata-zone restored attribute mismatch for {mode}/{entry.name}")
            cases += 1
    return cases
