# BGZF blocked gzip support

Vort provides dependency-free BGZF parsing, deterministic writing, bounded
decoding, and virtual-offset range extraction on top of the existing raw
DEFLATE implementation.

`parseBgzf` walks every independent gzip member and requires a well-formed
`BC` extra subfield. `BSIZE + 1` is checked against the 65,536-byte BGZF block
limit, optional gzip name/comment/header-CRC fields are bounded, and block
trailers expose CRC-32 and `ISIZE`. Data after the canonical EOF marker is
rejected.

`decodeBgzfAllocLimited`, `decodeBgzfInto`, and decoded-size preflight validate
each raw DEFLATE stream, exact output size, and CRC-32 independently. A corrupt
member cannot be hidden by a later valid member.

`encodeBgzfAlloc`, `encodeBgzfAppend`, and `encodeBgzfInto` create independent
blocks and append the standard 28-byte EOF marker by default. Writers try the
caller-selected block size up to 64 KiB and automatically retry incompressible
64 KiB chunks at the safe 65,280-byte size so the complete encoded member still
fits the 16-bit `BSIZE` field.

BGZF virtual offsets are represented by `BgzfVirtualOffset`, with a 48-bit
compressed block offset and 16-bit uncompressed in-block offset.
`decodeBgzfRangeAlloc` validates both block boundaries and extracts ranges that
cross blocks without decoding unrelated earlier blocks.

```sh
zig build run -- encode-bgzf-file input.bin output.bgz
zig build run -- inspect-bgzf-file output.bgz
zig build run -- decode-bgzf-file output.bgz decoded.bin 536870912
zig build run -- decode-bgzf-range output.bgz slice.bin \
  START_VIRTUAL END_VIRTUAL 1048576
```

`run-bgzf-diff` compares Vort output with Python's gzip/zlib implementation and
the optional system `gzip -t`, and decodes independently generated BGZF blocks.
