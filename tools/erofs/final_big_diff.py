def verify_final_big_pclusters(cli, mkfs, fsck, temp, help_text, make_image, run):
    source = temp / "final-big-tree"
    source.mkdir()
    state = 0x8F12_3456
    prefix = bytearray()
    for _ in range(8192):
        state ^= (state << 13) & 0xFFFF_FFFF
        state ^= state >> 17
        state ^= (state << 5) & 0xFFFF_FFFF
        prefix.append(state & 0xFF)
    payload = bytes(prefix) * 2
    (source / "tail.bin").write_bytes(payload)
    cases = 0
    for codec in ("lz4", "lzma", "deflate", "zstd"):
        if codec.encode() not in help_text:
            continue
        for legacy in (False, True):
            label = f"final-big-{codec}-{'full' if legacy else 'compact'}"
            image = temp / f"{label}.erofs"
            make_image(mkfs, source, image, codec, legacy, pcluster_size=65536)
            extracted = temp / f"{label}-fsck"
            run(fsck, f"--extract={extracted}", "--no-preserve", image)
            if (extracted / "tail.bin").read_bytes() != payload:
                raise AssertionError(f"erofs-utils final-pcluster mismatch for {label}")
            listing = run(cli, "list-erofs-file", image).stdout
            if b"\ttail.bin\t" not in listing:
                raise AssertionError(f"Vort final-pcluster listing mismatch for {label}")
            output = temp / f"{label}.out"
            run(cli, "extract-erofs-file", image, "tail.bin", output, len(payload))
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort final-pcluster extraction mismatch for {label}")
            cases += 1
    return cases
