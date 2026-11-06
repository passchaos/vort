# Brotli and Zstd wide decoded sizes

Count-only interfaces report logical stream quantities with `core.StreamCount`:
`u64` on 32-bit targets and the existing `usize` on 64-bit targets. Small
compressed inputs can describe output larger than 4 GiB without requiring a
plaintext allocation or a large caller buffer.

Brotli `decodedStreamSize*`, `summarizeStream*`, and `probeStream*` retain this
type for decoded totals, logical limits, expected sizes, cumulative statistics
and diagnostic coordinates. This includes allocator/history/options variants,
metadata, uncompressed and compressed blocks, RFC/Large Window streams, and
static/shared dictionaries. Long copy counting reconstructs only the final
visible history period needed by subsequent literals and references.

Zstd `decodedFrameSize*`, `decodedNativeFrameSize*`, raw/RLE size queries,
concatenated/chunk variants and reusable decoder size methods use the same
counter. `FrameDecodeOptions.max_output_len` and `expected_output_len` are
logical quantities. Frame/block counting is separate from output allocation;
compressed sequence visibility respects the frame window and retains external
dictionary history while the frame has not yet filled that window. Frame content
size and cumulative output limits remain checked across concatenated frames.

Slices, capacities, block-local lengths, ring slots and heap limits stay
`usize`. Complete-output alloc/append/Into paths check `toLocal` before
materializing a logical result. A 32-bit process can query a >4 GiB output size,
then receive `IntegerOverflow` if it requests that complete plaintext in one
physical slice. `max_total_working_memory` remains an independent `?usize`
quota. Size queries preserve their previous verification semantics: Zstd checks
checksum-footer presence; content checksum comparison belongs to decoding.

## Borrowed Brotli dictionary chunks

Static-dictionary chunk conveniences now sum borrowed source lengths with
checked `StreamCount` arithmetic. A stream can exceed 4 GiB while each chunk,
index and encoded result remains locally addressable. Admission runs before
alias capture, reusable output clearing or encoder reset. Input caps therefore
reject the complete offered source without damaging a previous reusable result.

The boundary contract borrows one real 1 MiB tile through 4096 descriptors,
then adds 17 bytes and empty chunks. This verifies exact-cap acceptance and
cap-minus-one rejection using about 1 MiB of source data. Deliberate first-allocation
OOM in cold public alloc/append routes proves wide admission separately from
full source encoding. The long oracle below performs the complete encoding.

## ZIP64 codec input boundaries

The ZIP streaming writer preserves Deflate/Zstd pledges and codec input caps
in the same logical domain. A ZIP64 entry's input no longer has to fit `usize`
before codec initialization or at the next input offer. Codecs with local input
caps retain their established limits, including the Deflate64 writer.

Public writer contracts cover the ZIP32 sentinel, large known pledges, codec
and archive limits, bounded prefixes and caller guards. A real four-case
native/x86 campaign writes and independently decodes 4,294,967,313 bytes per
Deflate/Zstd member. Both targets produce identical archive hashes and CRC32
473974062: the Deflate ZIP is 5,103,883 bytes and the Zstd ZIP is 262,428 bytes.
The probe reads only 82 bytes of its fixed central record; Python checks the
whole record structure and streamed payload with libz/libzstd. This avoids the
one-shot ZIP parser's existing 32-bit materialization restriction.

```sh
zig build -j8 test-zip-wide-codec-input test-zip-wide-codec-input-x86
zig build -j4 run-zip-wide-codec-input-diff
zig build -j4 run-zip-wide-codec-input-long-diff
```

## Empty dictionary references and statistics

Private meta-block byte statistics stay local because the declared block length
bounds their output. Command, dictionary-reference, distance and histogram
cardinalities can grow without output through empty serialized transforms, so
those quantities retain wide counters. Aggregate statistics use checked,
transactional merging into the wide stream summary.

Empty transformed words at absolute distance <=120 return `CorruptFrame` in
summary, complete decoding and progressive decoding. This matches experimental
Brotli 1.2.0 commit `558fc647cdaf391228d614ca85f711e02e4e583b`: direct distance
codes at that boundary can consume no bits and produce no bytes indefinitely.
Larger distances consume extra bits and retain valid empty-reference behavior.
The regression fixture distinguishes absolute distance from the dictionary
address after subtracting available history, checks truncation and resets, and
compares low/high-distance cases with that local reference.

## Reproducible validation

```sh
zig build -j8 test-br-zstd-wide-size-counts
zig build -j8 test-br-zstd-wide-size-counts-x86
zig build -j8 test-br-zstd-wide-size-counts-wasm
zig build -j4 run-br-zstd-wide-size-diff -- --jobs 4
zig build -j4 run-br-zstd-wide-size-long-diff -- --jobs 4
```

Native, actual x86 and WASI execute the same public contracts. Real compact
fixtures include >4 GiB RLE/compressed Zstd frames and Brotli streams with
compressed copies, metadata, stored blocks and dictionaries. Boundary models
are labeled separately from physical wire parsing and complete source replay.

`tools/wide_sizes` produces Brotli/Zstd wire through system streaming encoders,
then independently decodes it with 64 KiB sinks and checks every output byte
and CRC. Native/x86 probes measure the public count-only APIs. Dictionary
alloc/append probes replay borrowed `information` tiles through the complete
public encoder and pipe the generated wire to libbrotli. Reports record actual
source/output totals, ABI widths, library versions/hashes, probe hashes, heap
requests and release after deinit. No full plaintext is retained; dictionary
wire is streamed directly through a pipe. Evidence is written to
`zig-out/br-zstd-wide-size-{smoke,long}/report.json`.

The real eight-case wide-size matrix validates 4,294,967,313 decoded bytes in
each native/x86 case. Reference-produced Zstd wire is 131,103 bytes and Brotli
wire is 1,376,291 bytes. All four complete static-dictionary alloc/append cases
accept and independently decode the same full source length; encoded wire is
830,605,084 bytes, peak encoder requests are at most 847,123,606 bytes, and
live requested bytes return to zero. The complete-output API necessarily retains
that wire; source and reference sink buffers remain bounded to 1 MiB/64 KiB.
