# Partial extent fixtures

The four `partial-extent-{lz4,lzma,deflate,zstd}.erofs.b64` images retain the
compressed bytes and packed-prefix metadata from erofs-utils
1.9.4-g5fcb2f76's corresponding packed-prefix fixtures. A visible inode at
NID 96 points to the first physical compressed region through a 16-byte
modern extent record with `PARTIAL_REF`. The visible output is the first
17 bytes of the packed data, exactly
`06 00 01 76 6f 72 74 2e 07 00 01 6f 74 68 65 72 2e`.

The added inode is ordinary metadata; its directory entry and superblock CRC
were updated. fsck.erofs independently extracts that prefix for every codec.
These are wire variations of reference data, rather than a claim that mkfs
produces these inode layouts by default.

`reader/tests/partial_helpers.zig` varies 4/8/16/32-byte records, legacy
full-index bit-15 references, zero-length holes, whole fragments and mixed
partial-reference/fragment files. Prefix comparisons obtain actual complete
extent sizes and data through the public reader, since a reference extent can
decode to much more than 4 KiB. `tools/erofs/partial_diff.py` constructs these
layouts independently, checks fsck and Vort output, and adds literal/match
prefix cuts. Native tests additionally exercise ranges, tiny output schedules,
decoder limits, corruption, recursion and exhaustive allocation failures.
