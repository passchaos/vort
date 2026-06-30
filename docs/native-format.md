# Native Vort format direction

This document records the initial native `vort` format direction. Compatibility
formats (`raw deflate`, `zlib`, `gzip`) are constrained by RFC behavior; the
native format is where Vort can exceed `zlib`, `zlib-ng`, `zlib-rs`, and `zstd`
without inheriting all historical wire-format tradeoffs.

The current implemented native v0 frame supports store/no-compression,
deflate-compressed, RLE-compressed, and caller-supplied dictionary-patch payload
modes. Concatenated v0 streams can embed a skippable serialized index, and the
blocked best-mode stream encoder can select store/deflate/RLE per block while
preserving indexed range decode. Dictionary-aware blocked streams can also range
decode when the caller supplies the same dictionary. Future native versions
should preserve the same engineering constraints: explicit sizes, bounded
memory, deterministic decoding, independent corruption localization, and simple
parser states that can be fuzzed aggressively.

## Goals

- Splittable by construction: large streams should be independently decodable by
  block or seek point without scanning from the beginning.
- Strong indexing: optional frame indexes should support byte-range lookup,
  uncompressed offsets, checksums per block, and external sidecar indexes.
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
