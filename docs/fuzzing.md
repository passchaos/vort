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
