# Zstd source output alias regression

The pinned baseline `5425a37b0c36ce8b4193b8ea8d09dd638403d1ab` successfully
decodes the 18-byte `counterexample.zst` but publishes `abddef` instead of
`abcdef` when the destination is `history[1..7]`. Its two Raw blocks contain
`abc` and `def`, and the frame advertises a 1024-byte window. The second
history append overwrites output already published by the first block.
`before.log.gz` records the executed ReleaseSafe failure; the expected decoded
length still passes. A checksum cannot detect this overwrite because the
executor hashes independent staging bytes.

The installed libzstd 1.4.8 independently accepts the same frozen frame through
`ZSTD_decompress` and returns exactly six bytes, `abcdef`; `reference.json`
records the library, fixture hash and decoded bytes.

Reproduce against the archived revision without changing the working tree:

```sh
python3 docs/performance/zstd-source-output-alias-20261111/reproduce_before.py
```

`before_test.zig.fragment` is the exact test appended to that frozen source.
The reproducer preserves its temporary source and log for inspection.

The fix rejects destructive output aliases with `InvalidBlockPlan` before
payload execution or append growth. A cohesive alias module covers complete
workspace spans, borrowed dictionary storage/catalogs and caller descriptors.
Public frame/stream/cursor/append tests include unknown/declared sizes,
checksummed frames, unused destination tails, spare output capacity,
prepared dictionary state, no source callbacks or allocations on rejection,
and independent retries. Low-level frame tests cover 17 drain destinations
and verify complete memory/state/lease preservation followed by a
history-dependent compressed block and a valid checksum.

Reproduction gates:

```sh
zig build -j2 check-zstd-source-reverse -Doptimize=ReleaseSafe --summary all
zig build -j2 test-zstd -Doptimize=ReleaseFast --summary all
zig build -j2 check check-wasm --summary all
```

The source gate executes the same contract groups on native x86_64, Linux x86
and actual wasm32-wasi. `summary.json` binds exact source hashes, compiler,
counterexample and terminal gate results; its WASI receipt binds the executed
binary. This is functional regression evidence with no throughput or memory
leadership claim. Full competitor ratio/speed/lifecycle coverage remains open.
