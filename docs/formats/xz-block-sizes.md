# Explicit XZ Block Header sizes

Date: 2026-10-26. The public option, direct block alias fix and CLI flag are
implemented. Native/x86 functional, independent liblzma compatibility, actual
instrumented MT worker, Wasm and final build/help results are recorded in the
[functional baseline](../performance/xz-block-sizes-functional-baseline.md).

`XzEncodeOptions.include_block_sizes` and
`XzIncrementalEncoder.Options.include_block_sizes` default to `false`. The option
is independent of `parallel`: callers may declare sizes with serial or bounded
parallel one-shot encoding, and with the serial incremental encoder. The default
keeps the established XZ framing. Ordinary non-aliasing default block writes keep
the prior allocation and append order.

```zig
const encoded = try vort.encodeXzAlloc(allocator, input, .{
    .include_block_sizes = true,
    .block_size = 1024 * 1024,
});
defer allocator.free(encoded);

var encoder = try vort.XzIncrementalEncoder.initWithOptions(allocator, .{
    .include_block_sizes = true,
    .block_size = 1024 * 1024,
});
defer encoder.deinit();
```

The same one-shot option reaches Alloc, Into and transactional Append, including
stored and lazy entrypoints. Incremental block emission uses the same writer;
flush and finish declare the actual size of a partial block. `reset()` retains
the current option, while `nextStream(options)` and `nextStreamExactSize` use
the next stream's explicit options. Identical settings and block boundaries are
verified to produce identical serial/parallel/incremental block wires within
the baseline's bounded matrix; flush boundaries must match before comparing
complete streams.

## Wire fields

With `include_block_sizes = true`, each nonempty block declares both sizes in
its Block Header. The writer sets flag bits `0x40` and `0x80` and retains the low
filter-count-minus-one bits. For the existing preprocessing chain followed by
LZMA2, the flags byte is `0xc0 | preprocessing_filter_count`. It writes the
Compressed Size VLI, then the Uncompressed Size VLI, before filter descriptions.

| Field | Exact meaning |
| --- | --- |
| Compressed Size | Complete LZMA2 payload length, including the final zero end marker; excludes the Block Header, Block Padding and Check |
| Uncompressed Size | Original plaintext block length before preprocessing filters |
| Index Unpadded Size | Block Header including its CRC, LZMA2 payload and Check; excludes Block Padding |

Sizes use canonical XZ VLIs with the existing 63-bit maximum. Header length,
Header CRC-32, four-byte block alignment and Index records are calculated from
the new framing, and the stream's Index/Footer use those records. The content
Check still covers original plaintext. Empty streams have no blocks and gain no
synthetic size declaration.

The decoder already parses the optional sizes and validates them against actual
LZMA2 progress. This increment adds encoder declarations, with malformed-size,
VLI and Header CRC regression checks recorded in the functional baseline.

## Storage, aliases and failures

Exact Compressed Size requires completing a block payload before writing its
header. The true branch temporarily owns that complete payload, plus filter
scratch when applicable. These are real allocations through the supplied
allocator. Only explicitly enabled `ParallelOptions` supplies a whole-operation
requested-heap cap: those allocations pass through its shared budget and can
cause `WorkingMemoryLimitExceeded`, without shrinking block boundaries. Serial
one-shot has no separate whole-heap option. Incremental
`max_pending_output_len` limits logical pending bytes; it does not cap the
temporary payload or all allocator requests. `MatchOptions.max_working_memory`
is an inner matcher/parser budget, not a cap on the new payload storage.
Existing complete one-shot output staging and Index storage still grow with
total output. Incremental encoding remains block-bounded and serial, with an
additional temporary payload during each block emission. This option establishes
no constant-memory, zero-allocation or RSS guarantee.

The direct block writer now captures an input slice that overlaps the output
allocation before header growth, payload growth or the final plaintext Check can
invalidate it. Both sized and default branches use this early copy; default
non-aliasing input adds no copy allocation. A failed block append restores the
original output length, and temporary input/filter/payload storage is released.
Public one-shot publication retains its established transactional contract;
incremental errors retain that API's progress contract rather than undoing bytes
already returned by earlier calls.

## CLI

XZ file encoding accepts `--block-sizes`, `--block-sizes=true` and
`--block-sizes=false` after positional arguments. Omission preserves false;
the shorthand enables declarations. Boolean values must be exactly lowercase
`true` or `false`; empty, invalid or duplicate values reject. The explicit flag
overrides a preset independently of option order and does not enable parallel
encoding.

```sh
zig build run -- encode-xz-file input.bin output.xz --block-sizes
zig build run -- encode-xz-stored-file input.bin output.xz --block-sizes=true
zig build run -- encode-xz-file input.bin output.xz --block-sizes=false
```

LZMA-Alone, raw LZMA2 and MicroLZMA commands reject an explicit flag, including
false, with `UnsupportedXzBlockSizesOption`. The CLI contract and actual public
CLI-module gate verify successful content/size declarations and rejected-output
preservation; the final full CLI help includes the option.

## liblzma multithreaded decoder scope

In liblzma 5.8.4, both declared header sizes are necessary for parallel block
decoding. Index sizes at the stream end do not replace them. Default unsized
blocks remain valid XZ and enter its serial direct mode. Enabling the option
removes this missing-header condition, but multiple blocks, decoder thread and
memory limits, supported filters and I/O still control actual worker activity.

The native/x86 campaigns each pass 129/129. For a specific 262177-byte input
split into nine 32 KiB blocks, the separately compiled test-only liblzma 5.8.4
counter build completes nine jobs on three distinct workers, with naturally
overlapping decode-call activity peaking at three. The same unsized stream uses
nine direct blocks for missing sizes and no worker calls. Sized low-threading-
memory decoding (`memlimit_threading = 1`) also uses nine direct blocks and no
worker calls. Single-block and empty controls observe one and zero completed
worker identities. Original and instrumented libraries verify full plaintext
and exact stream input consumption separately.

These are actual scoped observations, not configured-thread-count evidence or
a promise that every sized stream uses three workers. The counter patch has its
own source/library identity, no artificial delay/barrier and no timing gate.
Declared sizes do not establish throughput gains or full liblzma MT feature
parity. Parallel incremental encoding and broader performance remain follow-up
work.
