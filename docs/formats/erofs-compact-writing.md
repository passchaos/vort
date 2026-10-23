# EROFS compressed index writing

All public EROFS encoding APIs accept
`ErofsWriterOptions.compressed_index_format`. The default is `.full`.

| Option | Header | Index representation |
| --- | --- | --- |
| `.full` | 16 bytes | One legacy eight-byte record per logical cluster |
| `.compact_4byte` | 8 bytes | Paired four-byte items in eight-byte packs |
| `.compact` | 8 bytes | Initial four-byte items to reach 32-byte alignment, sixteen-item two-byte packs, then paired four-byte tail items |

Logical clusters remain 4 KiB. `compression_extent_size` controls decoded
groups from 4 KiB through 1 MiB, and `max_pcluster_size` retains its physical
byte cap. Every index format supports LZ4, MicroLZMA, raw Deflate and
Zstandard, their compressed-or-PLAIN fallback, and the same allocator and
working-memory limits.

```zig
const options: vort.ErofsWriterOptions = .{
    .compression = .lz4,
    .compressed_index_format = .compact,
    .compression_extent_size = 65536,
    .max_pcluster_size = 8192,
};
const image = try vort.encodeErofsAlloc(allocator, &entries, options);
defer allocator.free(image);
```

The same options apply to `encodeErofsToSink` and caller-owned `ErofsEncoder`,
including borrowed callback/file sources, tiny output buffers, extended
inodes, shared/long-prefix xattrs, directory metadata zones, MZi metaboxes,
packed file tails and compressed-inline tails. Empty files and stored/chunk
layouts retain their own representations. Whole-file fragments use the
standard full-layout fragment header. A fragment offset above `u32` also
selects full indexes, which carry its high word; compact fragment headers
cannot represent that word.

The CLI exposes the same choice:

```sh
zig build run -- create-erofs-file output.erofs dir/data input.bin \
  lz4 65536 8192 --compressed-index-format=compact
```

Accepted CLI values are `full`, `compact-4byte` and `compact`. Existing output
is replaced only after successful encoding and Sink completion, including
when source and output refer to the same pathname. Invalid format names and
working-budget failures preserve existing output and remove temporary files.

## Layout and ownership

`writer/compact_indexes.zig` advances physical addresses by extents. A head
consumes one block unless the following CBLKCNT supplies its physical count.
Each pack chooses a shared physical base appropriate to its first item,
including packs beginning inside an earlier compressed extent. Both compact
big-pcluster flags are emitted together. The final ordinary NONHEAD item
stores forward distance; its backward distance is inferred by the reader.
CBLKCNT remains explicit even in the final item. Missing items in a final
paired pack are zero-filled.

`writer/compression_metadata.zig` owns header/index sizing, metadata bounds,
fragment fields and inline placement for all three formats. The pack encoder
writes into caller-owned metadata with fixed physical-progress state. The
existing logical index vector and normal writer ownership remain in place;
encoding does not allocate a second index table. Reference allocating
orchestration and the streaming writer produce identical bytes for the same
settings and input.

## Reproducible validation

```sh
zig build test-erofs
zig build test-erofs test-byte-source test-byte-sink -Doptimize=ReleaseFast
zig build run-erofs-compact-diff -Doptimize=ReleaseFast -- \
  --fsck /path/to/original-erofs-utils/fsck/fsck.erofs \
  --metabox-oracle-fsck /path/to/metabox-oracle/fsck/fsck.erofs \
  --range-oracle /tmp/vort-erofs-range-oracle
```

The [positional oracle build](../../tools/erofs/nonhead-oracle.md) uses an
unmodified liberofs. The separate
[metabox oracle](../../tools/erofs/metabox-inline-oracle.md) retains the
existing narrowly documented fix for erofs-utils metadata ownership during
metabox tail extraction.

The compact differential uses the shared writer mode catalog. It tests both
compact formats across memory, Source, Sink and resumable encoding, with
repeat-output determinism, exact output equality between surfaces, whole and
range public-API reads, all xattrs, original fsck extraction and original
positional reads. The complete `run-erofs-diff` also checks 14 CLI create/read
and same-path cases plus three atomic-failure cases. `--cli` can optionally
add those CLI cases to the compact differential.

Zig regressions additionally compare final-big index bytes with an immutable
independent fixture, cover every pack alignment and final count through 70
logical clusters, mixed compressed/PLAIN extents, 1 MiB decoded groups,
empty/tiny/exact-block files, physical discontinuities, invalid counts,
Source failures, high fragment offsets and exhaustive allocation failures.
