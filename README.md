# Vort

Vort is a Zig-first next-generation compression library project. Its long-term
objective is to surpass `zlib`, `zlib-ng`, `zlib-rs`, and `zstd` in both
functionality and performance while preserving explicit ownership, deterministic
behavior, robust validation, and library-first APIs.

The repository is currently in bootstrap form. The first implemented pieces are:

- zlib-compatible Adler-32;
- gzip/zip-compatible IEEE CRC-32;
- storage/network-oriented CRC-32C/Castagnoli;
- portable slice-by-4/slice-by-8/slice-by-16 IEEE CRC-32, slice-by-32 IEEE CRC-32, and slice-by-8/slice-by-16/slice-by-32 CRC-32C fast paths, checksum dispatch reporting, and Adler-32/CRC-32/CRC-32C combine helpers for block/parallel checksum composition;
- shared progress/error/frame metadata types;
- pure Zig LZ4 frame/block
  decode/fallback encode with skippable/concatenated stream handling,
  optional content-size/checksum/block-checksum/Dictionary_ID fields,
  configurable frame block sizes, linked-block history encoding, encoded-block bounds, decoded-size
  preflight, bounded allocation for single/concatenated streams, bounded
  raw-block and skippable-frame encode-into/decoded-size preflight, inspectable
  native frame/block/skippable headers plus plain, standard-dictionary-aware, and dictionary-set-aware Zstd sequence-mode summaries, zero-allocation native stream/block
  iterators, reusable raw-block decoder, and
  caller-owned encode/decode-into/append, incremental frame encode with optional pledged content size and preset dictionary, plus reusable
  scratch encoder/decoder APIs; oversized incremental data frames release raw
  blocks directly, and compressed blocks use a resumable token cursor under
  arbitrary caller backpressure with no
  decoded-block scratch, including linked-block and preset-dictionary history;
  compressed-block checksums are validated before starting caller output;
  complete prevalidated frames switch to the same cursor instead of
  materializing the frame when a compressed block exceeds caller output;
  compressed blocks without block checksums also consume split input directly
  when the configured compressed-buffer cap is smaller than their payload;
  incremental skippable frames retain only their
  8-byte header while discarding or capturing arbitrary-size metadata directly
  from caller input,
  pure Zig native Zstandard frame encode/bounded/caller-owned decode with header
  options and decoded-size preflight, a
  dependency-free raw/RLE, literal-only compressed-block, single-/four-stream
  and treeless repeat Huffman-literals, minimal RLE-sequence, mixed
  RLE/predefined/FSE sequence-table, repeated sequence-table, and streaming
  default sequence compressed-block fallback encode/decode with exact
  RLE/predefined/compressed-FSE table arbitration, transactional cross-block
  sequence-table Repeat_Mode and repcode state, including wide blocks with more
  than 512 sequences, and
  frequency-aware single-/four-stream Huffman literal emission
  (covering the full direct-tree symbol range `0...128`, FSE-compressed
  high-byte weights, non-4-divisible four-stream splits, and treeless repeat
  trees across blocks), small-depth
  hash-chain large duplicate plus deeper duplicate
  candidate retention, RLE/predefined-table multi-duplicate, dictionary,
  repeated-pattern, and mixed duplicate/repeated/dictionary match emission with
  starts scanned up to 48 bytes and periods up to 64 bytes, exact
  RLE/predefined sequence-payload scoring for lookahead, size-aware
  dictionary/native-match-vs-Huffman arbitration,
  smallest native match-plan arbitration across independent bootstrap emitters,
  RLE-literals sections for same-byte sequence literals,
  Huffman-compressed literals inside sequence blocks when the literal payload is compressible,
  raw-block-cost-aware compressed-block selection
  (falling back to raw/RLE blocks when compressed blocks would expand, for
  broad zstd CLI compatibility), plus deterministic smallest-mode
  native selection, configurable native block size, optional content
  checksum/content-size header fields, skippable frame append/encode-into writer,
  decoded-size preflight, bounded allocation, explicit Dictionary_ID/preset
  history decode APIs, direct-output incremental decode for raw/RLE/compressed
  native frames (including dictionary, dictionary-set, no-content-size,
  bounded-history multi-block paths, per-block compressed-input retention when
  a frame exceeds the configured buffer limit, and resumable zero-scratch
  output for raw/RLE/Huffman literals and sequence execution across arbitrary
  caller output boundaries (including complete frames prevalidated by the direct
  path), plus header-only incremental discard/capture of arbitrarily large
  skippable-frame payloads), zero-allocation native stream/block iterators, and
  dependency-free standard full-dictionary generation from caller-selected
  history content using portable baseline entropy tables, plus first-stage
  corpus training of a complete literal Huffman alphabet and OF/ML/LL sequence
  FSE tables, plus measured first-sequence repcode selection that retains the
  baseline `1/4/8` values unless a retrained candidate strictly reduces the
  corpus's encoded bytes by at least 1%, with strict parsing and
  bidirectional libzstd interoperability validation,
  standardized seekable-stream encoding with output-bound, caller-owned-buffer, reusable encoder, and deterministic caller-selected parallel frame APIs, plus zero-allocation terminal seek-table parsing/iteration and bounded range decode (including preset-dictionary encoding, dictionary-set frame selection, optional per-frame checksum verification, decompressed-offset lookup, and a reusable caller-owned cumulative index with O(1) entry access and O(log n) offset lookup),
  caller-owned encode/decode-into/append, incremental raw/RLE frame encode with optional pledged content size and Dictionary_ID metadata, reusable native scratch encoder/decoder APIs, plus a reusable level-aware frame encoder that preserves adaptive selection policy while retaining primary scratch,
  used by downstream
  projects such as `../mcap` so compression algorithms stay centralized in
  Vort;
- raw deflate stored/fixed/dynamic/best encode and stored/fixed/dynamic decode, with zlib/gzip wrappers plus preset-dictionary-aware raw/zlib encode/decode;
- dependency-free ZIP32/ZIP64 archive reading and deterministic writing with
  EOCD/ZIP64-locator/central-directory iteration, exact entry lookup, stored,
  raw-deflate, and Bzip2-method-12 multi-entry encoding/extraction,
  transactional prefix append, 32-/64-bit data descriptors, archive/entry
  comments, CRC-32/size validation, UTF-8 flags, and explicit
  encrypted/multi-disk/unknown-method errors;
- dependency-free Bzip2 `BZh1`...`BZh9` encoding and decoding with canonical Huffman,
  selector/inverse move-to-front, RUNA/RUNB, inverse BWT, first-stage RLE,
  multi-block and explicit concatenated-stream support, caller-owned/bounded
  allocation APIs, decoded-size preflight, and block/combined CRC validation;
- dependency-free XZ decoding for single-filter LZMA2 streams with strict
  stream/block/index/footer validation, none/CRC-32/CRC-64/SHA-256 checks,
  multi-block and concatenated-stream handling, bounded APIs and metadata
  inspection, plus deterministic XZ writing with uncompressed LZMA2 chunks;
- dependency-free LZMA-Alone decoding with known/unknown-size headers,
  caller-selected output/dictionary limits, caller-owned output, and ZIP
  method-14 extraction through the same LZMA core;
- dependency-free Brotli `br` stored/uncompressed and planner-backed fast encode/decode surfaces, including explicit 10..16-bit one-shot planned windows at every level and the complete 10..24 range at ratio level with distance-bounded matching, exact-wire-selected two-type literal/command/distance entropy splitting for heterogeneous ratio inputs, one-shot planned metadata at every level, opt-in bounded static-dictionary probing for 257-byte through 4 KiB ratio inputs, arbitrarily large ratio inputs encoded as one bounded-memory multi-meta-block stream, a caller-to-caller incremental planned encoder with flush/metadata, compressed-or-stored arbitration, and bounded cross-block LZ77 history, chunked encoding with bounded parser scratch into one mixed compressed/stored multi-meta-block stream plus 10..24-bit window and metadata options, strict-by-default RFC 7932 window bits 10..24 plus explicit opt-in decoding of the Large Window Brotli 10..30-bit extension across one-shot, chunked, summary, buffered-incremental, and byte-progressive copy APIs, metadata meta-block skipping, caller-history stream summaries for large-window preflight without hidden allocation, a bounded split-input general facade that validates on explicit finish, byte-progressive stored-subset encode/decode, and bounded-header byte-progressive decoders for insert-only Huffman literals, single-command RLE, and copy streams with literal/distance context maps, entropy block switching across the complete 256-entry literal/command/distance block-type count range and literal/distance context-tree ranges, caller-owned compressed-header scratch beyond the default 16 KiB bound, dynamic direct/regular/recent distances, transformed static-dictionary references, non-final compressed blocks followed by metadata/stored blocks and a final-empty terminator, plus libbrotli streaming-operation differentials covering PROCESS accumulation, empty/repeated FLUSH, METADATA transitions, and FINISH with pending input; compressed output honors caller backpressure and copy history is caller-owned;
- dependency-free Snappy raw block full decode plus greedy match raw/framed encode with reusable encoder state, encoded-bound helpers, raw-block and framed-stream summaries, split-input and exact-size decode helpers, decoded-size preflight, bounded allocation, masked CRC-32C validation, skippable framed chunks, and caller-owned incremental framed encode/decode with 64 KiB input chunking, optional pledged input/output sizes, split headers/payloads, bounded input/output memory, tiny-output draining, exact-output continuation through following skippable chunks, reset/next-stream reuse with cumulative and per-stream counters, snapshots, and diagnostics;
- a native `VORT` store frame with skippable frames, concatenated streams, checksum-validated in-memory/serialized frame indexes, frame-index CRC composition, range CRC summaries, caller-owned and batch range decode APIs, and bounded streaming APIs;
- LZ77 greedy/lazy/optimal parser prototypes, dictionary metadata/training, match-coverage, patch-codec, native dictionary-patch frame, self-contained dictionary streams, native LDM reference frame, and dictionary-/LDM-aware native best-frame prototypes, long-distance match scanner, LDM-aware block planner, CLI smoke surfaces, fuzz corpus harnesses, and benchmark/report entrypoints.

Hosted CI runs on `main` pushes and pull requests through
`.github/workflows/ci.yml`, which installs Zig 0.16, checks formatting, runs
`ci-smoke`, and repeats the focused fuzz smoke entrypoints. The `ci-smoke`
target now includes `run-native-codec-probes-dashboard`, so the library-level
LZ4/Zstd frame and dictionary probes run together in CI and retain JSON/Markdown
artifacts rather than only existing as manual commands.
The standalone `check-wasm` gate compiles the complete library and its
out-of-line Brotli/Zstd optimized objects for baseline `wasm32-wasi`. Native
wide-Huffman decoding retains its 64-byte function alignment; WebAssembly uses
the same inlined decode body through a target-safe unaligned wrapper.

## Commands

```sh
zig build test
zig build check
zig build check-wasm
zig build -Doptimize=ReleaseFast ci-smoke
zig build run -- --help
zig build -Doptimize=ReleaseFast run-zstd-dictionary-trainer-compare -j1
zig build -Doptimize=ReleaseFast run-dictionary-train-bench-gate -j1
zig build -Doptimize=ReleaseFast run-zstd-native-encode-stage-bench-gate
zig build run -- checksum "hello vort"
zig build run -- store-roundtrip "hello vort"
zig build run -- vort-deflate-roundtrip "hello vort"
zig build run -- vort-blocked-range-demo
zig build run -- vort-blocked-best-range-demo
zig build run -- vort-sidecar-blocked-best-range-demo
zig build run -- vort-dict-blocked-range-demo
zig build run -- vort-self-dict-range-demo
zig build run -- vort-trained-dict-range-demo
zig build run -- vort-seekable-native-range-demo
zig build run -- vort-ldm-summary-demo
zig build run -- vort-ldm-blocked-range-demo
zig build run -- vort-sidecar-ldm-range-demo
zig build run -- vort-ldm-indexed-range-demo
zig build run -- store-range-demo
zig build run -- store-sidecar-range-demo
zig build run -- store-sidecar-dict-range-demo
zig build run -- encode-vort-sidecar-best-file README.md /tmp/readme.vort /tmp/readme.vidx 4096
zig build run -- encode-vort-embedded-best-file README.md /tmp/readme-embedded.vort 4096
zig build run -- encode-vort-embedded-dict-file README.md /tmp/readme-embedded-dict.vort 4096
zig build run -- verify-vort-sidecar-index-file /tmp/readme.vort /tmp/readme.vidx
zig build run -- verify-vort-sidecar-index-file /tmp/readme.vort /tmp/readme.vidx metadata
zig build run -- verify-vort-sidecar-index-file /tmp/readme.vort /tmp/readme.vidx full json
zig build run -- verify-vort-embedded-index-file /tmp/readme-embedded.vort
zig build run -- verify-vort-embedded-index-file /tmp/readme-embedded.vort metadata
zig build run -- verify-vort-embedded-index-file /tmp/readme-embedded.vort full json
zig build run-sidecar-verify-report -- /tmp/readme.vort /tmp/readme.vidx
zig build run-sidecar-verify-report -- --mode metadata /tmp/readme.vort /tmp/readme.vidx
zig build run-sidecar-corrupt-smoke
zig build run-sidecar-verify-report -- --self-test-corrupt --markdown /tmp/sidecar-corrupt.md --json /tmp/sidecar-corrupt.json
zig build run-sidecar-corrupt-dashboard
zig build run-validation-json-smoke
zig build run-validation-json-dashboard
zig build run-validation-json-docs-check
zig build run-dashboard-index  # writes zig-out/vort-dashboard-index.md/.json and enforces producer/smoke-gate mappings
zig build run-sidecar-verify-report -- --dir /tmp --limit 8 --keep-going
zig build run-sidecar-verify-report -- --markdown /tmp/sidecar-report.md --json /tmp/sidecar-report.json --dir /tmp
zig build run -- decode-vort-sidecar-range-file /tmp/readme.vort /tmp/readme.vidx /tmp/readme.range 32 64
zig build run -- decode-vort-embedded-range-file /tmp/readme-embedded.vort /tmp/readme-embedded.range 32 64
zig build run -- decode-vort-embedded-auto-range-file /tmp/readme-embedded-dict.vort /tmp/readme-embedded-dict.range 32 64
zig build run -- encode-vort-sidecar-dict-file README.md /tmp/readme-dict.vort /tmp/readme-dict.vidx 4096
zig build run -- decode-vort-sidecar-auto-range-file /tmp/readme-dict.vort /tmp/readme-dict.vidx /tmp/readme-dict.range 32 64
zig build run -- encode-vort-sidecar-ldm-file README.md /tmp/readme-ldm.vort /tmp/readme-ldm.vidx 4096
zig build run -- decode-vort-sidecar-range-file /tmp/readme-ldm.vort /tmp/readme-ldm.vidx /tmp/readme-ldm.range 32 64
zig build run -- zlib-store-roundtrip "hello vort"
zig build run -- gzip-store-roundtrip "hello vort"
zig build run -- list-zip-file /tmp/archive.zip
zig build run -- extract-zip-file /tmp/archive.zip path/in/archive.txt /tmp/archive.out 1048576
zig build run-zip-diff
zig build run -- encode-bzip2-file README.md /tmp/readme.bz2 9
zig build run -- decode-bzip2-file /tmp/archive.bz2 /tmp/archive.out 67108864
zig build run -- decode-bzip2-concat-file /tmp/members.bz2 /tmp/members.out 67108864
zig build run -- size-bzip2-file /tmp/archive.bz2 67108864
zig build run-bzip2-diff
zig build run -- encode-xz-stored-file README.md /tmp/readme.xz crc64 1048576
zig build run -- decode-xz-file /tmp/readme.xz /tmp/readme.out 67108864
zig build run -- inspect-xz-file /tmp/readme.xz
zig build run-xz-diff
zig build run -- decode-lzma-file /tmp/archive.lzma /tmp/archive.out 67108864 67108864
zig build run -- size-lzma-file /tmp/archive.lzma 67108864
zig build run-lzma-diff
zig build run -- encode-br-stored-hex "hello vort" 16 metadata
zig build run -- decode-br-hex 40001068656c6c6f03 5
zig build run-br-stored-corpus
zig build run-br-literal-cli-diff
zig build run-br-planned-node-diff
zig build -Doptimize=ReleaseFast run-br-planned-encode-bench-gate
zig build -Doptimize=ReleaseFast run-br-ratio-stage-profile-gate
zig build -Doptimize=ReleaseFast run-br-planned-chunks-bench-gate
zig build -Doptimize=ReleaseFast run-br-upstream-multiblock-diff
zig build -Doptimize=ReleaseFast run-br-real-corpus-diff
# Optional real-corpus prefixes from neighboring checkouts:
zig build -Doptimize=ReleaseFast run-br-real-corpus-diff -- \
  --extra-file ~/Work/godot/thirdparty/ufbx/ufbx.c \
  --extra-file ~/Work/opencv/data/haarcascades/haarcascade_frontalface_default.xml
zig build -Doptimize=ReleaseFast run-br-progressive-copy-bench-gate
zig build -Doptimize=ReleaseFast run-br-progressive-huffman-bench-gate
zig build -Doptimize=ReleaseFast run-br-incremental-planned-bench-gate
zig build run -- zlib-fixed-roundtrip "hello vort"
zig build run -- gzip-fixed-roundtrip "hello vort"
zig build run -- decode-raw-hex cb48cdc9c90700
zig build run -- decode-raw-hex cb48cdc9c90700 5
zig build run -- inspect-raw-header-hex cb48cdc9c90700
zig build run -- inspect-raw-header-hex cb48cdc9c90700 json
zig build run -- decode-raw-dict-hex cb402701 "hello "
python3 - <<'PY'
import zlib
co = zlib.compressobj(level=6, wbits=-15)
open("/tmp/vort.raw", "wb").write(co.compress(b"hello") + co.flush())
PY
zig build run -- decode-raw-file /tmp/vort.raw /tmp/vort-raw.out 5
printf "hello " > /tmp/vort.dict
printf "cb402701" | xxd -r -p > /tmp/vort-dict.raw
zig build run -- decode-raw-dict-file /tmp/vort-dict.raw /tmp/vort-raw-dict.out /tmp/vort.dict 17
zig build run -- decode-zlib-hex 7801cb48cdc9c90700062c0215
zig build run -- decode-zlib-concat-hex 7801cb48cdc9c90700062c02157801cb48cdc9c90700062c0215
zig build run -- inspect-zlib-header-hex 7801cb48cdc9c90700062c0215
zig build run -- inspect-zlib-header-hex 7801cb48cdc9c90700062c0215 json
zig build run -- inspect-zlib-deflate-header-hex 7801cb48cdc9c90700062c0215 json
zig build run -- inspect-zlib-dict-deflate-header-hex 78f908610235cb4027013a2e067d "hello " json
zig build run -- decode-zlib-dict-hex 78f908610235cb4027013a2e067d "hello "
zig build run -- decode-zlib-dict-concat-hex 78f908610235cb4027013a2e067d78f908610235cb4027013a2e067d "hello "
python3 - <<'PY'
import zlib
open("/tmp/vort.zlib", "wb").write(zlib.compress(b"hello"))
PY
zig build run -- decode-zlib-file /tmp/vort.zlib /tmp/vort-zlib.out 5
cat /tmp/vort.zlib /tmp/vort.zlib > /tmp/vort-cat.zlib
zig build run -- decode-zlib-concat-file /tmp/vort-cat.zlib /tmp/vort-zlib-cat.out 10
zig build run -- inspect-zlib-header-file /tmp/vort.zlib
zig build run -- inspect-zlib-deflate-header-file /tmp/vort.zlib json
printf "hello " > /tmp/vort.dict && python3 - <<'PY'
import zlib
d = b"hello "
p = b"hello hello hello"
co = zlib.compressobj(level=9, wbits=zlib.MAX_WBITS, zdict=d)
open("/tmp/vort-dict.zlib", "wb").write(co.compress(p) + co.flush())
PY
zig build run -- inspect-zlib-dict-deflate-header-file /tmp/vort-dict.zlib /tmp/vort.dict json
zig build run -- decode-zlib-dict-file /tmp/vort-dict.zlib /tmp/vort-dict.out /tmp/vort.dict
zig build run -- decode-zlib-dict-file /tmp/vort-dict.zlib /tmp/vort-dict-limited.out /tmp/vort.dict 17
cat /tmp/vort-dict.zlib /tmp/vort-dict.zlib > /tmp/vort-dict-cat.zlib
zig build run -- decode-zlib-dict-concat-file /tmp/vort-dict-cat.zlib /tmp/vort-dict-cat.out /tmp/vort.dict
zig build run -- encode-raw-dict-best-file /tmp/vort-dict.out /tmp/vort-dict.raw /tmp/vort.dict default
zig build run -- encode-raw-dict-best-split-file /tmp/vort-dict.out /tmp/vort-dict-split.raw /tmp/vort.dict 7 default
zig build run -- encode-raw-dict-best-adaptive-file /tmp/vort-dict.out /tmp/vort-dict-adaptive.raw /tmp/vort.dict default
zig build run -- encode-zlib-dict-best-file /tmp/vort-dict.out /tmp/vort-dict-encoded.zlib /tmp/vort.dict default
zig build run -- encode-zlib-dict-best-split-file /tmp/vort-dict.out /tmp/vort-dict-split.zlib /tmp/vort.dict 7 default
zig build run -- encode-zlib-dict-best-adaptive-file /tmp/vort-dict.out /tmp/vort-dict-adaptive.zlib /tmp/vort.dict default
zig build run -- decode-gzip-hex 1f8b0800000000000403cb48cdc9c9070086a6103605000000
zig build run -- inspect-gzip-header-hex 1f8b0800000000000403cb48cdc9c9070086a6103605000000
zig build run -- inspect-gzip-header-hex 1f8b0800000000000403cb48cdc9c9070086a6103605000000 json
zig build run -- inspect-gzip-deflate-header-hex 1f8b0800000000000403cb48cdc9c9070086a6103605000000 json
python3 - <<'PY'
import gzip
open("/tmp/vort.gz", "wb").write(gzip.compress(b"hello", mtime=0))
open("/tmp/vort-cat.gz", "wb").write(gzip.compress(b"hello ", mtime=0) + gzip.compress(b"world", mtime=0))
PY
zig build run -- decode-gzip-file /tmp/vort.gz /tmp/vort-gzip.out 5
zig build run -- inspect-gzip-header-file /tmp/vort.gz
zig build run -- inspect-gzip-deflate-header-file /tmp/vort.gz json
zig build run -- inspect-gzip-deflate-header-file /tmp/vort-cat.gz json  # first member
zig build run -- inspect-gzip-deflate-header-file /tmp/vort-cat.gz json 1
zig build run -- decode-gzip-file /tmp/vort-cat.gz /tmp/vort-gzip-cat.out 11
zig build run -- encode-raw-best-file-hex README.md default
zig build run -- encode-zlib-best-file-hex README.md default
zig build run -- encode-gzip-best-file-hex README.md default
zig build run -- encode-raw-best-split-hex "abcdefghijklmnopqrstuvwxyz" 7 fast
zig build run -- encode-raw-dict-best-hex "hello hello hello" "hello " default
zig build run -- encode-zlib-dict-best-hex "hello hello hello" "hello " default
zig build run -- encode-zlib-best-adaptive-hex "abcdefghijklmnopqrstuvwxyz" default
zig build run -- encode-zlib-best-split-hex "abcdefghijklmnopqrstuvwxyz" 7 default
zig build run -- encode-gzip-best-split-hex "abcdefghijklmnopqrstuvwxyz" 7 default
zig build run-fuzz-smoke
zig build run-fuzz-corpus
zig build run-fuzz-corpus -- --deflate 4b0400 4a0400
zig build run-fuzz-corpus -- --deflate --expect=reject 4a0400
zig build run-fuzz-corpus -- --deflate --expect-error=TrailingData 4b040058
zig build run-fuzz-corpus -- --zlib 7801cb48cdc9c90700062c0215 0000 --gzip 1f8b0800000000000403cb48cdc9c9070086a6103605000000 0000
zig build run-fuzz-corpus -- --file corpus/deflate-wrapper-smoke.hex
zig build run-deflate-wrapper-fuzz-corpus
zig build run-deflate-wrapper-fuzz-corpus-dashboard
zig build run-fuzz-corpus-coverage-smoke
zig build run-fuzz-target
zig build run-libfuzzer-smoke
zig build run-afl-smoke
zig build run-checksum-diff
zig build run-checksum-zlib-diff
zig build -Doptimize=ReleaseFast run-checksum-bench-gate
zig build -Doptimize=ReleaseFast run-huffman-length-bench-gate
zig build -Doptimize=ReleaseFast run-deflate-code-length-rle-bench-gate
zig build run-zlib-diff
zig build run-gzip-diff
zig build run-python-zlib-diff
zig build run-python-zlib-diff-dashboard
zig build run-gzip-cli-diff
# gzip concatenated decode has explicit aliases as well:
# decode-gzip-concat-hex / decode-gzip-concat-file
zig build run-native-codec-probes
zig build run-native-codec-probes-dashboard
zig build run-lz4-native-probe
zig build run-lz4-native-dictionary-probe
zig build run-lz4-native-summary-cli-probe
zig build run-lz4-native-summary-dashboard
zig build run-native-summary-error-dashboard
zig build run-native-summary-error-negative-smoke
zig build run-lz4-native-probe -- --path README.md --limit 4096
zig build run-lz4-native-probe -- --dir docs --max-files 2 --limit 2048
zig build run -- encode-lz4-native-file README.md /tmp/vort-readme.lz4
zig build run -- summary-lz4-native-file /tmp/vort-readme.lz4
zig build run -- decode-lz4-native-file-to /tmp/vort-readme.lz4 /tmp/vort-readme-lz4.out 1048576
zig build run -- encode-lz4-block-hex 61626361626361626361
zig build run -- summary-lz4-block-hex 336162630300
zig build run -- decode-lz4-block-hex 336162630300 10
zig build run -- encode-lz4-block-prefix-hex 6d6e6f706d6e6f70 6162636465666768696a6b6c6d6e6f70
zig build run -- summary-lz4-block-prefix-hex 040400 6162636465666768696a6b6c6d6e6f70
zig build run -- decode-lz4-block-prefix-hex 040400 6162636465666768696a6b6c6d6e6f70 8
zig build run -- encode-snappy-block-hex 68656c6c6f
zig build run -- decode-snappy-block-hex 051068656c6c6f 5
zig build run -- summary-snappy-block-hex 051068656c6c6f
zig build run -- encode-snappy-block-file README.md /tmp/vort-readme.snappy-block
zig build run -- summary-snappy-block-file /tmp/vort-readme.snappy-block
zig build run -- decode-snappy-block-file-to /tmp/vort-readme.snappy-block /tmp/vort-readme-snappy.out 1048576
zig build run -- encode-snappy-frame-hex 68656c6c6f
zig build run -- decode-snappy-frame-hex ff060000734e6150705901090000bb1f1c1968656c6c6f 5
zig build run -- summary-snappy-frame-hex ff060000734e6150705901090000bb1f1c1968656c6c6f
zig build run -- encode-snappy-frame-file README.md /tmp/vort-readme.sz
zig build run -- summary-snappy-frame-file /tmp/vort-readme.sz
zig build run -- decode-snappy-frame-file-to /tmp/vort-readme.sz /tmp/vort-readme-snappy-frame.out 1048576
zig build run-snappy-block-cli-probe
zig build run-snappy-interop-probe
zig build run-snappy-report-gate
# Snappy encoded-bound, summary, split-input, and exact-size helpers are available from the library APIs:
# snappyEncodedBlockBound / snappySummarizeBlock / snappyDecodedBlockChunksSize / snappyDecodeBlockChunksIntoExactSize and
# snappyEncodedFrameBound / snappySummarizeFrame / snappyDecodedFrameChunksSize / snappyDecodeFrameChunksIntoExactSize.
zig build run -- encode-zstd-native-bytes-hex 68656c6c6f auto true true
zig build run -- encode-zstd-native-file-hex README.md literal_only true true
zig build run -- encode-zstd-native-file README.md /tmp/vort-readme.zst literal_only true true
zig build run -- decode-zstd-native-file-to /tmp/vort-readme.zst /tmp/vort-readme.out 1048576
zig build run -- summary-zstd-native-file /tmp/vort-readme.zst json
zig build run -- size-zstd-native-hex 28b52ffd240529000068656c6c6fa36d9f88 5
zig build run-zstd-native-cli-diff
zig build run-zstd-native-summary-cli-probe
zig build run-zstd-native-probe
zig build run-zstd-native-frame-probe
zig build run-zstd-native-dictionary-probe
zig build run-zstd-native-probe -- --path README.md --limit 4096
zig build run-zstd-native-probe -- --dir docs --max-files 2 --limit 2048
zig build run-header-inspect-smoke
zig build run-header-inspect-dashboard
zig build run-dashboard-category-smoke
zig build run-zlib-family-diff
zig build run-rust-deflate-diff
zig build run-external-probe
zig build run-cpu-features
zig build run-zstd-compare-gate
zig build run-zstd-compare-standard-gate
zig build run-zstd-compare-standard-releasefast-gate
zig build -Doptimize=ReleaseFast run-compat-benchmark
zig build -Doptimize=ReleaseFast run-standard-corpus-report
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --suite
zig build -Doptimize=ReleaseFast run-standard-corpus-suite
zig build -Doptimize=ReleaseFast run-standard-corpus-dashboard
zig build -Doptimize=ReleaseFast run-standard-corpus-full-dashboard
zig build -Doptimize=ReleaseFast run-standard-corpus-full-dashboard -- --paths README.md --limit 1
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --paths ~/Work/zlib-rs/silesia-small.tar
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --full
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-suite
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-dashboard -- --limit 3
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-full-suite
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-full-dashboard
zig build run-compression-report
zig build run-level-report
zig build run-level-report-csv
zig build run-level-report-dashboard
zig build run-huffman-length-report-dashboard
zig build run-huffman-length-report-dashboard -- --iterations 1000
zig build run-level-report -- README.md docs/roadmap.md
zig build run-dictionary-report
zig build run-native-library-bench
zig build run-native-library-bench -- --iterations 50
zig build run-native-library-bench-csv
zig build run-native-library-bench-gate
zig build run-native-dictionary-report
zig build run-native-dictionary-report -- --path README.md --limit 4096 --dict-len 512
zig build run-native-dictionary-report -- --path README.md --limit 4096 --dict-len 512 --json zig-out/native-dict.json --markdown zig-out/native-dict.md
zig build run-dictionary-report -- README.md docs/roadmap.md
zig build run-dictionary-report -- --target 512 README.md docs/roadmap.md
zig build run-dictionary-deflate-report
zig build run-dictionary-deflate-report -- /tmp/vort.dict /tmp/vort-dict.out
zig build run-dictionary-deflate-report -- --dict /tmp/vort.dict README.md docs/roadmap.md
zig build run-dictionary-deflate-report -- --dict /tmp/vort.dict docs
zig build run-dictionary-deflate-report-csv
zig build run-dictionary-deflate-report-dashboard
zig build -Doptimize=ReleaseFast run-dictionary-corpus-report
zig build -Doptimize=ReleaseFast run-dictionary-corpus-report -- --per-file
zig build -Doptimize=ReleaseFast run-dictionary-corpus-dashboard
zig build -Doptimize=ReleaseFast run-dictionary-corpus-dashboard -- --targets 128,256,512
zig build run-level-report
zig build run-level-report-csv
zig build run-level-report-dashboard
zig build run-huffman-length-report-dashboard
zig build run-huffman-length-report-dashboard -- --iterations 1000
zig build run-dynamic-plan-report
zig build run-dynamic-plan-report-csv
zig build run-split-policy-report
zig build run-split-policy-report -- README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-split-policy-corpus-report
zig build run-native-range-report
zig build run-native-range-report -- README.md docs/roadmap.md
zig build run-native-range-report -- --offset 32 --length 64 README.md
zig build run-native-range-report -- --sweep README.md
zig build -Doptimize=ReleaseFast run-file-corpus-report -- README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-file-corpus-dashboard -- README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-file-corpus-dashboard -- docs
zig build -Doptimize=ReleaseFast run-file-corpus-dashboard -- ~/Work/zlib-rs/silesia-small.tar
zig build -Doptimize=ReleaseFast run-file-corpus-standard-dashboard -- --limit 3
zig build -Doptimize=ReleaseFast run-file-corpus-standard-full-dashboard -- --limit 3
zig build bench-checksum -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseFast run-checksum-bench-gate
zig build -Doptimize=ReleaseFast run-snappy-report-gate
zig build -Doptimize=ReleaseFast run-snappy-reference-bench-gate  # optional runtime libsnappy comparison
zig build -Doptimize=ReleaseFast run-lz4-reference-bench-gate  # optional runtime liblz4 comparison
zig build -Doptimize=ReleaseFast run-zstd-reference-bench-gate  # optional runtime libzstd comparison
zig build -Doptimize=ReleaseFast run-zstd-reference-bench -- --libzstd /path/to/libzstd  # explicit reference library
zig build -Doptimize=ReleaseFast run-zstd-reference-bench -- --input path/to/file --name corpus_case --level 1  # same-frame in-process file decode comparison
zig build -Doptimize=ReleaseFast run-zstd-decode-profile -- --libzstd /path/to/libzstd  # pure-Vort decode shapes from explicit libzstd
zig build -Doptimize=ReleaseFast run-zstd-decode-profile -- --input path/to/file --name corpus_case --level 1  # file-backed match/literal shape profile
zig build -Doptimize=ReleaseFast run-zstd-sequence-decode-stage-bench  # prepared sequence bit/FSE ns per sequence on real source files
zig build -Doptimize=ReleaseFast run-zstd-sequence-decode-stage-bench -- --input path/to/file --name corpus_case --level 1  # file-backed sequence-stage timing
zig build -Doptimize=ReleaseFast run-zstd-interleaved-block-bench -- --input path/to/file --name corpus_case --level 1  # medium-block Huffman/FSE/copy kernel timing
zig build -Doptimize=ReleaseFast run-zstd-encode-bench-gate  # libzstd encode comparison and level-policy gate
zig build -Doptimize=ReleaseFast run-zstd-encode-bench -- --libzstd /path/to/libzstd  # explicit encode reference library
zig build -Doptimize=ReleaseFast run-zstd-native-encode-stage-bench-gate  # match-family timings plus single-beam search histograms
zig build -Doptimize=ReleaseFast run-zstd-level-schedule-bench-gate  # parallel-vs-serial multi-block scheduling
zig build run-zstd-large-sequence-probe  # >512-sequence single/cross-block encode plus Vort/libzstd decode
zig build run-zstd-compat-probe  # optional system-libzstd decode matrix
# Build and select the current local upstream reference explicitly:
make -C ~/Work/zstd/lib -j4 libzstd-release
zig build -Doptimize=ReleaseFast run-zstd-compat-probe -- \
  --libzstd ~/Work/zstd/lib/libzstd.so
# Optional deep zstd upstream decodecorpus differential (paired z*.zst / z* files):
zig build -Doptimize=ReleaseFast run-zstd-compat-probe -- \
  --decodecorpus /tmp/zstd-frames /tmp/zstd-plain --decodecorpus-count 1000
# Add --decodecorpus-dictionary /tmp/zstd-frames/dictionary for dictionary corpora.
# Reproduce the complete nine-campaign/9,900-frame suite and clean each temporary corpus:
zig build -Doptimize=ReleaseFast run-zstd-decodecorpus-gate -j1
# The same corpus can use an explicitly selected upstream shared library:
zig build -Doptimize=ReleaseFast run-zstd-decodecorpus-gate -j1 -- \
  --libzstd ~/Work/zstd/lib/libzstd.so
# Override discovery with -- --decodecorpus /path/to/zstd/tests/decodecorpus.
zig build bench-deflate-decode -Doptimize=ReleaseFast
zig build bench-deflate-incremental-encode -Doptimize=ReleaseFast -- 8
zig build run-deflate-incremental-encode-gate
# Optional direct zlib-ng compat-library comparison:
zig build bench-deflate-incremental-encode -Doptimize=ReleaseFast \
  -Dzlib-ng-root=$HOME/Work/zlib-ng -- 8
zig build -Dzlib-ng-root=$HOME/Work/zlib-ng run-deflate-incremental-encode-gate
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report -- --iterations 1000
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report-csv
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report-dashboard  # writes CSV/Markdown/JSON decode-stage artifacts
zig build run-zlib-relaxed-report-gate
zig build bench-corpus-decode -Doptimize=ReleaseFast
zig build bench-deflate-encode -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseFast run-rust-deflate-bench
zig build -Doptimize=ReleaseFast run-rust-deflate-bench-csv
zig build -Doptimize=ReleaseFast run-rust-deflate-encode-bench
zig build -Doptimize=ReleaseFast run-rust-deflate-encode-bench-csv
zig build -Doptimize=ReleaseFast run-rust-deflate-benchmark-summary
zig build bench-native-parallel -Doptimize=ReleaseFast
zig build bench-native-parallel -Doptimize=ReleaseFast -- README.md 4096 2
zig build -Doptimize=ReleaseFast run-native-parallel-corpus-report
zig build -Doptimize=ReleaseFast run-native-parallel-dashboard
zig build -Doptimize=ReleaseFast run-native-parallel-dashboard -- --workers 2 --block-len 4096 --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-native-parallel-dashboard -- --worker-sweep 1,2,4 --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-native-parallel-full-dashboard
zig build -Doptimize=ReleaseFast run-native-parallel-full-dashboard -- --workers 2 --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-native-parallel-multi-corpus-dashboard -- --limit 3
zig build -Doptimize=ReleaseFast run-native-parallel-multi-corpus-full-dashboard
zig build -Doptimize=ReleaseFast run-native-thread-pool-full-dashboard
zig build -Doptimize=ReleaseFast run-native-parallel-multi-corpus-full-dashboard -- --workers 2 --paths README.md docs/roadmap.md
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

const raw = try vort.encodeRawFixedDeflateAlloc(allocator, "payload");
defer allocator.free(raw);
const raw_level_6 = try vort.encodeRawLevelAlloc(allocator, "payload", 6);
defer allocator.free(raw_level_6);
const raw_exact = try vort.decodeRawDeflateAllocExactSize(allocator, raw, "payload".len);
defer allocator.free(raw_exact);
const bounded = try vort.decodeRawDeflateAllocLimited(allocator, raw, 1024);
defer allocator.free(bounded);
const raw_chunks = [_][]const u8{ raw[0..1], raw[1..] };
var raw_join_scratch: [1024]u8 = undefined;
var raw_out: [1024]u8 = undefined;
const raw_chunk_header = try vort.parseRawDeflateHeaderInfoFromChunks(&raw_chunks, &raw_join_scratch);
_ = raw_chunk_header.block_type;
const raw_chunked = try vort.decodeRawDeflateChunks(&raw_chunks, &raw_join_scratch, &raw_out);
_ = raw_chunked;

// Native LZ4 APIs are available as alloc, append, caller-owned slice, and
// reusable scratch forms. Linked block mode can improve ratio when chunks share
// the previous 64 KiB of history.
const lz4_options: vort.Lz4NativeFrameOptions = .{ .block_mode = .linked };
var lz4_encoder = try vort.Lz4NativeFrameEncoder.init(allocator);
defer lz4_encoder.deinit();
const lz4_frame = try lz4_encoder.encodeScratch("payload payload", lz4_options);
const lz4_header = try vort.lz4InspectNativeFrameHeader(lz4_frame);
_ = lz4_header.block_independent;
const lz4_first_block = try vort.lz4InspectNativeFrameFirstBlock(lz4_frame);
_ = lz4_first_block;
_ = try vort.lz4InspectNativeFrameBlockAt(lz4_frame, lz4_first_block.?.header_offset);
const lz4_blocks = try vort.lz4SummarizeNativeFrameBlocks(lz4_frame);
_ = lz4_blocks.block_count;
const lz4_stream = try vort.lz4SummarizeNativeStream(lz4_frame);
_ = lz4_stream.frame_count;
const lz4_native_size = try vort.lz4DecodedNativeFrameSize(lz4_frame);
_ = try vort.lz4DecodedNativeFrameSizeLimited(lz4_frame, lz4_native_size);
const lz4_frame_chunks = [_][]const u8{ lz4_frame[0..4], lz4_frame[4..] };
var lz4_join_scratch: [1024]u8 = undefined;
_ = try vort.lz4DecodedNativeFrameChunksSize(&lz4_frame_chunks, &lz4_join_scratch);
var lz4_chunk_appended: std.ArrayList(u8) = .empty;
defer lz4_chunk_appended.deinit(allocator);
try lz4_chunk_appended.appendSlice(allocator, "prefix:");
_ = try vort.lz4DecodeNativeFrameChunksAppend(
    allocator,
    &lz4_chunk_appended,
    &lz4_frame_chunks,
    &lz4_join_scratch,
);
_ = try vort.lz4DecodeNativeFrameChunksAppendExactSize(
    allocator,
    &lz4_chunk_appended,
    &lz4_frame_chunks,
    &lz4_join_scratch,
    lz4_native_size,
);
var lz4_block_iter = try vort.lz4IterateNativeFrameBlocks(lz4_frame);
while (try lz4_block_iter.next()) |block| {
    _ = block.payload_len;
}
const lz4_skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 0, "metadata");
defer allocator.free(lz4_skip);
_ = try vort.lz4InspectNativeSkippableFrame(lz4_skip);
var lz4_stream_iter = vort.lz4IterateNativeStream(lz4_skip);
while (try lz4_stream_iter.next()) |element| switch (element) {
    .frame => |frame| _ = frame.header.block_size_max,
    .skippable => |skippable| _ = skippable.payload,
};
var lz4_decoder = vort.Lz4NativeFrameDecoder.init(allocator);
defer lz4_decoder.deinit();
const lz4_plain = try lz4_decoder.decodeScratch(lz4_frame);
_ = lz4_plain;
_ = try lz4_decoder.decodedChunksSize(&lz4_frame_chunks, &lz4_join_scratch);
const lz4_chunk_plain = try lz4_decoder.decodeChunksScratch(&lz4_frame_chunks, &lz4_join_scratch);
_ = lz4_chunk_plain;
var lz4_reusable_chunk_appended: std.ArrayList(u8) = .empty;
defer lz4_reusable_chunk_appended.deinit(allocator);
try lz4_reusable_chunk_appended.appendSlice(allocator, "prefix:");
_ = try lz4_decoder.decodeChunksAppendExactSize(
    &lz4_reusable_chunk_appended,
    &lz4_frame_chunks,
    &lz4_join_scratch,
    lz4_native_size,
);
var lz4_incremental = vort.Lz4NativeIncrementalFrameDecoder.init(allocator);
defer lz4_incremental.deinit();
var lz4_incremental_out: ["payload payload".len]u8 = undefined;
_ = try lz4_incremental.step(lz4_frame[0..4], lz4_incremental_out[0..0]);
_ = try lz4_incremental.step(lz4_frame[4..], &lz4_incremental_out);
// The same incremental decoder can continue through concatenated native
// streams and LZ4 skippable metadata frames; feed more bytes after `.done` to
// decode the next stream member without resetting cumulative diagnostics.
var lz4_bounded_incremental = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
    .max_compressed_buffer_len = 1 << 20,
    .max_decoded_buffer_len = 1 << 20,
    .expected_output_len = "payload payload".len,
});
defer lz4_bounded_incremental.deinit();
// Skippable frames retain only their 8-byte header; their metadata payload can
// exceed max_compressed_buffer_len and is discarded or copied into caller-owned
// skippable_output incrementally. Oversized data frames switch to block-bounded
// input. Compressed LZ4 blocks without block checksums can stream under a
// header-sized cap; checksummed blocks require the cap to hold one encoded
// block so checksum failure is reported before caller output is exposed.
// After feeding/draining the final frame, call finish() to validate exact-size EOF.
const lz4_dict = vort.Lz4NativeDictionary.init(0x1234, "previous lz4 history");
const lz4_dict_options: vort.Lz4NativeFrameOptions = .{ .content_checksum = false };
const lz4_dict_bound = try vort.lz4EncodedNativeFrameBoundWithDictionary(
    "previous lz4 history payload".len,
    lz4_dict_options,
    lz4_dict,
);
_ = lz4_dict_bound;
const lz4_dict_frame = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(
    allocator,
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict,
);
defer allocator.free(lz4_dict_frame);
const lz4_dict_plain = try vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, lz4_dict_frame, lz4_dict);
defer allocator.free(lz4_dict_plain);
const lz4_dicts = [_]vort.Lz4NativeDictionary{lz4_dict};
const lz4_dict_set = vort.Lz4NativeDictionarySet.init(&lz4_dicts);
const lz4_dict_set_bound = try vort.lz4EncodedNativeFrameBoundWithDictionarySet(
    "previous lz4 history payload".len,
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
);
_ = lz4_dict_set_bound;
const lz4_dict_set_frame = try vort.lz4EncodeNativeFrameWithDictionarySetAlloc(
    allocator,
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
);
defer allocator.free(lz4_dict_set_frame);
var lz4_dict_set_append: std.ArrayList(u8) = .empty;
defer lz4_dict_set_append.deinit(allocator);
try vort.lz4EncodeNativeFrameAppendWithDictionarySet(
    allocator,
    &lz4_dict_set_append,
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
);
const lz4_dict_set_into = try allocator.alloc(u8, lz4_dict_set_bound);
defer allocator.free(lz4_dict_set_into);
_ = try vort.lz4EncodeNativeFrameIntoSliceWithDictionarySet(
    allocator,
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
    lz4_dict_set_into,
);
const lz4_reusable_dict_set_frame = try lz4_encoder.encodeScratchWithDictionarySet(
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
);
_ = lz4_reusable_dict_set_frame;
const lz4_reusable_dict_set_owned = try lz4_encoder.encodeWithDictionarySetAlloc(
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
);
defer allocator.free(lz4_reusable_dict_set_owned);
_ = try lz4_encoder.encodeIntoSliceWithDictionarySet(
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
    lz4_dict_set_into,
);
const lz4_stream_plain = try vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(
    allocator,
    lz4_dict_frame,
    lz4_dict_set,
);
defer allocator.free(lz4_stream_plain);
const lz4_stream_exact = try vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(
    allocator,
    lz4_dict_frame,
    lz4_dict_set,
    lz4_stream_plain.len,
);
defer allocator.free(lz4_stream_exact);
const lz4_chunks = [_][]const u8{ lz4_dict_frame[0..8], lz4_dict_frame[8..] };
const lz4_join = try allocator.alloc(u8, lz4_dict_frame.len);
defer allocator.free(lz4_join);
var lz4_chunk_out: ["previous lz4 history payload".len]u8 = undefined;
_ = try vort.lz4DecodeNativeFrameChunksIntoWithDictionarySet(
    &lz4_chunks,
    lz4_join,
    &lz4_chunk_out,
    lz4_dict_set,
);

var lz4_block_encoder = try vort.Lz4BlockEncoder.init(allocator);
defer lz4_block_encoder.deinit();
_ = vort.lz4NativeMaxChainDepth; // public upper bound for NativeFrameOptions.chain_depth.
const lz4_block_once = try vort.lz4EncodeBlockWithChainDepthAlloc(allocator, "payload", lz4_dict_options.chain_depth);
defer allocator.free(lz4_block_once);
const lz4_block = try lz4_block_encoder.encodeWithPrefixScratch("payload", "previous payload history");
_ = try lz4_block_encoder.encodeWithPrefixScratchAndChainDepth("payload", "previous payload history", lz4_dict_options.chain_depth);
var lz4_block_decoder = vort.Lz4BlockDecoder.init(allocator);
defer lz4_block_decoder.deinit();
const lz4_block_plain = try lz4_block_decoder.decodeWithPrefixScratch(lz4_block, "payload".len, "previous payload history");
_ = lz4_block_plain;

// Native-subset Zstd APIs expose the same alloc/append/into/scratch style plus
// mode reporting. The block size and match-search budget options let callers
// trade ratio, encode latency, and seekability without going through the CLI.
const zstd_options: vort.ZstdNativeFrameOptions = .{
    .selection = .auto,
    .block_size_max = 32 * 1024,
    // 0 disables mixed dictionary/duplicate/repeated lookahead; values up to
    // the default keep more ratio-seeking branches at higher planning cost.
    // Dictionary-only matches remain available even when the budget is 0.
    .match_search_budget = vort.zstdNativeMaxMatchSearchBudget,
};
var zstd_encoder = vort.ZstdNativeFrameEncoder.init(allocator);
defer zstd_encoder.deinit();
const zstd_result = try zstd_encoder.encodeScratch("payload payload", zstd_options);
_ = zstd_result.mode;
const zstd_header = try vort.zstdInspectNativeFrameHeader(zstd_result.frame);
_ = zstd_header.content_size;
const zstd_first_block = try vort.zstdInspectNativeFrameFirstBlock(zstd_result.frame);
_ = zstd_first_block.block_type;
_ = try vort.zstdInspectNativeFrameBlockAt(zstd_result.frame, zstd_first_block.header_offset);
if (zstd_first_block.block_type == .compressed) {
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(zstd_result.frame, zstd_first_block);
    _ = modes.literal_length_mode;
}
const zstd_blocks = try vort.zstdSummarizeNativeFrameBlocks(zstd_result.frame);
_ = zstd_blocks.block_count;
const zstd_stream = try vort.zstdSummarizeNativeStream(zstd_result.frame);
_ = zstd_stream.frame_count;
var zstd_block_iter = try vort.zstdIterateNativeFrameBlocks(zstd_result.frame);
while (try zstd_block_iter.next()) |block| {
    _ = block.block_type;
}
const zstd_skip = try vort.zstdEncodeSkippableFrameAlloc(allocator, 0, "metadata");
defer allocator.free(zstd_skip);
_ = try vort.zstdInspectNativeSkippableFrame(zstd_skip);
var zstd_stream_iter = vort.zstdIterateNativeStream(zstd_result.frame);
while (try zstd_stream_iter.next()) |element| switch (element) {
    .frame => |frame| _ = frame.header.block_size_max,
    .skippable => |skippable| _ = skippable.payload,
};
var zstd_decoder = vort.ZstdNativeFrameDecoder.init(allocator);
defer zstd_decoder.deinit();
const zstd_plain = try zstd_decoder.decodeScratch(zstd_result.frame);
_ = zstd_plain;
var zstd_incremental = vort.ZstdNativeIncrementalFrameDecoder.init(allocator);
defer zstd_incremental.deinit();
var zstd_incremental_out: ["payload payload".len]u8 = undefined;
_ = try zstd_incremental.step(zstd_result.frame[0..4], zstd_incremental_out[0..0]);
_ = try zstd_incremental.step(zstd_result.frame[4..], &zstd_incremental_out);
// Zstd native incremental decode likewise walks concatenated frames and
// skippable metadata frames through the same caller-owned StepResult API.
var zstd_bounded_incremental = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
    .max_compressed_buffer_len = 1 << 20,
    .max_decoded_buffer_len = 1 << 20,
    .expected_output_len = "payload payload".len,
});
defer zstd_bounded_incremental.deinit();
// If a data frame exceeds max_compressed_buffer_len, Vort releases input one
// block at a time. isBlockStreaming() exposes that path and
// compressedBufferedBytes()/compressedBufferCapacity() report logical and
// allocated encoded-input storage; both stay within a finite configured cap.
// Sequence-bearing blocks retain their FSE/Huffman cursors and pending
// literal/match progress across calls without allocating decoded-block scratch,
// including when a prevalidated direct frame meets a tiny output slice;
// streamedSequenceBlockCount() reports path coverage.
// Skippable frames retain only their 8-byte header; metadata payloads are
// discarded or copied into caller-owned skippable_output storage incrementally.
// After feeding/draining the final frame, call finish() to validate exact-size EOF.
// Brotli's general incremental decoder can instead pledge expected_compressed_len
// (or use initExactCompressedSize) to auto-validate/decode stored or compressed
// meta-block streams at a transport-provided boundary, then drain tiny output.
// BrotliIncrementalCopyStreamDecoder uses an embedded 16 KiB compressed-header
// buffer. For valid streams with unusually large entropy headers, pass a larger
// caller-owned slice as Options.compressed_header_scratch; it must remain alive
// and must not alias input, output, or history while the decoder is in use.
// Non-RFC Large Window streams remain rejected by default. Opt in explicitly
// on one-shot/chunked APIs with BrotliDecodeOptions, or on either general
// incremental decoder through Options.decode.
const br_large_window = vort.BrotliDecodeOptions{ .allow_large_window = true };
_ = try vort.brDecodeStreamIntoWithOptions(encoded_large_window, output, br_large_window);
const zstd_dict = vort.ZstdNativeDictionary.init(0x1234, "previous zstd history shared phrase");
var zstd_incremental_encoder = try vort.ZstdNativeIncrementalFrameEncoder.initWithPresetDictionary(allocator, .{
    .include_content_size = false,
    .selection = .literal_only,
    .dictionary_id = zstd_dict.id,
}, zstd_dict);
defer zstd_incremental_encoder.deinit();
// Feed split input with step(), call finish(), then drain until StepResult.done.
// The dictionary bytes are borrowed and may be referenced by emitted sequences;
// completed blocks also seed a bounded indexed rolling window for multiple later
// block matches without retaining the complete input stream.
// Call flush(), then step with empty input until need_input, to publish a
// non-final block before continuing the same frame. Repeated empty flushes are
// idempotent.
// LZ4 and framed Snappy incremental encoders expose the same resumable flush
// acknowledgement contract, as does the Brotli stored-stream encoder.
// RawDeflateIncrementalStoredEncoder provides the same split-input/tiny-output
// contract for RFC 1951 stored blocks, including pledged input size and flush.
// RawDeflateIncrementalFixedEncoder adds fixed-Huffman compression, a rolling
// 32 KiB history, and zlib-compatible empty stored sync-flush boundaries.
// ZlibIncrementalFixedEncoder adds CMF/FLG, optional preset DICTID, streaming
// Adler-32 and the footer while preserving the raw core's flush semantics.
// GzipIncrementalFixedEncoder adds optional RFC 1952 metadata/FHCRC plus
// streaming CRC-32 and ISIZE with the same split-input and sync-flush contract.
// RawDeflateIncrementalBestEncoder evaluates stored, fixed, and dynamic Huffman
// representations per block while retaining the same rolling history core.
// Hash and lazy-parser levels additionally retain a bounded 32 KiB predecessor
// ring and epoch-tagged hash heads across blocks; reset reuses them in O(1).
// ZlibIncrementalBestEncoder and GzipIncrementalBestEncoder expose that selector
// through wrapper checksums/metadata; *OptionsForLevel maps zlib levels 0...9.
// Set adaptive_blocks on a best encoder to use CompressionOptions.split_options
// for costed, bounded block-boundary selection instead of one fixed block size.
// Set lookahead_len to retain a bounded suffix and move normal block cuts to a
// complete LZ77 token boundary discovered with next-call prefix bytes.
// Set low_entropy_block_len to a larger bounded cap to amortize dynamic-tree
// headers for byte runs/tiny alphabets while retaining block_len for other data.
// RawDeflateIncrementalStoredDecoder is the caller-to-caller byte-progressive
// decode reference path for RFC 1951 stored blocks and bounded hostile input.
// RawDeflateIncrementalFixedLiteralDecoder adds resumable fixed-Huffman bit
// decoding plus caller-owned 32 KiB history for split length/distance matches.
// The same decoder switches between stored, fixed, and dynamic blocks without
// losing bit-reservoir or history state. Fixed/dynamic Huffman symbols use
// bounded prefix lookups, and matches copy in resumable spans rather than one
// byte at a time.
// Dynamic blocks currently progress through HLIT/HDIST/HCLEN and the split
// code-length alphabet/repeats into byte-progressive payload literals and matches.
// ZlibIncrementalDecoder layers split CMF/FLG and streaming Adler/footer
// validation over that raw decoder. The raw core reports the exact compressed
// prefix at EOB, so wrappers can batch input without consuming footer bytes.
// Exact-size caller output can finish the raw match and consume EOB/footer in
// the same step.
// initWithDictionary validates split DICTID and seeds the raw 32 KiB history
// from the caller-owned preset dictionary.
// GzipIncrementalDecoder supports split FEXTRA/FNAME/FCOMMENT/FHCRC plus
// streaming CRC-32/ISIZE and batches raw input up to the exact member footer.
// Set allow_concatenated to continue through RFC 1952 members while enforcing
// max_output_len/expected_output_len cumulatively.
// snapshot() reports the active/last member index and compressed offset; after
// an error it preserves the failing member, phase, and detection offset.
const zstd_dict_options: vort.ZstdNativeFrameOptions = .{ .selection = .literal_only };
const zstd_dict_bound = try vort.zstdEncodedNativeFrameBoundWithDictionary(
    "prefix: previous zstd history payload, shared phrase tail".len,
    zstd_dict_options,
    zstd_dict,
);
_ = zstd_dict_bound;
const zstd_dict_frame = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(
    allocator,
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict,
);
defer allocator.free(zstd_dict_frame.frame);
const zstd_dict_plain = try vort.zstdDecodeNativeFrameAllocWithDictionary(
    allocator,
    zstd_dict_frame.frame,
    zstd_dict,
);
defer allocator.free(zstd_dict_plain);
_ = zstd_dict_plain;
const zstd_dicts = [_]vort.ZstdNativeDictionary{zstd_dict};
const zstd_dict_set = vort.ZstdNativeDictionarySet.init(&zstd_dicts);
const zstd_dict_set_bound = try vort.zstdEncodedNativeFrameBoundWithDictionarySet(
    "prefix: previous zstd history payload, shared phrase tail".len,
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
);
_ = zstd_dict_set_bound;
const zstd_dict_set_frame = try vort.zstdEncodeNativeFrameWithDictionarySetAlloc(
    allocator,
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
);
defer allocator.free(zstd_dict_set_frame.frame);
var zstd_dict_set_append: std.ArrayList(u8) = .empty;
defer zstd_dict_set_append.deinit(allocator);
_ = try vort.zstdEncodeNativeFrameAppendWithDictionarySet(
    allocator,
    &zstd_dict_set_append,
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
);
const zstd_dict_set_into = try allocator.alloc(u8, zstd_dict_set_bound);
defer allocator.free(zstd_dict_set_into);
_ = try vort.zstdEncodeNativeFrameIntoSliceWithDictionarySet(
    allocator,
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
    zstd_dict_set_into,
);
const zstd_reusable_dict_set_frame = try zstd_encoder.encodeScratchWithDictionarySet(
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
);
_ = zstd_reusable_dict_set_frame.mode;
const zstd_reusable_dict_set_owned = try zstd_encoder.encodeWithDictionarySetAlloc(
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
);
defer allocator.free(zstd_reusable_dict_set_owned.frame);
_ = try zstd_encoder.encodeIntoSliceWithDictionarySet(
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
    zstd_dict_set_into,
);
const zstd_stream_plain = try vort.zstdDecodeNativeConcatenatedFrameAllocWithDictionarySet(
    allocator,
    zstd_dict_frame.frame,
    zstd_dict_set,
);
defer allocator.free(zstd_stream_plain);
const zstd_stream_exact = try vort.zstdDecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(
    allocator,
    zstd_dict_frame.frame,
    zstd_dict_set,
    zstd_stream_plain.len,
);
defer allocator.free(zstd_stream_exact);
const zstd_chunks = [_][]const u8{ zstd_dict_frame.frame[0..8], zstd_dict_frame.frame[8..] };
const zstd_join = try allocator.alloc(u8, zstd_dict_frame.frame.len);
defer allocator.free(zstd_join);
_ = try vort.zstdDecodedNativeFrameChunksSizeWithDictionarySet(
    &zstd_chunks,
    zstd_join,
    zstd_dict_set,
);
_ = try vort.zstdDecodedRawOrRleFrameChunksSizeWithDictionarySet(
    &zstd_chunks,
    zstd_join,
    zstd_dict_set,
);
_ = try zstd_decoder.decodedChunksSizeWithDictionarySet(&zstd_chunks, zstd_join, zstd_dict_set);
const zstd_chunk_plain = try zstd_decoder.decodeChunksScratchWithDictionarySet(&zstd_chunks, zstd_join, zstd_dict_set);
_ = zstd_chunk_plain;
var zstd_chunk_appended: std.ArrayList(u8) = .empty;
defer zstd_chunk_appended.deinit(allocator);
try zstd_chunk_appended.appendSlice(allocator, "prefix:");
_ = try vort.zstdDecodeNativeFrameChunksAppendWithDictionarySet(
    allocator,
    &zstd_chunk_appended,
    &zstd_chunks,
    zstd_join,
    zstd_dict_set,
);
_ = try vort.zstdDecodeNativeFrameChunksAppendExactSizeWithDictionarySet(
    allocator,
    &zstd_chunk_appended,
    &zstd_chunks,
    zstd_join,
    zstd_dict_set,
    zstd_stream_plain.len,
);
var zstd_chunk_out: ["prefix: previous zstd history payload, shared phrase tail".len]u8 = undefined;
_ = try vort.zstdDecodeNativeFrameChunksIntoWithDictionarySet(
    &zstd_chunks,
    zstd_join,
    &zstd_chunk_out,
    zstd_dict_set,
);
var zstd_reusable_chunk_appended: std.ArrayList(u8) = .empty;
defer zstd_reusable_chunk_appended.deinit(allocator);
try zstd_reusable_chunk_appended.appendSlice(allocator, "prefix:");
_ = try zstd_decoder.decodeChunksAppendExactSizeWithDictionarySet(
    &zstd_reusable_chunk_appended,
    &zstd_chunks,
    zstd_join,
    zstd_dict_set,
    zstd_stream_plain.len,
);

const zlib_bytes = try vort.encodeZlibFixedAlloc(allocator, "payload");
defer allocator.free(zlib_bytes);
const zlib_level_6 = try vort.encodeZlibLevelAlloc(allocator, "payload", 6);
defer allocator.free(zlib_level_6);
const zlib_level_options = try vort.optionsForZlibLevel(6);
_ = zlib_level_options; // numeric zlib levels 1..9; level 0 uses stored helpers
const zlib_header = try vort.parseZlibHeaderInfo(zlib_bytes);
_ = zlib_header.window_bits; // 15 for the default 32 KiB deflate window
const zlib_stream = try vort.inspectZlibStreamAlloc(allocator, zlib_bytes);
_ = zlib_stream.deflate_bytes; // exact raw DEFLATE byte count before Adler-32
_ = zlib_stream.adler32_matches; // diagnostic footer check
const zlib_exact = try vort.decodeZlibAllocExactSize(allocator, zlib_bytes, "payload".len);
defer allocator.free(zlib_exact);
const zlib_bounded = try vort.decodeZlibAllocLimited(allocator, zlib_bytes, 1024);
defer allocator.free(zlib_bounded);
const zlib_relaxed = try vort.decodeZlibAllocWithOptions(
    allocator,
    zlib_bytes,
    .{ .ignore_adler = true, .allow_trailing_data = true },
);
defer allocator.free(zlib_relaxed);
var zlib_out: [1024]u8 = undefined;
const zlib_written = try vort.decodeZlib(zlib_bytes, &zlib_out);
var zlib_decoder = try vort.ZlibDecoder.initWithOptionsExactSize(
    zlib_bytes,
    &zlib_out,
    .{ .ignore_adler = false },
    "payload".len,
);
var zlib_step_out: ["payload".len]u8 = undefined;
_ = try zlib_decoder.step(&zlib_step_out);
const zlib_chunks = [_][]const u8{ zlib_bytes[0..2], zlib_bytes[2..] };
var zlib_inspect_scratch: [1024]u8 = undefined;
const zlib_header_from_chunks = try vort.parseZlibHeaderInfoFromChunks(&zlib_chunks, &zlib_inspect_scratch);
_ = zlib_header_from_chunks.window_bits;
const zlib_chunk_info = try vort.inspectZlibStreamFromChunksAlloc(allocator, &zlib_chunks, &zlib_inspect_scratch);
_ = zlib_chunk_info.deflate_bytes;
const zlib_chunked_written = try vort.decodeZlibChunksInto(&zlib_chunks, &zlib_out);
_ = zlib_chunked_written;
var zlib_join_scratch: [1024]u8 = undefined;
const zlib_chunked_compat_written = try vort.decodeZlibChunks(&zlib_chunks, &zlib_join_scratch, &zlib_out);
_ = zlib_chunked_compat_written;
var zlib_chunked_decoder = try vort.ZlibDecoder.initFromChunksWithOptionsExactSize(
    &zlib_chunks,
    &zlib_join_scratch,
    &zlib_out,
    .{},
    "payload".len,
);
_ = try zlib_chunked_decoder.step(&zlib_step_out);
var zlib_cat: std.ArrayList(u8) = .empty;
defer zlib_cat.deinit(allocator);
try zlib_cat.appendSlice(allocator, zlib_bytes);
try zlib_cat.appendSlice(allocator, zlib_bytes);
const zlib_concatenated = try vort.decodeZlibConcatenatedAlloc(allocator, zlib_cat.items);
defer allocator.free(zlib_concatenated);
const zlib_cat_relaxed = try vort.decodeZlibConcatenatedAllocWithOptions(
    allocator,
    zlib_cat.items,
    .{ .ignore_adler = true, .allow_trailing_data = true },
);
defer allocator.free(zlib_cat_relaxed);
var zlib_cat_decoder = try vort.ZlibDecoder.initConcatenatedWithOptionsExactSize(
    zlib_cat.items,
    &zlib_out,
    .{},
    "payloadpayload".len,
);
var zlib_cat_step_out: ["payloadpayload".len]u8 = undefined;
_ = try zlib_cat_decoder.step(&zlib_cat_step_out);
const zlib_cat_chunks = [_][]const u8{ zlib_cat.items[0..2], zlib_cat.items[2..] };
var zlib_cat_join_scratch: [1024]u8 = undefined;
var zlib_cat_chunk_decoder = try vort.ZlibDecoder.initConcatenatedFromChunksExactSize(
    &zlib_cat_chunks,
    &zlib_cat_join_scratch,
    &zlib_out,
    "payloadpayload".len,
);
_ = try zlib_cat_chunk_decoder.step(&zlib_cat_step_out);
// FDICT concatenated streams can use the dictionary-aware variants:
// const zlib_dict_cat = try vort.decodeZlibConcatenatedAllocWithDictionary(
//     allocator, zlib_dict_bytes, "preset dictionary",
// );
// Dictionary-aware concatenated streams also have WithOptions variants when
// integrations need relaxed per-member Adler or trailing-data behavior.

const gzip_bytes = try vort.encodeGzipFixedAlloc(allocator, "payload");
defer allocator.free(gzip_bytes);
const gzip_level_6 = try vort.encodeGzipLevelAlloc(allocator, "payload", 6);
defer allocator.free(gzip_level_6);
const gzip_with_metadata = try vort.encodeGzipBestWithHeaderAlloc(
    allocator,
    "payload",
    vort.optionsForCompressionLevel(.default),
    .{
        .mtime = 0,
        .filename = "payload.txt",
        .comment = "deterministic Vort gzip stream",
        .header_crc = true,
    },
);
defer allocator.free(gzip_with_metadata);
const gzip_header = try vort.parseGzipHeaderInfo(gzip_with_metadata);
_ = gzip_header.filename; // "payload.txt"; slices alias gzip_with_metadata
const gzip_member = try vort.inspectGzipMemberAlloc(allocator, gzip_bytes, 0);
_ = gzip_member.deflate_bytes; // exact raw DEFLATE byte count for member 0
_ = gzip_member.crc32_matches; // diagnostic trailer check; false does not hide member offsets
const gzip_exact = try vort.decodeGzipAllocExactSize(allocator, gzip_bytes, "payload".len);
defer allocator.free(gzip_exact);
const gzip_cat_exact = try vort.decodeGzipConcatenatedAllocExactSize(allocator, gzip_bytes, "payload".len);
defer allocator.free(gzip_cat_exact);
const gzip_bounded = try vort.decodeGzipConcatenatedAllocLimited(allocator, gzip_bytes, 1024);
defer allocator.free(gzip_bounded);
var gzip_out: [1024]u8 = undefined;
const gzip_written = try vort.decodeGzip(gzip_bytes, &gzip_out);
const gzip_chunks = [_][]const u8{ gzip_bytes[0..4], gzip_bytes[4..] };
var gzip_join_scratch: [1024]u8 = undefined;
const gzip_header_from_chunks = try vort.parseGzipHeaderInfoFromChunks(&gzip_chunks, &gzip_join_scratch);
_ = gzip_header_from_chunks.data_offset;
const gzip_member_from_chunks = try vort.inspectGzipMemberFromChunksAlloc(allocator, &gzip_chunks, &gzip_join_scratch, 0);
_ = gzip_member_from_chunks.deflate_bytes;
const gzip_chunked_written = try vort.decodeGzipChunks(&gzip_chunks, &gzip_join_scratch, &gzip_out);
_ = gzip_chunked_written;
const gzip_chunked_exact = try vort.decodeGzipChunksAllocExactSize(
    allocator,
    &gzip_chunks,
    &gzip_join_scratch,
    "payload".len,
);
defer allocator.free(gzip_chunked_exact);
const gzip_cat_written = try vort.decodeGzipConcatenated(gzip_bytes, &gzip_out);
const gzip_cat_chunks = [_][]const u8{ gzip_bytes[0..4], gzip_bytes[4..] };
const gzip_cat_chunked_written = try vort.decodeGzipConcatenatedChunks(&gzip_cat_chunks, &gzip_join_scratch, &gzip_out);
_ = gzip_cat_chunked_written;

// Limited decode APIs return error.OutputLimitExceeded before allocating or
// appending beyond the caller's declared uncompressed-size budget. Dictionary
// variants are available for raw deflate and zlib streams that need preset
// history. The zlib dictionary encoders emit FDICT/DICTID and the raw/zlib
// planners can emit back-references into the preset history:
// const dict_decoded = try vort.decodeZlibAllocWithDictionaryLimited(
//     allocator,
//     zlib_with_dictionary,
//     dictionary,
//     1024,
// );
// defer allocator.free(dict_decoded);
// const dict_encoded = try vort.encodeZlibBestWithDictionaryAlloc(
//     allocator,
//     "payload",
//     dictionary,
//     vort.optionsForCompressionLevel(.default),
// );
// defer allocator.free(dict_encoded);
```

### Brotli planned encoder knob

`BrotliPlannedEncodeOptions.extended_dictionary_probes` lets ratio-mode callers
explicitly spend more CPU looking for RFC 7932 static-dictionary matches in
257-byte through 4 KiB inputs. The default is `0`, so the established automatic
search remains limited to inputs of at most 256 bytes and default wire output
and latency remain unchanged. Values `1...brotliMaxExtendedDictionaryProbes`
(`4096` currently) cap the number of literal positions examined; `64` is a
practical starting point for text-oriented workloads. A candidate replaces the
ordinary LZ/stored result only when its complete Brotli wire is strictly
smaller. Non-zero budgets require `.ratio`; inputs above 4 KiB and larger
budgets return `error.InvalidBlockPlan`.
The planned encode benchmark accepts `--extended-dictionary-probes N`, so this
opt-in path can be measured with the same built-in and repeatable `--path`
corpora as the default levels.
`brProfilePlannedRatioBlockAlloc` is the explicit diagnostic counterpart for
default-window 4--32 KiB ratio blocks. It reproduces the production wire while
reporting lazy/optimal plan, command, wire, and selection timings plus optimal
chain/search counters, first-prefix-mismatch buckets, and lower-bound
length/distance-cost/slack plus length-extension histograms;
normal encode entrypoints do not enable those counters.
`run-br-ratio-stage-profile-gate` writes and validates the corresponding
three-size source profile at `zig-out/vort-br-ratio-stage-profile.csv`, including
input/output hashes, stage/count identities, and independent libbrotli decode.

### Native LZ4/Zstd library knobs

The native LZ4/Zstd APIs are library-first.  CLI commands and probes call the
same public symbols shown above; applications should use the allocator/append,
caller-owned slice, reusable scratch, chunked, and incremental decoder APIs
directly.
Zstd native encoded-bound helpers now account for the same shortest
single-segment `Frame_Content_Size` width used by the writer, so callers sizing
`encode*IntoSlice` buffers do not reserve the old eight-byte content-size worst
case for small and medium frames.

| Codec | Option / symbol | Default / range | Use when | Tradeoff |
| --- | --- | --- | --- | --- |
| LZ4 native | `Lz4NativeFrameOptions.block_mode` | `.independent` or `.linked` | Consecutive frame blocks share recent history and ratio matters. | `.linked` can improve ratio across block boundaries; `.independent` is simpler for random block handling. |
| LZ4 native | `Lz4NativeFrameOptions.block_size_id` | `.max4mb`; `.max64kb` / `.max256kb` / `.max1mb` / `.max4mb` | You need a latency/working-set knob for frame block size. | Smaller blocks can reduce latency and direct-output burst size; larger blocks usually reduce framing overhead. |
| LZ4 native | `Lz4NativeFrameOptions.chain_depth` | `vort.lz4NativeMaxChainDepth` (`16` currently); `0...vort.lz4NativeMaxChainDepth` | You want to trade encode CPU for deeper hash-chain match search. | `0` disables match search and is fastest/least compact; the default enables the deeper parser used by the native bench ratio rows. |
| LZ4 native | `content_checksum` / `block_checksum` | content checksum on by default; block checksum off by default | You need frame or block corruption detection in the native frame itself. | Checksums add bytes and CPU but give earlier corruption reports. |
| LZ4 native | `Lz4NativeDictionary` | caller-owned bytes plus non-zero `id` | Payloads share a known prefix/history. | Encoder can emit dictionary references; decoder must be given the matching dictionary or dictionary set. |
| LZ4 native | `Lz4OwnedNativeDictionary.metadata()` / `Lz4NativeDictionary.initFromMetadata` / `encodeDictionaryMetadata*` / `decodeDictionaryMetadata*` / `*DictionaryMetadataCatalog*` | shared `DictionaryMetadata` plus 64 KiB history window; single records are 32 bytes and catalogs are versioned counted records with strict and prefix decoders | You want to persist trained dictionary catalog metadata from the same object returned by `lz4TrainNativeDictionaryAlloc`, then verify received bytes before decoding. | Metadata uses the wider shared dictionary fingerprint; frame `Dictionary_ID` is still derived from validated bytes; dictionary bytes are still distributed separately. |
| LZ4 native | `Lz4NativeDictionarySet` / `Lz4NativeDictionarySet.initFromMetadata` / `lz4NativeDictionarySetFromMetadataAlloc` | caller-owned slice of dictionaries or validated metadata+bytes catalog | Concatenated streams can carry different `Dictionary_ID` values, or a container provides versioned metadata records beside dictionary bytes. | Lets decoders resolve each frame without caller-side splitting; metadata construction validates bytes and duplicate IDs before decode; the alloc helper owns only the small catalog array. |
| Zstd native | `ZstdNativeFrameOptions.selection` | `.auto`; `.auto` / `.raw_or_rle` / `.literal_only` | You need deterministic native-subset frame selection. | `.auto` chooses the smaller implemented native mode; explicit modes are useful for tests and predictable behavior. |
| Zstd native | `ZstdNativeFrameOptions.block_size_max` | `std.compress.zstd.block_size_max`; `1...std.compress.zstd.block_size_max` | You need a latency/seekability/ratio knob. | Smaller blocks reduce per-block latency and direct-output bursts; larger blocks usually improve ratio and reduce headers. |
| Zstd native | `ZstdNativeFrameOptions.match_search_budget` | `vort.zstdNativeMaxMatchSearchBudget` (`512` currently); `0...vort.zstdNativeMaxMatchSearchBudget` | You want to bound the bootstrap mixed-match planner. | `0` disables generic duplicate/repeated mixed planning while dictionary-only matches can still be used; the default searches more branches for ratio. |
| Zstd native | `vort.zstdNativeMaxDirectHuffmanSymbol` | `128` currently | You need to know when the bootstrap writer can use direct Huffman literal weights. | Byte values above this use FSE-compressed Huffman weights when the literal-only plan wins; incompressible shapes can still fall back to raw/RLE or another native plan. |
| Zstd native | `content_checksum` / `include_content_size` | both on by default | You want self-describing frames and content verification. | Disabling them saves bytes when a container already carries size/checksum metadata. |
| Zstd native | `ZstdNativeDictionary` / `ZstdNativeDictionary.initRawContent` | caller-owned bytes plus a non-zero ID, or explicit ID-less raw content | Payloads share preset history, including standard Zstd raw-content dictionary interoperability. | Non-zero IDs can be resolved through dictionary sets; ID-less frames require the caller to pass the raw dictionary explicitly, including through the `zstdDecodeNativeSeekableRange*WithDictionary` scan/index APIs, because the frame cannot select it from a set. |
| Zstd native | `zstdStandardDictionaryFromContentBound` / `zstdStandardDictionaryFromContentInto` / `zstdStandardDictionaryFromContentAlloc` | non-zero ID and at least 8 bytes of caller-selected history; generated header is `zstdStandardDictionaryHeaderLen` bytes | You need a dependency-free RFC 8878 full-dictionary container accepted by Vort and libzstd. | Uses stable portable baseline Huffman/FSE tables and repcodes `1/4/8`; it wraps selected history but does not train corpus-specific entropy statistics like COVER/FastCover. |
| Zstd native | `zstdTrainStandardDictionaryAlloc` | representative sample slices, native history `ZstdDictionaryTrainOptions`, and a non-zero ID | You want Vort to train selected history and first-block entropy models without libzstd. | Trains a complete 256-symbol Huffman table from raw sample-byte frequencies and OF/ML/LL FSE tables from dictionary-aware LZ77 sequence codes. It ranks the first two explicit offsets, retrains for that repcode candidate, and adopts it only when forced-compressed sample frames are strictly smaller by at least 1%; ties and sub-threshold changes retain `1/4/8`. The deterministic history selector is not COVER/FastCover. |
| Zstd native | `zstdTrainValidatedStandardDictionaryAlloc` | training samples, non-empty selector samples, history options, and non-zero ID | You can reserve representative payloads to select a better history without external trainers. | Evaluates total-frequency/cross-sample rankings, phrase configurations, ranked/reverse layouts, raw corpus-tail history, and five history sizes down to 25% using selector coverage plus estimated dictionary/literal/offset cost, then trains standard entropy tables from both input partitions; keep a separate held-out set for evaluation. This remains narrower than COVER/FastCover. |
| Shared dictionary | `dictionary.trainValidatedTargetsAlloc` | training samples, selector samples, ordered target sizes, and shared phrase options | You need several validation-selected history sizes from the same corpus. | Collects every phrase configuration once, then independently assembles and scores each requested target without changing candidate or tie order. The returned optional slices are owned by `OwnedValidatedDictionaries`; use `take(index)` to transfer one before `deinit`. The Zstd validated standard trainer uses this internally for its five-size ladder. |
| Shared dictionary | `summarizeDictionaryMatches` / `dictionary.validationScore` | borrowed dictionary, sample slices, and non-zero minimum match length | You need dictionary coverage/cost diagnostics without temporary allocation. | Streams the same greedy matches as `findDictionaryMatchesAlloc`; the legacy `summarizeDictionaryMatchesAlloc` and `dictionary.validationScoreAlloc` names remain compatible wrappers but no longer allocate. |
| Zstd native | `ZstdOwnedNativeDictionary.metadata()` / `ZstdNativeDictionary.initFromMetadata` / `encodeDictionaryMetadata*` / `decodeDictionaryMetadata*` / `*DictionaryMetadataCatalog*` | shared `DictionaryMetadata` plus `std.compress.zstd.default_window_len`; single records are 32 bytes and catalogs are versioned counted records with strict and prefix decoders | You want to persist trained dictionary catalog metadata from the same object returned by `zstdTrainNativeDictionaryAlloc`, then verify received bytes before decoding. | Metadata uses the wider shared dictionary fingerprint; frame `Dictionary_ID` is still derived from validated bytes; dictionary bytes are still distributed separately. |
| Zstd native | `ZstdNativeDictionarySet` / `ZstdNativeDictionarySet.initFromMetadata` / `zstdNativeDictionarySetFromMetadataAlloc` | caller-owned slice of dictionaries or validated metadata+bytes catalog | Concatenated streams can carry different `Dictionary_ID` values, or a container provides versioned metadata records beside dictionary bytes. | Shared decoder APIs resolve per-frame IDs and avoid manual stream splitting; metadata construction validates bytes and duplicate IDs before decode; the alloc helper owns only the small catalog array. |

For bounded-memory decode, prefer the `*Limited`, exact-size, chunked, append,
and incremental forms when the surrounding container knows the expected output
length or has an allocation budget. Chunked append helpers decode split
compressed input into an existing `ArrayList`, so containers can preserve their
own prefixes/sidecars without constructing a reusable decoder just to avoid an
alloc-returning API. `*AppendExactSize` variants additionally verify the decoded
byte count before extending the destination, returning `SizeMismatch` for
container-advertised lengths that do not match the stream. Reusable
`NativeFrameDecoder` values expose matching single-frame `decodeChunks*` and
concatenated `decodeConcatenatedChunks*` helpers, so callers can keep
decoder-owned scratch capacity while still appending into their own output
buffers. Native one-shot, chunked, concatenated, and reusable decoders also provide
`decode*Into*ExactSize` forms, including dictionary/dictionary-set variants, for
caller-owned slices when a container-advertised byte count must match exactly.
Incremental native decoders expose the shared `StepResult`
contract: feed compressed bytes, provide caller-owned output slices, then call
`finish()` when an exact EOF/size check matters. Direct-output paths are fastest
when the caller supplies a large enough output slice; if a slice is too small
for an atomic compressed block, the decoders intentionally fall back to bounded
scratch and continue draining without losing correctness. Dictionary-set
chunked APIs additionally accept caller-owned compressed join scratch so split
input can be decoded without hidden global state. Public dictionary probes also
pin error precedence for hostile frames that carry a missing or mismatched
`Dictionary_ID` plus another defect: LZ4 covers content checksum, block
checksum, and content-size conflicts across one-shot and incremental paths;
Zstd covers content checksum, content-size, malformed raw/RLE blocks, and
malformed compressed sequence-table blocks, including incremental diagnostics
where that path applies. Dictionary-set probes extend the same precedence to
skippable concatenated streams whose later frame needs a missing ID, including
chunked/reusable helpers and incremental dictionary-set drains. LZ4
dictionary-set fixtures now cover later-frame block checksum, content checksum,
content-size, and invalid-match conflicts; Zstd dictionary-set fixtures cover
malformed compressed sequence-table conflicts. In those cases callers see
`NeedDictionary` before deeper payload or checksum errors, while providing the
matching dictionary exposes the underlying `ChecksumMismatch`, `SizeMismatch`,
`InvalidMatch`, or `CorruptFrame`.

`run-lz4-native-probe` also dynamically calls liblz4's `LZ4F_compressFrame` for 120 frame option/level/payload combinations spanning all four block-size IDs, linked and independent modes, checksums, omitted content size, and a 300 KiB multi-block payload. It decodes those frames through Vort's one-shot, incremental, reusable, and chunked public APIs, and independently decodes matching Vort-generated frames through `LZ4F_decompress`, so LZ4 interoperability coverage is bidirectional and is not limited to CLI routing.

`run-snappy-interop-probe` dynamically calls the complete libsnappy raw-block C
API. Eight libsnappy-generated blocks, from empty and tiny data through a 64 KiB
incompressible block and a 160 KiB multi-chunk payload, are decoded through
Vort's one-shot, exact-size caller-buffer, and split-input APIs. Matching
Vort-generated raw blocks are validated and decoded by libsnappy; the fixed
matrix requires copy-bearing output from both encoders. The same
libsnappy blocks are wrapped in standard checksummed framed-stream chunks and
decoded through Vort's one-shot, caller-buffer, split-input, and incremental
APIs, while every compressed block in Vort-generated frames is independently
validated and decoded by libsnappy (currently seven compressed chunks across
nine data chunks). The runtime dependency exists only in the probe; truncating
every libsnappy block must also be rejected by both implementations. The
production Snappy implementation remains pure Zig.

The focused library benchmark/gate tracks these public surfaces directly:

```sh
zig build run-native-library-bench
zig build run-native-library-bench -- --path README.md --limit 4096 --iterations 1
zig build run-native-library-bench-path-gate
zig build run-native-library-bench-gate
zig build run-native-library-bench-releasefast-csv
zig build run-native-library-bench-releasefast-gate
zig build run-native-library-bench-releasefast-path-gate
```

The bench command accepts repeated `--path` arguments plus `--limit` for focused project-file payloads. The Debug and ReleaseFast gates currently require the LZ4 chain-depth, Zstd match-budget, high-byte
FSE Huffman, LZ4/Zstd lib/native lib-decode rows, Zstd sequence-Huffman literal, LZ4/Zstd lib-generated compatibility-frame/no-size/checksum/no-size+checksum/independent/full-independent, dictionary, trained-dictionary,
dictionary-set, chunked dictionary-set, chunked append, chunked append exact-size, reusable decoder,
reusable append exact-size, direct-output, and small-output rows to
round-trip and to preserve the expected size relationships. In addition to the
CSV rows, the bench executable now runs cheap pre-row smoke checks for
no-content-size multi-compressed Zstd frames (including checksum mismatch and
truncated-checksum limit precedence), LZ4 skippable streams followed by
malformed/truncated/checksum/trailing frames, and LZ4/Zstd dictionary-set
skippable streams in direct-output plus codec-specific small-output modes. These checks intentionally
do not add CSV rows, keeping the Debug gate bounded. The heavier limited
compressed-FSE sequence-table path is covered by
`run-zstd-native-dictionary-probe` for public inspect/decode of LL/OF/ML=FSE
blocks plus repeated sequence-table reuse, and `run-zstd-native-frame-probe` for
treeless repeat-Huffman literal reuse, mixed compressed-FSE sequence-table
layouts (for example OF+ML=FSE with predefined LL), repeat-offset selector variants
(zero-literal rep1/rep2, positive-literal rep2, invalid `rep0 - 1`, valid cross-block `rep0 - 1` including the minimum non-zero boundary after a direct-offset update plus Repeat_Mode replay, multi-sequence predefined-table state transitions, mixed RLE/predefined sequence modes, and repeated mixed-table modes across blocks, and pure library-level libzstd-generated frame differentials with incremental drains and chunked split-input helpers), and
malformed sequence bitstreams, mixed-table reserved-bit/truncated/short-bitstream paths, and short/corrupt LL/OF/ML compressed-FSE state streams,
while focused unit tests keep the writer-side ML=FSE construction covered
without adding the heavier path to the regular native library bench gate.

## Direction

See `docs/native-format.md` for the initial native Vort frame direction,
`docs/native-lz4-zstd-status.md` for the current native LZ4/Zstd implementation
audit, `docs/validation-json.md` for validation/report JSON schemas,
`docs/fuzzing.md` for parser fuzzing entrypoints, `docs/external-differential.md` for competitor
differential validation, `docs/checksum-dispatch.md` for checksum dispatch
status, `docs/zstd-gap.md` for current zstd comparison limitations, and
`docs/dynamic-encoder.md` for dynamic encoder status. Local Rust deflate
baselines such as `~/Work/fdeflate` and `~/Work/miniz_oxide` should be treated
as required functionality/performance competitors once their executable harnesses
are wired into Vort validation.

Compatibility formats (`raw deflate`, `zlib`, `gzip`, `bzip2`, `XZ/LZMA2`,
LZMA-Alone, and selected zstd-facing workflows) should be behavior-compatible where claimed.
Native Vort formats may innovate more aggressively, but they must be versioned,
documented, fuzzed, benchmarked, and differentially tested against reference
implementations where a reference exists.
