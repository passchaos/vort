# Native Vort format direction

This document records the initial native `vort` format direction. Compatibility
formats (`raw deflate`, `zlib`, `gzip`) are constrained by RFC behavior; the
native format is where Vort can exceed `zlib`, `zlib-ng`, `zlib-rs`, and `zstd`
without inheriting all historical wire-format tradeoffs.

The current implemented native v0 frame supports store/no-compression,
deflate-compressed, RLE-compressed, caller-supplied dictionary-patch, and
long-distance-reference payload modes. Concatenated v0 streams can embed a
skippable serialized index with per-frame checksum metadata validated during
range decode. Sidecar-index validation has explicit modes:
`inspectHeader`/`inspectFrame`/`inspectFrameExact` expose frame mode, encoded
length, payload length, raw header metadata, and whether the frame requires a
caller-supplied dictionary before callers allocate decode buffers; the
header-only variant works before the full payload is available, while the exact
variant rejects trailing bytes for single-frame inputs.
`inspectConcatenated` extends the same preflight idea across concatenated native
streams by reporting data-frame count, total uncompressed bytes, combined CRC-32,
mode counts, and whether any member requires a dictionary without decoding
payloads. `inspectConcatenatedWithOptions` can enforce expected frame count,
total uncompressed length, and combined checksum using only frame headers.
`SidecarValidationMode.metadata` checks sidecar/index structure and frame-header
agreement without decoding payloads, while the default
`SidecarValidationMode.full` decodes each referenced frame so it detects payload
corruption that would not change sidecar bytes or frame headers.
`validateEmbeddedIndexAlloc` and `validateSidecarIndexAlloc` auto-load embedded
dictionaries in full mode, while `validateSidecarIndexWithDictionaryAlloc` and
`validateSidecarIndexWithOptionsAlloc` cover external-dictionary streams.
Full validation decodes frames into a reusable scratch buffer, so validating many
same-sized or smaller frames avoids repeated decoded-payload allocations while
preserving the same checksum/error semantics.
`validateSidecarIndexReportAlloc` and `validateEmbeddedIndexReportAlloc` return
structured failure context (validation mode, stage, frame index/offset,
uncompressed offset, numeric frame flags, readable frame mode, recoverability
hint, and error name) for diagnostics without replacing the throwing APIs.
`SidecarValidationOptions.expected_total_uncompressed` and
`expected_checksum` let callers enforce a known logical payload length and
whole-stream CRC-32 from index metadata before optional full payload decoding.
`run-sidecar-verify-report` includes the same context columns/fields in CSV,
Markdown, and JSON output when validation fails. JSON validation artifacts carry
stable `schema` and `schema_version` fields so scripts can gate compatibility.
See `validation-json.md` for the current schema field reference.
`run-sidecar-corrupt-smoke` exercises the distinction by mutating payload bytes
across store, deflate, RLE, dictionary, LDM, self-contained dictionary sidecar,
seekable native sidecar, and embedded-index streams: metadata validation
succeeds by contract, and full validation rejects each corrupted stream. The
same smoke can write Markdown and JSON artifacts for CI/dashboard retention via
the report tool's `--markdown` and `--json` flags. The seekable native encoder
integrates these production paths:
`encodeSeekableNativeStreamAlloc` emits an embedded-index stream and
`encodeSeekableNativeSidecarStreamAlloc` keeps the index external while selecting
store/deflate/RLE, trained dictionary-patch/deflate, and LDM reference frames per
block. It can embed the trained dictionary as skippable metadata, align blocks
around LDM candidates, preserve indexed range decode, and append skippable
long-distance-match summaries for encoder/planner feedback. Future native
versions should preserve the same engineering constraints: explicit sizes,
bounded memory, deterministic decoding, independent corruption localization, and
simple parser states that can be fuzzed aggressively.

## Goals

- Splittable by construction: large streams should be independently decodable by
  block or seek point without scanning from the beginning.
- Strong indexing: optional frame indexes should support byte-range lookup,
  uncompressed offsets, checksums per block, and external sidecar indexes; the
  current serialized v0 index records each frame checksum, can be validated
  against the target stream either by cheap metadata checks or by full referenced
  frame decoding, and rejects mismatched, payload-corrupt (full mode), or
  non-monotonic range-decode sidecars; sidecar-indexed encoders can keep the
  index external, and sidecar index bytes can drive range decode without an
  embedded index, including streams that embed or require a dictionary.
- Dictionary-first: content dictionaries should carry stable IDs, training
  metadata, window constraints, and compatibility hints.
- Multi-mode compression: store, fixed-Huffman deflate-compatible, dynamic
  Huffman, future ANS/FSE-style entropy, long-distance matching, and specialized
  small-payload modes can coexist behind explicit block type tags.
- Deterministic parallelism: encoders may use threads, but deterministic mode
  must produce stable bytes for the same input/config/dictionaries.
- Safety limits: decoders must be able to reject frames by declared memory,
  window, dictionary, block size, output size, and checksum policy before large
  allocations.

## Proposed high-level layout

```text
frame := magic version flags header_len header_crc blocks [index] frame_footer
block := block_header payload block_checksum
index := seek_points block_summaries optional_dictionary_refs
```

The exact byte layout is intentionally not frozen yet. Before implementation,
write golden vectors and version the format so experimental encoders do not
accidentally become permanent compatibility promises.

## Block metadata candidates

Each block should eventually expose:

- compressed size and uncompressed size;
- uncompressed offset for seek/index use;
- block type and entropy mode;
- window/dictionary reference;
- checksum choice and checksum value;
- optional content features such as long-distance match source or skippable
  metadata.

## Validation requirements before freezing v1

- Corpus round trips for tiny, text, JSON, source, binary, repetitive, random,
  and already-compressed inputs.
- Fuzz targets for frame headers, indexes, block headers, and each entropy mode.
- Differential compatibility tests for any deflate-compatible block mode.
- Benchmarks against zlib, zlib-ng, zlib-rs, and zstd on the same machine.
- A documented migration story for experimental v0 frames.

## Frame-index checksum composition

`frameIndexCombinedChecksum` composes the per-frame CRC-32 values recorded in a
validated frame index into the CRC-32 of the logical concatenated payload. It
uses the same `crc32Combine` primitive as other blocked/parallel checksum paths,
so callers that already trust or have validated an index can compute whole-stream
checksum metadata without decoding or rereading every frame payload. Normal
sidecar/embedded validation remains responsible for proving that frame bytes and
index entries match. Successful `ValidationReport` values expose the combined
checksum, frame count, and total indexed uncompressed byte count for callers that
need a whole-stream summary; callers can also feed those expected values back
through `SidecarValidationOptions` to reject mismatched sidecar/index metadata.
`summarizeFrameIndex` exposes the same frame count, total uncompressed length,
and combined checksum directly for callers that already have trusted index
entries and do not need a full validation report.
Serialized frame indexes also expose `frameIndexEntryCount` and caller-owned
`decodeFrameIndex`, so callers can preflight sidecar buffer sizes and decode
index entries without forcing an allocation.
Embedded-index helpers mirror that shape: `viewEmbeddedIndex` returns the
borrowed serialized index payload, payload offset, and entry count, while
`decodeEmbeddedIndex` fills caller-owned entry storage.
Indexed and sidecar range decode also expose `WithIndexBuffer` variants that
reuse caller-owned index entry storage for callers that want to avoid allocating
while parsing the embedded or sidecar index; non-dictionary compressed range
variants can use `RangeDecodeBuffers`/payload scratch for partial-frame reads,
while dictionary-aware range variants offer a richer `DictionaryRangeDecodeBuffers` form for callers that already have
dictionary bytes, and auto/self-contained dictionary variants combine borrowed
embedded dictionary bytes with the same caller-owned index/payload/patch storage.
Full sidecar/embedded validation can likewise accept caller-provided index,
payload scratch, and dictionary-deflate patch scratch buffers, letting trusted
validation loops avoid parser/scratch allocations when their maximum frame sizes
are already known; report-producing validation APIs expose the same buffer-reuse
path. `sidecarValidationBufferSizesForIndex`,
`sidecarValidationBufferSizesForSidecarIndex`, and
`sidecarValidationBufferSizesForEmbeddedIndex` preflight the required validation
entry count, payload scratch length, and dictionary-deflate patch scratch length.
Default full validation pre-reserves payload scratch capacity from the largest
indexed frame to avoid repeated growth across many frames, while callers that
need dictionary-deflate validation to stay zero-allocation should provide both
payload and patch scratch explicitly.

## Store-frame streaming state reuse

`Encoder`, `Decoder`, `AnyDecoder`, and `IncrementalDecoder` support
caller-owned state reuse via `reset`. This lets streaming callers process
multiple native frames without reallocating or reinitializing state objects, while retaining explicit progress
accounting and checksum verification at frame boundaries. Both decoders expose a
common `StreamingDiagnostics` view via `diagnostics`; `Encoder.snapshot`,
`Decoder.snapshot`, `AnyDecoder.snapshot`, and `IncrementalDecoder.snapshot`
retain type-specific fields for callers that need more detail. Diagnostics include the current phase,
cumulative frame input bytes when available, emitted output bytes, expected
payload/frame length, remaining bytes, and the most recent error name/phase plus
recoverability hint so callers can attach byte-accurate diagnostics to stalled or
corrupt streaming sessions. `AnyDecoder` borrows store-frame payloads directly
and uses caller-owned payload scratch for compressed native frames before draining
bounded output chunks; dictionary-patch/deflate members additionally accept
caller-owned patch scratch through `initWithDictionary`/`resetWithDictionary`.

## Zlib bounded-output decoder

`ZlibDecoder` accepts a complete zlib-wrapped deflate stream or caller-provided
zlib byte chunks (for example concatenated PNG IDAT chunk data), including preset
dictionary streams, decodes it into caller-owned scratch, and then drains the
result through bounded output chunks.
This is the wrapper shape used by PNG IDAT data, so multi-filter RGB/RGBA PNG-like zlib payloads—including varied row widths—can use
Vort without an output allocation when the decoded size is known or preflighted.
Exact-size initializers reject streams whose decoded size differs from the caller's
PNG/IHDR-derived expectation before any bounded-output drain begins. For PNG
consumers that want scanline-sized reads, `stepPngScanline` drains exactly one
decoded row at a time, returns the row filter byte separately, validates the
filter method range 0..4, and copies only the row payload bytes into the caller's
row buffer. `reconstructPngScanline` and `stepPngScanlineReconstruct` implement
PNG filter methods 0 through 4 with caller-owned current/previous row buffers, so
library callers can progress from IDAT zlib bytes to reconstructed scanlines
without allocating intermediate image rows. `pngImageInfo` computes PNG/IHDR
row length, filter stride, and exact zlib payload size from width, height, bit
depth, and color type, including sub-byte grayscale/indexed rows.
`pngZlibDecodeBufferSizes` and `pngIdatChunksScratchLen` expose the caller-owned
scratch and output sizes needed by the row and full-image helpers.
`PngZlibScanlineDecoder` packages the chunked zlib decode scratch, filtered-row
scratch, previous-row scratch, and row metadata into a reusable row pipeline for
callers that want one API to produce reconstructed rows from IDAT chunks.
`decodePngZlibImageFromChunks` drains the same pipeline into a caller-owned full
image buffer when the caller wants a complete reconstructed image without a
separate row loop.
`pngAdam7Info` plans Adam7 interlace passes, including per-pass dimensions,
row bytes, exact filtered payload bytes, maximum row scratch, and final image
output size, so interlaced PNG support can preflight memory before decoding pass
payloads.
`placePngAdam7Row` and `placePngAdam7Pass` scatter reconstructed pass rows into
the final packed image buffer for both byte-aligned and sub-byte grayscale/indexed
formats.
`decodePngAdam7ZlibImageFromChunks` combines zlib decoding, pass-row
reconstruction, and Adam7 placement for PNG-like interlaced IDAT payloads,
including packed sub-byte indexed/grayscale rows and 16-bit RGBA rows, when the
caller has provided all required scratch buffers. The helper rejects corrupt filter bytes and
decoded payload length mismatches before accepting an interlaced image.
`zig build run-png-scratch-report` records caller-owned scratch and output
footprints for representative non-interlaced and Adam7 PNG-like zlib paths, which
provides a baseline for future incremental inflate work to reduce peak memory.
`ZlibDecoder` also records wrapper/header, missing-dictionary, truncation,
Adler-32 mismatch, and PNG row-boundary diagnostics through the shared
`StreamingDiagnostics` surface.

`GzipDecoder` provides the same caller-owned bounded-output shape for ordinary
gzip-wrapped deflate streams. It accepts either a complete gzip member or
caller-provided gzip byte chunks, decodes and validates that member into
caller-provided scratch, then drains the scratch through caller-sized output
chunks without requiring an allocator in the decode/drain path. Concatenated gzip
member initializers use the same scratch contract and preserve empty middle
members while draining the combined logical payload. Exact-size initialization is
intended for callers that already know the uncompressed length from surrounding
metadata; it rejects length mismatches before exposing any payload bytes. Gzip
header, truncation, CRC-32, and ISIZE failures are retained in the shared
diagnostics view with recoverability hints for corrupt headers, truncated input,
or payload/footer corruption.

## Range decode summary APIs

`decodeRangeWithSummaryAlloc`, `decodeIndexedRangeWithSummaryAlloc`, and the
sidecar range summary variants return both the decoded bytes and a CRC-32 of the
returned logical range. Caller-owned output variants such as
`decodeRangeInto`, `decodeIndexedRangeInto`, and
`decodeSidecarIndexedRangeInto` fill a provided buffer and return the same
offset/CRC-32 summary, avoiding the final range allocation when callers already
own suitably sized storage. These variants preserve the same index, dictionary,
and bounds validation behavior as the byte-slice range APIs.
Allocator-returning single-range helpers are built on the caller-owned path, so
their behavior and fast paths stay aligned with `decodeRangeInto` while adding
only the final returned range buffer allocation.

## One-shot decode-into APIs

`decodeAnyInto` provides a caller-owned one-shot decoder for the non-dictionary
native frame modes: store, deflate, RLE, and LDM. It verifies the same size,
trailing-data, and CRC-32 contracts as `decodeAnyAlloc`, while avoiding the
allocator-returning helper's output allocation when the caller already knows the
frame's target buffer. Allocator-returning callers can use
`decodeAnyAllocExactSize` when they know the expected output length or
`decodeAnyAllocLimited` when they need to cap allocation before trusting frame
metadata. Dictionary frames still require the dictionary-specific decode APIs
because their correctness depends on caller-supplied dictionary bytes.
Concatenated native decode now uses the same per-frame decode path for
store/deflate/RLE/LDM frames, and dictionary-aware concatenated variants accept
caller-supplied dictionary bytes for dictionary-patch/deflate members. Both
surfaces expose exact-size and output-limited allocator variants for callers that
need bounded memory use across multi-frame inputs. Auto concatenated variants
reuse embedded dictionary metadata when present, matching the indexed range auto
decode behavior for self-contained dictionary streams. Caller-owned
concatenated `Into` variants report bytes written, decoded data-frame count, and
CRC-32 of the concatenated logical payload while avoiding the final output
allocation. Allocator-returning concatenated decoders preflight the stream with
`inspectConcatenated`, allocate the final output buffer once, and then reuse the
same `Into` path.
`inspectEmbeddedDictionary` validates the embedded dictionary skippable metadata
without allocating dictionary bytes and reports the dictionary ID, content length,
and skippable-frame offset for auto-decode preflight. Its options variant can
enforce an expected dictionary ID and content length before any decode path
allocates or copies dictionary bytes. `parseEmbeddedDictionary` returns a
borrowed slice into the input stream, and auto dictionary range/validation/
concatenated paths use that borrowed slice so self-contained dictionary streams
do not copy dictionary bytes just to decode immediately. `viewEmbeddedDictionary`
combines the borrowed slice and validated metadata in one scan for callers that
need both, and its options variant enforces expected dictionary ID/length while
still avoiding allocation.

## Batch range summary APIs

`decodeRangesWithSummaryAlloc`, `decodeIndexedRangesWithSummaryAlloc`, and the
dictionary/sidecar batch variants decode multiple logical ranges after a single
index parse/validation step. Each returned `RangeDecodeResult` carries its own
bytes, offset, and CRC-32 summary. Batch `Into` variants such as
`decodeRangesInto`, `decodeIndexedRangesInto`, and
`decodeSidecarIndexedRangesAutoInto` fill caller-owned buffers and return per-
range write counts plus CRC-32 summaries. The batch implementation caches
decoded frame payloads for the duration of one batch, so overlapping or nearby
ranges in the same indexed frame do not repeatedly decode that frame; allocating
summary batch APIs preflight all request bounds before allocating range buffers,
then reuse the same into/cache path before wrapping the buffers in
`RangeDecodeResult` values. The batch APIs are intended for workloads such as
data-lake readers or archive manifests that need several small slices from the
same indexed stream without reparsing the embedded or sidecar index for each
request.
The decoded-frame cache is allocated lazily, so batches fully satisfied by
store/RLE/full-frame compressed fast paths do not pay an extra cache allocation.

## Store-frame range fast path

Caller-owned range decode paths copy directly from store-frame payload slices when
the indexed frame is uncompressed. The fast path still validates the frame
header, size metadata, and full payload CRC-32 before copying the requested
subrange, but it avoids allocating and materializing a decoded copy of the whole
store frame. Non-store frames have their own mode-specific fast paths when a
caller range covers a whole frame; otherwise they continue through the normal
decode/cache path.

## Deflate full-frame range fast path

When a caller-owned range decode request covers an entire native deflate frame,
the range decoder sends the raw deflate payload directly into the caller's output
buffer and validates the resulting CRC-32 against the frame header. This avoids
allocating a temporary whole-frame decoded buffer for common block-aligned range
reads. Partial deflate/LDM-frame ranges can provide `RangeDecodeBuffers.payload_scratch`
through embedded-index or sidecar-index `WithBuffers` APIs, or use the lower-level
`decodeRangeIntoWithPayloadScratch` helpers to verify the whole frame in
caller-owned storage before copying the requested subrange; callers that omit
payload scratch keep the heap-backed decoded-frame cache path so subranges can be
copied safely after the frame checksum has been verified.

## RLE decode-into and range fast path

Native RLE frames expose a caller-owned decode path that expands each run with
`@memset` into the provided buffer and verifies the frame CRC-32. Range reads over
RLE frames stream through the compact run payload, validate the full-frame CRC as
they go, and copy only the overlapping logical run spans into the caller's range
buffer. This avoids materializing a whole decoded RLE frame for both full-frame
and partial range reads.

## Dictionary decode-into and full-frame range fast path

The dictionary patch codec now exposes caller-owned decode helpers
(`decodePatchInto`/`decodedPatchSize`) in addition to the allocator-returning
variant. Native dictionary-patch frames can use this path directly, so full-frame
dictionary range reads can materialize into the caller's target buffer and then
validate the frame CRC-32 without allocating a whole decoded frame. Native
dictionary-deflate frames use the same final patch decode-into step after
inflating the compressed patch payload. Dictionary range reads
can provide `DictionaryRangeDecodeBuffers` through the indexed, sidecar, auto,
or self-contained dictionary `WithBuffers` APIs so index parsing, full-frame
dictionary-deflate patch inflation, and partial decoded-frame materialization
reuse caller-owned storage.
`dictionaryRangeBufferSizesForIndex`, `dictionaryRangeBufferSizesForSidecarIndex`,
and `dictionaryRangeBufferSizesForEmbeddedIndex` preflight the required entry
count, largest decoded-frame `payload_scratch`, and matching maximum
`patch_scratch` length. When payload scratch is supplied to batch reads,
the implementation favors deterministic zero-allocation re-decode over the lazy
heap-backed decoded-frame cache; callers that omit payload scratch keep the cache
behavior so nearby subranges share one verified decoded copy within a batch.
Allocator-returning dictionary frame decoders also have exact-size and
output-limited variants, matching the non-dictionary native safety surface while
still requiring the caller-supplied dictionary bytes. Deflate-wrapped dictionary
patches bound the intermediate inflated patch size from the declared decoded
output length and reject non-progress literal operations, so a small final
payload cannot force unbounded patch materialization.

## Long-distance decode-into and full-frame range fast path

Native LDM frames also expose a caller-owned decode path, and partial LDM range
reads use the same `RangeDecodeBuffers.payload_scratch` zero-allocation path as
partial deflate reads. Literal operations copy directly into the provided buffer,
while match operations replay from already
produced bytes one byte at a time so overlapping back-references keep the same
semantics as the allocator-returning decoder. Full-frame LDM range reads now use
that decoder to fill the caller range buffer and validate the frame CRC-32
without allocating a temporary whole-frame decoded copy; partial LDM ranges still
use the decoded-frame cache path.
