# Vort

Vort is a Zig-first next-generation compression library project. Its long-term
objective is to surpass `zlib`, `zlib-ng`, `zlib-rs`, and `zstd` in both
functionality and performance while preserving explicit ownership, deterministic
behavior, robust validation, and library-first APIs.

The repository is currently in bootstrap form. The first implemented pieces are:

- zlib-compatible Adler-32;
- gzip/zip-compatible IEEE CRC-32;
- storage/network-oriented CRC-32C/Castagnoli;
- portable slice-by-4/slice-by-8/slice-by-16 IEEE CRC-32 and slice-by-8/slice-by-16 CRC-32C fast paths, checksum dispatch reporting, and Adler-32/CRC-32/CRC-32C combine helpers for block/parallel checksum composition;
- shared progress/error/frame metadata types;
- raw deflate stored/fixed/dynamic/best encode and stored/fixed/dynamic decode, with zlib/gzip wrappers plus preset-dictionary-aware raw/zlib encode/decode;
- a native `VORT` store frame with skippable frames, concatenated streams, checksum-validated in-memory/serialized frame indexes, frame-index CRC composition, range CRC summaries, caller-owned and batch range decode APIs, and bounded streaming APIs;
- LZ77 greedy/lazy/optimal parser prototypes, dictionary metadata/training, match-coverage, patch-codec, native dictionary-patch frame, self-contained dictionary streams, native LDM reference frame, and dictionary-/LDM-aware native best-frame prototypes, long-distance match scanner, LDM-aware block planner, CLI smoke surfaces, fuzz corpus harnesses, and benchmark/report entrypoints.

Hosted CI runs on `main` pushes and pull requests through
`.github/workflows/ci.yml`, which installs Zig 0.16, checks formatting, runs
`ci-smoke`, and repeats the focused fuzz smoke entrypoints.

## Commands

```sh
zig build test
zig build check
zig build -Doptimize=ReleaseFast ci-smoke
zig build run -- --help
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
zig build run-zlib-diff
zig build run-gzip-diff
zig build run-python-zlib-diff
zig build run-python-zlib-diff-dashboard
zig build run-gzip-cli-diff
zig build run-header-inspect-smoke
zig build run-header-inspect-dashboard
zig build run-dashboard-category-smoke
zig build run-zlib-family-diff
zig build run-rust-deflate-diff
zig build run-external-probe
zig build run-cpu-features
zig build run-zstd-compare
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
zig build bench-deflate-decode -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report -- --iterations 1000
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report-csv
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report-dashboard  # writes CSV/Markdown/JSON decode-stage artifacts
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
const raw_exact = try vort.decodeRawDeflateAllocExactSize(allocator, raw, "payload".len);
defer allocator.free(raw_exact);
const bounded = try vort.decodeRawDeflateAllocLimited(allocator, raw, 1024);
defer allocator.free(bounded);

const zlib_bytes = try vort.encodeZlibFixedAlloc(allocator, "payload");
defer allocator.free(zlib_bytes);
const zlib_header = try vort.parseZlibHeaderInfo(zlib_bytes);
_ = zlib_header.window_bits; // 15 for the default 32 KiB deflate window
const zlib_stream = try vort.inspectZlibStreamAlloc(allocator, zlib_bytes);
_ = zlib_stream.deflate_bytes; // exact raw DEFLATE byte count before Adler-32
_ = zlib_stream.adler32_matches; // diagnostic footer check
const zlib_exact = try vort.decodeZlibAllocExactSize(allocator, zlib_bytes, "payload".len);
defer allocator.free(zlib_exact);
const zlib_bounded = try vort.decodeZlibAllocLimited(allocator, zlib_bytes, 1024);
defer allocator.free(zlib_bounded);
var zlib_out: [1024]u8 = undefined;
const zlib_written = try vort.decodeZlib(zlib_bytes, &zlib_out);
var zlib_cat: std.ArrayList(u8) = .empty;
defer zlib_cat.deinit(allocator);
try zlib_cat.appendSlice(allocator, zlib_bytes);
try zlib_cat.appendSlice(allocator, zlib_bytes);
const zlib_concatenated = try vort.decodeZlibConcatenatedAlloc(allocator, zlib_cat.items);
defer allocator.free(zlib_concatenated);
// FDICT concatenated streams can use the dictionary-aware variants:
// const zlib_dict_cat = try vort.decodeZlibConcatenatedAllocWithDictionary(
//     allocator, zlib_dict_bytes, "preset dictionary",
// );

const gzip_bytes = try vort.encodeGzipFixedAlloc(allocator, "payload");
defer allocator.free(gzip_bytes);
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
const gzip_cat_written = try vort.decodeGzipConcatenated(gzip_bytes, &gzip_out);

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

## Direction

See `docs/native-format.md` for the initial native Vort frame direction,
`docs/validation-json.md` for validation/report JSON schemas, `docs/fuzzing.md`
for parser fuzzing entrypoints, `docs/external-differential.md` for competitor
differential validation, `docs/checksum-dispatch.md` for checksum dispatch
status, `docs/zstd-gap.md` for current zstd comparison limitations, and
`docs/dynamic-encoder.md` for dynamic encoder status. Local Rust deflate
baselines such as `~/Work/fdeflate` and `~/Work/miniz_oxide` should be treated
as required functionality/performance competitors once their executable harnesses
are wired into Vort validation.

Compatibility formats (`raw deflate`, `zlib`, `gzip`, and selected zstd-facing
workflows) should be behavior-compatible where claimed. Native Vort formats may
innovate more aggressively, but they must be versioned, documented, fuzzed,
benchmarked, and differentially tested against reference implementations where a
reference exists.
