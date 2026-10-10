# zchunk

Vort implements the zchunk v1 (`.zck`) format in pure Zig. zchunk divides a
file into independently compressed chunks so unchanged chunks can be reused or
downloaded by range.

The reader validates canonical compressed integers, the lead and header hash,
full compressed-data hash, every compressed chunk hash, index counts and byte
ranges, the mandatory dictionary entry, optional elements, signatures, stream
IDs, source hashes, and exact body length. SHA-1, SHA-256, SHA-512, and the
zchunk-specific first-128-bits-of-SHA-512 mode are supported. Full files,
detached/header-only metadata, uncompressed chunks, Zstd chunks, raw or standard
Zstd dictionaries, and source-hash headers can be parsed.

Decoding is available for the default stream, a caller-selected stream, or one
indexed chunk. Allocating APIs enforce explicit output limits. Returned archive
and entry metadata borrow the caller's input bytes.

The deterministic writer uses caller-selected fixed chunk sizes and emits
either independent Zstd frames or uncompressed chunks. It currently writes a
single default stream, an empty dictionary entry, no optional elements, and no
signatures; readers accept the broader v1 structures described above.

```sh
zig build run -- encode-zchunk-file input.bin output.zck 65536 zstd normal
zig build run -- inspect-zchunk-file output.zck
zig build run -- extract-zchunk-chunk output.zck 1 first-chunk.bin 65536
zig build run -- decode-zchunk-file output.zck restored.bin 536870912
zig build run-zchunk-diff
```

CI builds a pinned zchunk reference implementation and validates Vort output
with `zck_read_header --verify` and `unzck`. The reverse direction covers normal
and dictionary-backed reference files.
