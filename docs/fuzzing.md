# Fuzzing plan

Current deterministic fuzz entrypoints:

```sh
zig build run-fuzz-smoke
zig build run-fuzz-corpus
zig build run-fuzz-corpus -- <hex-sample> [...]
zig build run-fuzz-corpus -- --deflate --expect=reject <hex-sample>
zig build run-fuzz-corpus -- --file corpus/deflate-wrapper-smoke.hex
zig build run-fuzz-target
zig build run-libfuzzer-smoke
zig build run-afl-smoke
zig build -Doptimize=ReleaseFast ci-smoke
```

Coverage-guided fuzzing should target these parser surfaces first:

1. native VORT store headers and skippable frames;
2. serialized frame indexes;
3. raw deflate block headers and stored/fixed/dynamic block transitions;
4. zlib/gzip wrappers and optional gzip headers.

The shared raw-byte target also probes bounded container readers, including
native LZ4 frames generated through the public LZ4HC encoder, plus
Android sparse v1 metadata and CRC checkpoints plus Android OTA v2 headers,
protobuf manifests, operation hashes, short partition/range reads, and bounded
BSDIFF40/BSDF2, PUF1/PUFFDIFF, LZ4DIFF, and Zucchini v1 application. Valid
seeds exercise each nested patch surface rather than only malformed header
rejection; the LZ4DIFF seed reaches a complete BSDIFF application and LZ4HC
level-5 target reconstruction, while the Zucchini seed reaches CRC-checked
NoOp literal application, a second seed reaches AArch64 ELF target-pool and
branch-reference correction, and a third reaches PE32+ base-relocation,
absolute-pointer, and rel32 correction. A fourth valid seed reaches AArch32 ELF
relocation, absolute-pointer, and ARM A24 branch correction. A fifth reaches
DEX fixed tables, Dalvik code references, raw integrity deltas, and target-pool
correction. A sixth exercises ZTF line/column translation and textual reference
rewriting.

The `tools/fuzz_corpus.zig` command is intentionally hex-sample based so corpus
reducers can feed minimized byte strings without inventing a file format.
`--store`, `--deflate`, `--zlib`, and `--gzip` switch the decoder used for
subsequent hex tokens. `--expect=accept|reject|any` (or the spelling variants
`--expect-accept`, `--expect-reject`, and `--expect-any`) sets a sticky expected
outcome for subsequent tokens; corpus files may use `# expect: accept` or
`# expect: reject` inline next to a sample. The harness fails on
`UnexpectedAccept` or `UnexpectedReject` when a regression changes a sample's
classification.
`--dict=<text>`, `--dict-hex=<hex>`, and `--dict-clear` set or clear a sticky
preset dictionary for subsequent raw deflate and zlib samples, allowing minimized
dictionary-reference regressions to live in the same corpus file as ordinary
wrapper samples. `--limit=<bytes>` and `--limit-clear` similarly exercise
bounded-output raw/zlib/gzip decode paths.
`tools/fuzz_target.zig` exposes `fuzzOne(allocator, data)` for raw-byte fuzz
runners and also has a smoke-test main. `tools/fuzz_libfuzzer.zig` exports `LLVMFuzzerTestOneInput` and is smoke-tested by `run-libfuzzer-smoke`. `tools/fuzz_afl.zig` is an AFL-style file-input driver suitable for `@@` invocations and is smoke-tested by `run-afl-smoke`. AFL/libFuzzer packaging should preserve crashing inputs as hex samples in regression tests.
The `ci-smoke` aggregate build step runs the deterministic fuzz entrypoints
alongside unit tests, compile checks, differential harnesses, and benchmark
smoke reports so local changes can use one command before commit.
The hosted GitHub Actions workflow in `.github/workflows/ci.yml` also reruns
the focused fuzz smoke entrypoints explicitly after `ci-smoke`, keeping the
local and hosted parser-validation surfaces aligned.

## 2026-11-10: Brotli and Zstd join the raw-byte fuzz target

`tools/fuzz_target.zig` previously fed every raw input only to
`vort.decodeRawDeflateAlloc` and container parsers. It now also calls
`vort.br.decodeStreamAlloc` and `vort.zstd.decodeFrameAlloc`, accepting
and freeing valid output and treating every documented decode error
(including `InvalidMagic` for non-frame inputs) as an expected rejection.
This gives the coverage-guided (`run-libfuzzer-smoke`,
`run-afl-smoke`) and deterministic (`run-fuzz-target`) harnesses the
same malformed-payload reach into the Brotli and Zstd entropy decoders
that raw Deflate already had. Verified gates:

- `zig build run-fuzz-target` (64 samples)
- `zig build run-libfuzzer-smoke`, `zig build run-afl-smoke`
- `zig build run-fuzz-corpus-coverage-smoke` (3 wrapper modes, 22 exact
  error expectations)
- `zig build run-native-fuzz-corpus-coverage-smoke` (1 native mode,
  7 exact error expectations)

## 2026-11-12: structure-aware codec differential fuzzing

`tools/codec_differential_fuzz.zig` (`run-codec-differential-fuzz`)
complements the raw-byte target with generated valid wires. A deterministic
SplitMix64 generator feeds eight content patterns (RLE, periodic, random,
text-like, mixed runs and sparse binary) across boundary sizes from 0 bytes
through 8 KiB (`--deep` extends the schedule to 64 KiB) into:

- raw Deflate levels 0/1/6/9, zlib levels 0/6/9 and gzip levels 0/6/9 (level
  0 exercises the stored-block encoder explicitly);
- standard Zstd frames at levels 1/3/9;
- RFC Brotli qualities 0/5/11 (q11 only for inputs up to 1 KiB in smoke).

Every valid wire is checked three ways: Vort one-shot and exact-size decode
must reproduce the source; the installed system references (zlib, libzstd,
libbrotli via `@cImport`) must accept the same wire and reproduce the source;
then systematic prefix truncation and five-position/three-mask single-byte
mutations are replayed through both Vort and the references. Truncation
requires both decoders to reject or both to produce identical bytes; mutation
agreement is required whenever both accept, while one-sided acceptance is
retained as a counted divergence signal rather than a hard failure. The
reference destination carries bounded 4x/1 MiB headroom so mutated RLE
expansion cannot alias the original output buffer.

The default smoke campaign covers 3,168 valid wires, 75,531 truncation cuts
and 44,055 mutations with zero cross-decoder disagreements. Because the tool
links system libraries, it runs on native targets only and is wired into
`check` (compile) and `ci-smoke` (execution); hosted CI already installs
`zlib1g-dev`, `libzstd-dev` and `libbrotli-dev`.

The first `--deep` campaign (3,640 valid wires, 91,267 truncation cuts,
45,795 mutations, sizes to 64 KiB) found a real Brotli decoder panic: a
malformed complex prefix-code description could end a code-16 repeat exactly
on the alphabet boundary and then issue one more direct length symbol,
indexing `lengths[alphabet_size]` out of bounds instead of returning
`InvalidHuffmanCode`. All three complex prefix-code readers (runtime,
resumable large-command, and profiled) now reject an overfull alphabet after
a flushed repeat, and a focused regression test pins the crafted bitstream.
After the fix, an independent-seed deep campaign and a rerun with the final
binary (up to 3,888 valid wires, 99,451 truncation cuts and 48,315 mutations
per campaign) both completed with zero cross-decoder disagreements.

## 2026-11-13: format-feature variants and expanded mutation matrix

The generator now reaches format surfaces that valid-wire generation
previously skipped. Every baseline wire keeps its original checks, and the
new variants run through the same round-trip, exact-size, reference-interop,
truncation and mutation pipeline:

- raw Deflate and zlib preset dictionaries (deep; level 0 excluded). The
  reference installs raw-Deflate dictionaries proactively before the first
  `inflate` call (raw streams cannot signal `Z_NEED_DICT`) and zlib
  dictionaries reactively on `Z_NEED_DICT`, matching Vort's two contracts;
- rich gzip headers with randomized FEXTRA/FNAME/FCOMMENT/FHCRC, MTIME, XFL
  and OS fields through both the stored and best encoders;
- Zstd content checksums, unknown content size, explicit Window_Log 10
  frames, two-frame concatenation and skippable frames in leading, trailing
  and interspersed positions. The libzstd one-shot API rejects skippable and
  concatenated suffixes while Vort's frame loop accepts them, so those
  variants use a `ZSTD_decompressStream` reference whose completion rule is
  full input consumption plus a zero final hint (the API buffers partial
  magic bytes and returns a positive hint for truncated streams, and returns
  0 at every frame boundary);
- Brotli explicit window widths (10/16/24 in deep), disabled literal context
  modeling, a metadata meta-block prefix and the opt-in Large Window
  extension (lgwin 30), checked against a libbrotli streaming decoder with
  `BROTLI_DECODER_PARAM_LARGE_WINDOW` enabled;
- deep-only two-member concatenated gzip streams. The one-shot gzip facade
  validates exactly one member, so Vort uses `GzipIncrementalDecoder` with
  `allow_concatenated` while the reference runs one `inflate` state per
  member (a single inflate call stops at the first `Z_STREAM_END` and does
  not auto-continue);
- deep-only Zstd raw-content dictionary frames. Both Vort and the
  `ZSTD_decompress_usingDict` reference are handed the same raw dictionary;
  the reference rejects the wire without it, pinning the dictionary contract,
  while truncated and mutated prefixes still run through the full agreement
  pipeline;
- deep-only Zstd standard full dictionary frames trained from a deterministic
  eight-sample corpus. The frame header carries the Dictionary_ID and the
  reference receives the full serialized dictionary through
  `ZSTD_decompress_usingDict`; without it the reference rejects the frame with
  a dictionary mismatch. The trainer's substring scan is quadratic, so the
  variant runs only at the representative level and on inputs up to 2 KiB with
  bounded phrase options, keeping a full deep campaign around seven minutes;
- deep-only Brotli RAW shared-prefix dictionary frames with an overlapping
  payload. The installed libbrotli 1.0.9 exports no `AttachDictionary`
  symbol, so this is a Vort-to-Vort contract variant: attached-prefix decode
  must reproduce the source, no-prefix decode must reject it, and mutation
  output-length changes fail while content-only corruption is counted as a
  one-sided divergence rather than a hard interop failure;
- deep campaigns add eight RNG-driven random sizes per pattern alongside the
  fixed boundary schedule.

The mutation matrix keeps five-position XOR flips for every wire and adds,
for wires up to 2 KiB, fixed-position overwrite (0x00/0xff/random), single
random-byte insertion and single-byte deletion operators, each with separate
counters in the summary.

The widened smoke campaign covers 3,768 valid wires (600 feature variants),
93,862 truncation cuts and 108,963 mutations. A `--deep` campaign covers
roughly 14,100 valid wires (about 9,300 feature variants), around 400,000
truncation cuts and around 375,000 mutations once the dictionary variants
are included; the Zstd-only deep campaign adds roughly 5,380 wires per
seed with the trained standard dictionary. Deep seeds 1-3 on the
dictionary-enabled generator, seeds 1-6 on the pre-dictionary generator
(roughly 77,000 valid wires, 2.2 million truncation cuts and 2 million
mutations), and the earlier legacy-generator seeds 1-13 all complete with
zero cross-decoder disagreements and no Vort/reference one-sided truncation
mismatches.

The extended generator immediately found a real interop defect: the
resumable raw Deflate decoder rejected legal literal-only dynamic blocks
with `InvalidDynamicBlockHeader`. A level-6 block with no distance symbols
still declares one distance code slot with length zero; zlib's `inftrees`
treats an all-zero LENS/DISTS alphabet as a deferred error marker rather
than rejecting the header, while Vort's `validDynamicAlphabet` required at
least one active symbol. The one-shot decoder accepted the same wires, so
the defect was invisible until the gzip concatenation variant drove the
streaming decoder. `validDynamicAlphabet` now accepts a zero-symbol
alphabet (the empty Huffman table fails only if a distance symbol is ever
actually decoded), matching zlib semantics; oversubscribed and incomplete
multi-symbol alphabets remain rejected. Focused raw and gzip streaming
regression tests pin the previously failing sizes.
