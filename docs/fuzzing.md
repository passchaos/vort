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

The `tools/fuzz_corpus.zig` command is intentionally hex-sample based so corpus
reducers can feed minimized byte strings without inventing a file format.
`--store`, `--deflate`, `--zlib`, and `--gzip` switch the decoder used for
subsequent hex tokens. `--expect=accept|reject|any` (or the spelling variants
`--expect-accept`, `--expect-reject`, and `--expect-any`) sets a sticky expected
outcome for subsequent tokens; corpus files may use `# expect: accept` or
`# expect: reject` inline next to a sample. The harness fails on
`UnexpectedAccept` or `UnexpectedReject` when a regression changes a sample's
classification.
`tools/fuzz_target.zig` exposes `fuzzOne(allocator, data)` for raw-byte fuzz
runners and also has a smoke-test main. `tools/fuzz_libfuzzer.zig` exports `LLVMFuzzerTestOneInput` and is smoke-tested by `run-libfuzzer-smoke`. `tools/fuzz_afl.zig` is an AFL-style file-input driver suitable for `@@` invocations and is smoke-tested by `run-afl-smoke`. AFL/libFuzzer packaging should preserve crashing inputs as hex samples in regression tests.
The `ci-smoke` aggregate build step runs the deterministic fuzz entrypoints
alongside unit tests, compile checks, differential harnesses, and benchmark
smoke reports so local changes can use one command before commit.
The hosted GitHub Actions workflow in `.github/workflows/ci.yml` also reruns
the focused fuzz smoke entrypoints explicitly after `ci-smoke`, keeping the
local and hosted parser-validation surfaces aligned.
