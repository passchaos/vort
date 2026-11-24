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

The [2026-11-20 current-source campaign](performance/codec-functional-differential-current-20261120.md)
records the latest deep-run results after encoder lifecycle admission. Its
14,684 valid-stream checks and 498,324 mutations retain explicit external
reference versus Vort-only scope; the historical reporting counters now have
classified observations and representative adjudication.

The [classified reporting tool](performance/codec-differential-reporting-20261120.md)
now separates actual external references, Vort-only contracts and mutation
acceptance directions, with bounded complete-output captures and replay.
Representative triage exposed malformed Deflate distance-tree acceptance;
the [dynamic admission fix](performance/deflate-dynamic-admission-20261120.md)
removes eight raw and two gzip observations at unchanged generated-wire and
mutation-sequence digests in the current seed.

A later [bounded three-format screen](performance/codec-functional-differential-20261124.md)
records reference parity for generated valid wires and the regression for
incremental zlib completion with an allowed tail and a short output pledge.
Its Brotli follow-up uses `--brotli-reference-floor=BYTES` to distinguish
reference destination limits from acceptance differences without changing
the generated cases. This summary-only option accepts 4,096 through 1 MiB
(before the one-byte slack), applies only to Brotli, and cannot be combined
with artifact capture or replay. Omit it to use the historical capacity.
`--brotli-reference-exact-input` selects the streaming reference for ordinary
Brotli too and rejects otherwise successful decodes if input remains. Its
summary counts those unconsumed tails; it can be combined with the capacity
floor but not capture or replay. Without it, ordinary Brotli retains the
historical one-shot reference policy. `--zlib-reference-exact-input` requires
complete input for single-stream raw Deflate, zlib and gzip reference calls.
It reports successful prefixes refused for leaving a tail, leaves the
already-strict multi-member gzip reference unchanged, and is also summary-only.

`tools/codec_differential_fuzz.zig` (`run-codec-differential-fuzz`)
complements the raw-byte target with generated valid wires. A deterministic
SplitMix64 generator feeds eight content patterns (RLE, periodic, random,
text-like, mixed runs and sparse binary) across boundary sizes from 0 bytes
through 8 KiB (`--deep` extends the schedule to 64 KiB) into:

- raw Deflate levels 0/1/6/9, zlib levels 0/6/9 and gzip levels 0/6/9 (level
  0 exercises the stored-block encoder explicitly);
- standard Zstd frames at levels 1/3/9;
- RFC Brotli qualities 0/5/11 (q11 only for inputs up to 1 KiB in smoke).

For a valid-wire-only incremental campaign, pass `--incremental-valid-only`:

```sh
LD_LIBRARY_PATH="$HOME/Work/brotli/build-vort:$HOME/Work/zstd/lib" \
  zig build -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --deep --incremental-valid-only --brotli-reference-exact-input --zlib-reference-exact-input
```

The flag preserves the ordinary one-shot, exact-size and applicable reference
checks, then drives the same wire through two incremental schedules. The
unpledged schedule uses one-byte input on small wires and bounded fragments on
long wires. The second applies an exact output pledge with a different chunk
schedule. Zstd also exercises its block-stream and prevalidated-frame input
policies respectively. In both schedules, every step checks progress bounds,
exact plaintext as it is published, and output canaries. EOF requires complete
wire consumption, a successful `finish`, and the exact plaintext length. Deep
runs include dictionary, concatenation, and format variants; the existing
classification report still distinguishes external checks from Vort-only
contracts. `incremental_valid_json` reports passes, failures, and successful
step calls by codec. This mode skips truncation and mutation and cannot be used
with divergence capture or replay; default runs are unchanged.

For independent real-file streams, repeat `--real-file=PATH`. This replaces
synthetic generation, reads whole files (never silent prefixes), and applies an
8 MiB per-file default cap. `--real-limit=BYTES` changes the cap up to 64 MiB.
Libz, libzstd and libbrotli encode with explicit flushes at 64 KiB intervals.
Each complete wire must round-trip and finish through both incremental schedules,
including periodic empty output buffers. The same schedules then replay the
final-byte cut: the reference must reject it, and Vort must report truncation
while every published byte still matches the original plaintext. For this
single-frame case, prevalidated Zstd must withhold all bytes until validation;
the other routes must publish at least the prefix before the last 64 KiB.
The report separates
full and cut cases and binds file/wire hashes, reference versions and settings.

```sh
zig build -Doptimize=ReleaseFast run-codec-real-stream-smoke
corpus="$HOME/Work/corpora/silesia-20261025/files"
LD_LIBRARY_PATH="$HOME/Work/brotli/build-vort:$HOME/Work/zstd/lib" \
  zig build -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --real-file="$corpus/xml" --real-file="$corpus/ooffice"
```

The README smoke is also part of `ci-smoke`; the full Silesia sweep is opt-in
and is functionality evidence, not a timing result. The
[full-file receipt](performance/codec-upstream-real-20261124.md) records the
Brotli boundary defect found and the reference versions and corpus hashes.

`--real-brotli-wide` selects only Brotli and uses libbrotli's one-shot
quality-6, `lgwin=22` standard encoder, without forced flushes. A declared wide
window is not enough: the Vort summary must find an actual backward copy past
65,520 bytes in each wire. The mode checks both incremental schedules, strict
and prefix caller-history preflight with contiguous and joined chunk input,
plus direct validation and replay over 257-byte pieces without a compressed
join buffer. All preflight routes use zero requested codec heap. A one-byte-short
logical limit, final-byte truncation, and trailing bytes must fail strict preflight
without writing to caller output. Tail replay still checks the emitted prefix
byte-for-byte; unlike the flushed mode, it does not assume the last 64 KiB is
the only unpublished data.
`upstream_brotli_preflight_json` records the observed window, maximum distance,
legacy fixed-history outcome, and requested heap.

```sh
# Deterministic long-copy input, no corpus download (included in ci-smoke).
zig build run-codec-brotli-wide-smoke
# Optional real file, with the same size limit as --real-file.
LD_LIBRARY_PATH="$HOME/Work/brotli/build-vort" \
  zig build -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --real-brotli-wide --real-file="$corpus/xml"
```

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
  and interspersed positions. These variants use a `ZSTD_decompressStream`
  reference to inspect frame completion explicitly. Its completion rule is
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
- deep-only Brotli serialized shared-dictionary frames built through
  `serializeSharedDictionaryAlloc` with a custom static word list and an
  explicit dictionary choice. The variant encodes through the legacy planned
  level path where the serialized matcher is wired; the RFC built-in static
  dictionary stays available without the custom attachment, so the contract
  is the attached-dictionary round trip plus truncation prefix identity,
  with mutation length and content changes recorded as one-sided divergences;
- deep-only Vort-native magicless Zstd frames with the standard magic
  omitted. libzstd rejects them as unknown frame descriptors, so they run as
  a Vort-to-Vort contract: magicless decode through the formatted options
  API must reproduce the source, standard-format decode must reject the wire
  with `InvalidMagic`, and truncation/mutation use the same prefix and
  length rules as the other Vort-only variants;
- deep campaigns add eight RNG-driven random sizes per pattern alongside the
  fixed boundary schedule.

The mutation matrix keeps five-position XOR flips for every wire, adds
single-bit flips at the same sampled positions, and for wires up to 2 KiB
runs fixed-position overwrite (0x00/0xff/random), adjacent two-byte
overwrite with a deduplicated in-bounds start schedule, single
random-byte insertion and single-byte deletion operators, each with
separate counters in the summary. The two-byte schedule rejects starts
whose pair would run past the wire end, so short wires stay safe.

The widened smoke campaign covers 3,768 valid wires (600 feature variants),
93,862 truncation cuts and 108,963 mutations. A `--deep` campaign covers
roughly 14,100 valid wires (about 9,300 feature variants), around 400,000
truncation cuts and around 375,000 mutations once the dictionary variants
are included; the Zstd-only deep campaign adds roughly 5,690 wires per
seed once the magicless variant joins the trained standard dictionary.
Deep seeds 1-3 on the dictionary-and-magicless generator, seeds 1-3 on the
pre-magicless dictionary generator, seeds 1-6 on the pre-dictionary
generator (roughly 77,000 valid wires, 2.2 million truncation cuts and 2
million mutations), and the earlier legacy-generator seeds 1-13 all
complete with zero cross-decoder disagreements and no Vort/reference
one-sided truncation mismatches.

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

## 2026-11-15: bounded incremental Zstd decoder fuzz driver

`src/zstd/incremental/fuzz_driver.zig` adds a deterministic driver that
mutates both the wire and the caller-driven step schedule, which the
one-shot raw-byte target cannot reach. `zstd.incremental_fuzz.drive(allocator,
seed)` derives, per seed: a generated frame (both frame formats, raw/RLE and
literal-only selections, optional checksum and content size, six payload
shapes including multi-block), a mutation regime (valid, one-sided truncation,
single-byte flip, or appended suffix), both compressed-input policies, an
optional exact/short output pledge, a finite working-memory and compressed
buffer cap, and independent input/output slice schedules.

Every step is checked for the same invariants the hand-written decoder tests
rely on: local progress never exceeds the offered slices, the cumulative
snapshot advances by exactly the reported progress, output beyond
`output_written` keeps its canary fill, and live/peak working memory plus
retained compressed capacity stay within budget. Rejections must be
documented decode errors (never real `OutOfMemory`), are sticky across further
calls, carry diagnostics, and reproduce after `reset`; accepted runs are
replayed under a different schedule to prove schedule independence and, when
the one-shot decoder also accepts the bytes, must match its output. Truncated
wires and uncompleted suffix members terminate as an explicit `incomplete`
result rather than a stall.

The same entry backs the in-graph tests (`zig build test-zstd`, including the
48-seed fixed matrix, determinism and suffix-retention cases, with testing
allocator leak detection) and a standalone ReleaseFast runner:

```sh
zig build run-zstd-incremental-fuzz-smoke
```

The runner is also compiled by the `check` graph. Its seed mix currently
reports roughly balanced accepted/rejected/incomplete outcomes; a violated
invariant exits non-zero. The structure is codec-agnostic and is reused for
the Brotli and Deflate incremental decoders below.

## 2026-11-15: bounded incremental Brotli decoder fuzz driver

`src/br/incremental/fuzz_driver.zig` ports the Zstd `drive` contract to the
owned incremental Brotli decoder (`br.IncrementalStreamDecoder`) behind the
same seed-driven, codec-agnostic shape. Each seed selects a generated wire
(either `encodePlannedStreamAlloc` for inputs of at least five bytes, or an
RFC stored stream that also covers empty and tiny payloads), a mutation regime
(valid, truncation, single-byte flip, appended suffix), an optional
exact/short output pledge, finite working-memory and compressed-input caps,
and independent input/output slice schedules.

Brotli-specific contract differences are modeled explicitly: there is no
frame-format or compressed-input-policy dimension, and a completed stream
rejects further bytes with `TrailingData` unless `allow_trailing_data` is
set. The suffix regime therefore always enables trailing tolerance so frame
completion timing cannot make the result depend on the chunk schedule; a
dedicated test pins both the sticky `TrailingData` rejection and the tolerant
path. As with Zstd, every step checks progress accounting, canary
preservation, resource caps, sticky documented errors that clear on `reset`,
schedule independence, and one-shot (`decodeStreamAlloc`) differential
agreement, while truncated wires end as an explicit incomplete result.

The same entry backs in-graph tests (`zig build test-br`, including the
48-seed matrix, determinism and trailing-data cases, with leak detection) and
a standalone ReleaseFast runner:

```sh
zig build run-br-incremental-fuzz-smoke
```

The runner is compiled by the `check` graph and exits non-zero on any violated
invariant.

## 2026-11-15: bounded incremental Deflate decoder fuzz driver

`src/deflate/incremental/fuzz_driver.zig` completes the three-codec family by
porting the `drive` contract to the zlib and gzip incremental decoders
(`deflate.ZlibIncrementalDecoder` / `deflate.GzipIncrementalDecoder`). Deflate
differs from the other two codecs in that its incremental decoders are built
over a caller-owned 32 KiB history slice (the RFC 1951 maximum window) instead
of an allocator, and their error set is the closed `deflate.Error` (core
errors), so the hot path never allocates and every non-success result is a
documented rejection.

Each seed selects a wrapper (zlib/gzip), a wire kind (stored/fixed/best), a
mutation regime (valid, truncation, single-byte flip, appended suffix), an
optional exact/short output pledge, and independent input/output slice
schedules. A type-erased `Handle` drives either generic through the shared
schedule. Every step checks progress accounting against the snapshot, canary
preservation, schedule independence (a second run under different chunks), and
one-shot differential agreement against `decodeZlibAlloc`/`decodeGzipAlloc`;
truncated wires end as an explicit incomplete result. The wrapper-specific
trailing-data rule is modeled as in Brotli: the suffix regime always enables
`allow_trailing_data` so completion timing cannot make `TrailingData`
schedule-dependent, while dedicated tests pin both the sticky rejection path
(including reset clearing `last_error_name`) and the tolerant path, plus the
short-pledge `SizeMismatch` contract.

The same entry backs in-graph tests (a 48-seed matrix, determinism,
trailing-data and short-pledge cases; allocator-backed temporary storage
still gets testing-allocator leak detection) and a standalone ReleaseFast
runner:

```sh
zig build run-deflate-incremental-fuzz-smoke
```

The runner is compiled by the `check` graph and exits non-zero on any violated
invariant. All three primary codecs (Zstd, Brotli, Deflate) now share the same
bounded incremental schedule/canary fuzz shape.

## 2026-11-15: coverage-guided entry for the incremental drivers

`tools/incremental_fuzz_libfuzzer.zig` exports
`LLVMFuzzerTestOneInput` over the three incremental `drive` functions. Because
each driver derives its wire mutation and step schedule from an opaque seed,
feeding arbitrary fuzzer bytes to this entry explores the full
schedule/canary/resource/sticky-error state space beyond the fixed 48-seed
matrices; the raw-byte `fuzz_target` harness still covers only one-shot
decoding. Any violated driver invariant or real allocation failure returns
non-zero so the engine preserves the crashing input. A debug `main` provides a
no-runtime smoke:

```sh
zig build run-incremental-libfuzzer-smoke
```

The executable is also compiled by the `check` graph. For an actual
coverage-guided campaign, rebuild the same entry with the toolchain's
libFuzzer instrumentation and point it at a seed corpus of arbitrary bytes.

## 2026-11-16: broad deterministic sweeps harden the drivers

Each codec driver now also runs a 256-seed deterministic sweep (a wider
derivation than the 48-entry fixed matrix) inside its in-graph tests, catching
schedule-dependent edge cases the matrix missed. The sweeps surfaced and fixed
three real driver-assumption gaps rather than decoder defects:

- Zstd: on a non-stopping decoder, an appended suffix is a real concatenated
  member attempt, so a different chunking may legitimately parse deeper into
  the random suffix and reject it. Schedule-independent output is now asserted
  only for frame-bounded regimes (or a suffix with `stop_after_first_frame`).
- Brotli: streams have no magic and end at an internal meta-block stop marker,
  so a flipped byte or suffix can end the stream before the whole view is
  consumed; the identical-output replay is now required only for the clean
  `valid` regime.
- Deflate: damaged wrapper streams can expand past the plaintext length. The
  decoder now always gets a finite `max_output_len`, the caller capture buffer
  carries extra headroom so wrapper header/footer finalization never runs out
  of output room, and over-expansion becomes a documented
  `OutputLimitExceeded` rejection instead of a driver buffer overrun.

## 2026-11-16: valid multi-member concatenation coverage

Each driver gains a dedicated deterministic test that round-trips two valid
members under one-byte input scheduling, complementing the random suffix
regime (which feeds random trailing bytes) with an all-valid concatenated
stream. The three codecs model member transitions differently and the tests
pin each contract:

- Zstd: a non-stopping decoder walks from the first frame straight into the
  next (`data_frame_count == 2`), with mixed literal-only and raw/RLE members.
- Deflate: both zlib and gzip wrappers use `allow_concatenated = true`; the
  test checks the cumulative output and the wrapper-specific member count
  (`stream_count` for zlib, `member_count` for gzip).
- Brotli: members are armed explicitly through `nextFrame`, which is only
  valid once the prior member reaches `done`; the test verifies the
  per-member output slices and `frame_count == 2`.

## 2026-11-16: dictionary round-trip coverage

Each driver also gains a deterministic preset-dictionary round-trip under
one-byte scheduling, pinning the codec-specific dictionary attachment path:

- Zstd: a raw-content `NativeDictionary` passed to
  `encodeNativeFrameWithDictionaryAlloc` and `initWithDictionary`.
- Deflate: a zlib stream built with
  `encodeZlibFixedWithDictionaryAlloc` and decoded through
  `ZlibIncrementalDecoder.initWithDictionary` over caller-owned history.
- Brotli: a multi-prefix `SharedDictionary` supplied via
  `DecodeOptions.shared_dictionary` (encoding through
  `encodePlannedStreamWithOptionsAlloc`).

The negative "missing dictionary rejects dictionary references" contract is
already covered by dedicated hard-coded-frame tests outside the fuzz drivers;
the drivers focus on the positive attached-dictionary round-trip because a
general encoder is free to emit literals instead of references.

## Public API / error coverage audit (2026-11-16)

A systematic gap scan accompanied the incremental fuzz work and closed several
zero-test public surfaces: the Zstd `decodeFrameChunks*` family (alloc/into,
exact/limited, scratch, size preflight, dictionary) and the Deflate gzip/zlib
size-preflight entry points including concatenated streams. Brotli's
chunks/prefix APIs were already covered under `src/br/decode/tests/`.

Reusable audit method:

- Low-reference scan: list `pub fn decode*`/`decoded*` symbols whose total
  in-file reference count is ~1 (definition only), then cross-check the whole
  `src/<codec>/` tree because tests often live in separate modules or behind
  root re-exports (thin wrappers and method-style APIs produce false positives).
- Error coverage: diff the errors actually `return`ed in the codec source
  against the `error.X` names asserted in tests. Exclude cross-codec errors in
  the shared `core.Error` set that the codec never produces, internal sentinels
  remapped before they reach callers (e.g. Zstd `EndOfStream` ->
  `TruncatedFrame`), and errors already asserted in the codec root test block.

Result after the added tests: no remaining produced-but-untested error and no
zero-test non-wrapper decode API was found across Zstd, Brotli, or Deflate.

## Encoder-side coverage follow-up (2026-11-16)

Applying the same low-reference scan to encode entry points found and closed
two zero-test independent contracts:

- `encodedNativeFrameBound` must upper-bound the real encoded length across
  empty/tiny/random/repeated inputs and checksum options;
- `encodeNativeFrameIntoSlice` must produce a byte-identical frame in a caller
  buffer and reject an undersized buffer with `OutputTooSmall`.

The other ref=1 encode names are not gaps on inspection: `encodeFrameAppend`
is the same core as the tested IntoSlice/Alloc paths; literal-only encoding has
deep block-mode/decode-interaction coverage in `limits_tests.zig` plus error
paths in `controls_resource_tests.zig`; seek-table encoding is covered by the
HQ/controls test modules; and the `With*` names are thin option wrappers over
tested cores. No remaining untested non-wrapper encode or decode entry point was
found across the three codecs.

## Other container formats coverage check (2026-11-16)

Beyond the three primary codecs, the coverage-guided entry point
(`tools/fuzz_target.zig`) already routes 46 encode/decode entry points spanning
the container and secondary formats (lz4, lz4-legacy, cab, chd, cso, dax,
decmpfs, the Windows LZ* family, android OTA, and more).

lz4 was checked specifically as a high-exposure format: it has no separate
incremental fuzz driver, but its one-shot path is in the coverage fuzzer and its
incremental state machine already has 75 dedicated tests across
`decoder_tests`, `dictionary_resume_tests`, `limits_tests`, and `tests`,
covering step scheduling, resume, and resource limits. A parallel driver would
therefore duplicate existing coverage rather than close a gap. The same pattern
holds for the other wired formats: no zero-test non-wrapper entry point was
found that would justify a new driver. New drivers should only be added where a
format has an uncovered incremental scheduling state machine, not merely because
it is absent from this driver's file list.

## Incremental encoder memory borrows (2026-11-20)

The scheduling fuzz above uses independent input and output storage. Its API
and error inventory does not establish safety for overlapping memory. A later
source audit found that Deflate, Brotli and Zstd incremental encoders could
publish a header or pending bytes before reading new input in the same call.
Overlapping buffers could therefore replace unread plaintext.

Dedicated public regressions now exercise those memory layouts, including
receiver and retained-capacity overlap, dictionaries and metadata, pending
drains, refusal without state or output changes, and successful disjoint retry.
They run through `check-incremental-encode-borrows` on native, Linux x86 and
actual WASI; the parallel Zstd path uses synchronous fallback on WASI.
See the [buffer contract](formats/incremental-encode-borrows.md) and
[before/after evidence](performance/incremental-encode-borrows-20261120.md).
