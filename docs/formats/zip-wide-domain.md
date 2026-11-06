# Wide ZIP metadata, readers and Deflate64 writers

ZIP64 records describe logical stream sizes independently of an addressable
slice. `core.StreamCount` is `u64` on 32-bit targets and preserves `usize` on
64-bit targets. Cumulative sizes, pledges and positions use this type; physical
buffers, capacities, indices and per-call `core.Progress` remain `usize`.

## Canonical metadata and complete-output APIs

`zip.Entry.uncompressed_size` describes logical output. `Archive.entryAt`,
iterators and queries can therefore report a >4 GiB decoded size from a small,
real borrowed archive. Its `compressed_size`, central/local header offsets and
compressed payload remain physical positions in `Archive.bytes`.

The record parser has separate logical central/local size resolvers for readers
that do not retain a complete archive. They preserve compressed sizes and
relative positions in the wide domain. Canonical complete-archive wrappers
check the local fit of compressed spans and header positions without narrowing
the logical decoded length.

Complete-output extraction verifies canonical entry identity before copying or
allocating. Its logical output cap is wide; conversion to a local allocation or
slice length is checked separately. A valid 32-bit metadata query may succeed
while requesting its complete plaintext returns `IntegerOverflow` or a caller
capacity error. Forged entry lengths do not cause allocation before validation.

## Streaming reader and multi-part source

The incremental entry decoder and full ZIP source reader retain logical sizes,
expected counts, limits and cumulative input/output in the wide domain. ZIP64
local and central metadata, descriptor comparisons, encryption overhead and CRC
accounting use the same counts. Caller progress still describes only one actual
input/output buffer. Failed-call progress records the committed prefix and
remains stable after a sticky failure; reset validates replacement metadata.

A multi-part normalized source is a virtual view, rather than a concatenated
allocation. Global lengths, part bases, metadata patches and read positions are
wide. A read first finds the part and bounds its window, then converts local
slice indices. Source callbacks accept logical positions and return local byte
counts. Whole normalized-output convenience APIs retain checked physical
allocation limits.

## Complete Deflate64 compression

The incremental compressed Deflate64 writer uses wide accepted input, published
output, exact pledges, input caps and cumulative block/match statistics. Stored,
fixed, dynamic and adaptive wire choices keep their existing format behavior.
Its match index is rebuilt for each bounded pass over history and one block;
those local positions do not become absolute stream coordinates.

Full offered input and deterministic limits are checked before drain/acceptance.
Output drains share one remaining-counter window, return the last representable
prefix normally, and refuse a later overflow before copying. Block statistics
are checked before wire and history commit. Sticky failure progress, flush,
finish and reset preserve their public contracts.

## CLI file publication

`extract-zip-file-incremental` and `extract-zip-stream-file` call the same public
reader APIs. Their decoded output uses fixed 64 KiB buffers and a wide count;
verified output replaces the destination through an atomic temporary file.
CRC, truncation, limit or central-directory errors preserve the old destination.
The complete compressed-input archive retained by these commands keeps its
existing 512 MiB cap and SFX lookup behavior. The source-reader API and independent
long oracle separately exercise archives larger than one 32-bit input slice.

## Validation routes

```sh
zig build -j8 test-zip-wide-read-counts
zig build -j8 test-zip-wide-read-counts-x86
zig build -j8 test-zip-wide-read-counts-wasm
zig build -j4 run-zip-wide-read-diff -- --jobs 4
zig build -j4 run-zip-wide-read-long-diff -- --jobs 4
```

The public metadata fixture combines a ZIP32 tiny member with a real ZIP64 Zstd
RLE member whose small compressed payload describes `2^32 + 3` output bytes.
Tests check queries, borrowed payloads, limits, physical refusal, corrupt local
and central metadata, and rejected forged entries. Decoder/writer boundary
models are distinguished from actual wire replay and real complete sources.

`tools/zip/wide_read` verifies public canonical parsing and incremental reads on
native and x86. It reuses independently validated Deflate/Zstd large members,
produces actual Deflate64 output with the public writer, and checks it through
Info-ZIP. Stored archives replay actual >4 GiB compressed and decoded bytes.
Every sink bounds its buffers and verifies output bytes and CRC; complete 4 GiB
plaintext is not retained. Reports preserve pointer/count widths, library/tool
versions, binary hashes, actual byte totals and codec/reader heap records.

The validated native/x86 long campaign passes all 16 reader cases with actual
output 4,294,967,313 bytes and CRC32 473974062. Stored source readers each
consume 4,294,967,543 actual ZIP bytes, including a central directory at
4,294,967,371. Public Deflate64 writers generate 319,754-byte ZIP archives with
319,492-byte payloads from that complete source, and Info-ZIP verifies every
decoded byte. Physical 32-bit extraction refuses large complete plaintext
before invoking its allocator. No counter seeds stand in for these long flows.

The borrowed split-view fixture has logical length 4,295,032,996 and first
record offset 4,294,967,300, using one real 64 KiB tile. The split reader starts
at that offset, decodes the real 65,498-byte tail member, validates its CRC and
completes ZIP64 central/end metadata. Valid legacy disk sentinels `0xffff` are
accepted only alongside validated ZIP64 actual disk values.

Public native/x86/WASI gates pass their metadata/reader and Deflate64 contracts.
The complete native ZIP suite passes 2,412 tests with one platform-specific
skip; dedicated native/x86 reader suites each pass 191 tests. CLI tests verify
both file APIs on native/x86, including wide caps, correct output, and preserving
an existing destination after CRC or limit failure. Reproduction receipts are
in `zig-out/zip-wide-read-{smoke,long}/report.json`.

Both 32-bit CLI file commands also extract the real Deflate64 long archive,
write and independently re-read 4,294,967,313 output bytes, and verify CRC32
473974062 with bounded buffers. Temporary full output files are removed after
verification. The twelve small native/x86 CLI controls separately confirm
atomic destination preservation on checksum and output-limit failures.
