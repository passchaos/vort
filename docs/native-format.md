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

## Batch range summary APIs

`decodeRangesWithSummaryAlloc`, `decodeIndexedRangesWithSummaryAlloc`, and the
dictionary/sidecar batch variants decode multiple logical ranges after a single
index parse/validation step. Each returned `RangeDecodeResult` carries its own
bytes, offset, and CRC-32 summary. Batch `Into` variants such as
`decodeRangesInto`, `decodeIndexedRangesInto`, and
`decodeSidecarIndexedRangesAutoInto` fill caller-owned buffers and return per-
range write counts plus CRC-32 summaries. The batch APIs are intended for
workloads such as data-lake readers or archive manifests that need several small
slices from the same indexed stream without reparsing the embedded or sidecar
index for each request.
