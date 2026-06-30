# Fuzzing plan

Current deterministic fuzz entrypoints:

```sh
zig build run-fuzz-smoke
zig build run-fuzz-corpus
zig build run-fuzz-corpus -- <hex-sample> [...]
```

Coverage-guided fuzzing should target these parser surfaces first:

1. native VORT store headers and skippable frames;
2. serialized frame indexes;
3. raw deflate block headers and stored/fixed/dynamic block transitions;
4. zlib/gzip wrappers and optional gzip headers.

The `tools/fuzz_corpus.zig` command is intentionally hex-sample based so corpus
reducers can feed minimized byte strings without inventing a file format. A
future libFuzzer/AFL integration should call the same parser functions used by
this tool and preserve crashing inputs as hex samples in regression tests.
