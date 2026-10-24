import os
import struct


def verify_packed_prefixes(cli, mkfs, fsck, temp, run):
    if mkfs is None:
        return 0
    source = temp / "packed-prefix-source"
    (source / "dir").mkdir(parents=True)
    payloads = {
        "small": b"packed prefix interoperability payload\n" * 29,
        "dir/other": b"other fragment\n" * 43,
        "large": b"packed prefix compressed data\n" * 3000,
    }
    attrs = {
        "/": {b"user.vort.root": b"root-value"},
        "small": {
            b"user.vort.repeat": b"repeated-value",
            b"user.other.detail": b"other-value",
        },
        "dir": {b"user.vort.repeat": b"repeated-value"},
        "dir/other": {b"user.vort.repeat": b"repeated-value"},
    }
    for name, data in payloads.items():
        (source / name).write_bytes(data)
    for name, attributes in attrs.items():
        path = source if name == "/" else source / name
        for key, value in attributes.items():
            os.setxattr(path, key, value)
    help_result = run(mkfs, "--help", check=False)
    help_text = help_result.stdout + help_result.stderr
    modes = [("stored", None, False)]
    for codec in ("lz4", "lzma", "deflate", "zstd"):
        if codec.encode() in help_text:
            modes.append((codec + "-compact", codec, False))
            modes.append((codec + "-full", codec, True))
    for label, codec, legacy in modes:
        image = temp / f"packed-prefix-{label}.erofs"
        command = [mkfs, "-T0", "--all-root", "--xattr-prefix=user.vort.", "--xattr-prefix=user.other.", "-E", "fragments"]
        if codec is not None:
            command += ["-z" + codec, "-E", "all-fragments"]
        if legacy:
            command += ["-E", "legacy-compress"]
        run(*command, image, source)
        header = image.read_bytes()[1024:1152]
        if struct.unpack_from("<I", header, 8)[0] & 0x10 or not struct.unpack_from("<Q", header, 96)[0]:
            raise AssertionError(f"mkfs did not place prefixes in a packed inode for {label}")
        if header[91] != 2:
            raise AssertionError(f"unexpected packed prefix count for {label}")
        extracted = temp / f"packed-prefix-{label}-fsck"
        run(fsck, f"--extract={extracted}", "--no-preserve", "--xattrs", image)
        for path, attributes in attrs.items():
            listing = run(cli, "list-erofs-xattrs", image, path).stdout
            target = extracted if path == "/" else extracted / path
            for key, value in attributes.items():
                required = b"xattr\t" + key + b"\t" + value.hex().encode() + b"\n"
                if required not in listing or os.getxattr(target, key) != value:
                    raise AssertionError(f"packed prefix xattr mismatch for {label}/{path}/{key!r}")
        for path, expected in payloads.items():
            output = temp / f"packed-prefix-{label}.out"
            run(cli, "extract-erofs-file", image, path, output, len(expected), "--output-chunk-size=17")
            if output.read_bytes() != expected or (extracted / path).read_bytes() != expected:
                raise AssertionError(f"packed prefix payload mismatch for {label}/{path}")
    return len(modes)
