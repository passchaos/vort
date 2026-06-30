# Vort

Vort is a Zig-first next-generation compression library project. Its long-term
objective is to surpass `zlib`, `zlib-ng`, `zlib-rs`, and `zstd` in both
functionality and performance while preserving explicit ownership, deterministic
behavior, robust validation, and library-first APIs.

The repository is currently in bootstrap form. The first implemented pieces are:

- zlib-compatible Adler-32;
- gzip/zip-compatible IEEE CRC-32;
- storage/network-oriented CRC-32C/Castagnoli;
- shared progress/error/frame metadata types;
- raw deflate stored-block encode/decode plus zlib/gzip-wrapped stored modes;
- a native `VORT` store frame that performs no compression yet, but validates
  frame layout, size accounting, CRC verification, one-shot APIs, allocator APIs,
  and bounded-output streaming APIs;
- a small CLI smoke surface, deterministic malformed-frame smoke corpus, and checksum benchmark entrypoint.

## Commands

```sh
zig build test
zig build check
zig build run -- --help
zig build run -- checksum "hello vort"
zig build run -- store-roundtrip "hello vort"
zig build run -- zlib-store-roundtrip "hello vort"
zig build run -- gzip-store-roundtrip "hello vort"
zig build run -- zlib-fixed-roundtrip "hello vort"
zig build run -- gzip-fixed-roundtrip "hello vort"
zig build run -- decode-raw-hex cb48cdc9c90700
zig build run -- decode-zlib-hex 7801cb48cdc9c90700062c0215
zig build run -- decode-gzip-hex 1f8b0800000000000403cb48cdc9c9070086a6103605000000
zig build run-fuzz-smoke
zig build run-fuzz-corpus
zig build run-checksum-diff
zig build run-zlib-diff
zig build run-gzip-diff
zig build run-python-zlib-diff
zig build run-compression-report
zig build run-file-corpus-report -- README.md docs/roadmap.md
zig build bench-checksum -Doptimize=ReleaseFast
zig build bench-deflate-decode -Doptimize=ReleaseFast
zig build bench-deflate-encode -Doptimize=ReleaseFast
```

## Current API sketch

```zig
const vort = @import("vort");

const adler = vort.adler32("payload");
const crc = vort.crc32("payload");
const encoded = try vort.storeEncodeAlloc(allocator, "payload");
defer allocator.free(encoded);
const decoded = try vort.storeDecodeAlloc(allocator, encoded);
defer allocator.free(decoded);
```

## Direction

See `docs/native-format.md` for the initial native Vort frame direction.

Compatibility formats (`raw deflate`, `zlib`, `gzip`, and selected zstd-facing
workflows) should be behavior-compatible where claimed. Native Vort formats may
innovate more aggressively, but they must be versioned, documented, fuzzed,
benchmarked, and differentially tested against reference implementations where a
reference exists.
