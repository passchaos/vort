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
reads. Partial deflate-frame ranges still use the decoded-frame cache path so
subranges can be copied safely after the frame checksum has been verified.

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
inflating the compressed patch payload; partial dictionary ranges continue to use
the decoded-frame cache path so subranges share one verified decoded copy within
batch requests. Allocator-returning dictionary frame decoders also have
exact-size and output-limited variants, matching the non-dictionary native safety
surface while still requiring the caller-supplied dictionary bytes. Deflate-
wrapped dictionary patches bound the intermediate inflated patch size from the
declared decoded output length and reject non-progress literal operations, so a
small final payload cannot force unbounded patch materialization.

## Long-distance decode-into and full-frame range fast path

Native LDM frames also expose a caller-owned decode path. Literal operations copy
directly into the provided buffer, while match operations replay from already
produced bytes one byte at a time so overlapping back-references keep the same
semantics as the allocator-returning decoder. Full-frame LDM range reads now use
that decoder to fill the caller range buffer and validate the frame CRC-32
without allocating a temporary whole-frame decoded copy; partial LDM ranges still
use the decoded-frame cache path.
