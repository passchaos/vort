# Completed codec contract gates — 2026-11-27

This package preserves the functional gate for the Deflate persistent-stream resource contracts and Zstd fallback planning increment, not a throughput or memory comparison. The measured test source is the frozen 2,267-file registry `beb79f99ed3809717dee3d3a3438247f835c45f012bfbb3aeab6cab6e6b0955f`. The engineering baseline is Git `d5d9d8aa`; the final candidate is identified by its frozen source registry, not by a Git tag or the live worktree.

| Original execution | Actual exit | Retained terminal summary |
| --- | ---: | --- |
| Initial whole-library ReleaseSafe `test check check-wasm` | **1** | 417/419 steps succeeded; 6107/6110 tests passed, two skipped and one failed |
| Final whole-library ReleaseSafe `test check check-wasm` | **0** | **419/419 steps succeeded; 6108/6110 tests passed, two skipped** |
| Focused native Deflate clone gate | **0** | 9/9 steps; 104/104 tests passed |
| Focused Deflate clone actual WASI gate | **0** | 9/9 steps; Node ran the codec and public wasm test artifacts |

Each [`evidence/`](evidence/) gate directory contains the original receipt, stdout (including empty stdout), stderr, and before/after selected-source manifests **byte for byte**. The complete logs retain the first failure and diagnostic `failed command` text; the recorded exit and terminal summary are authoritative. The original commands and paths are provenance, not verifier dependencies.

## Clone error-set correction

The initial `Deflate clone safe copy contracts` failure was an assertion that every encoder clone's error set was exactly `Allocator.Error`. Raw Stored still uses exactly that set. The six Raw/Zlib/Gzip Fixed and Best public encoder types use exactly `OutOfMemory`, `IntegerOverflow`, `InvalidBlockPlan`, and `WorkingMemoryLimitExceeded`; the actual wrapper declarations forward the raw encoder's clone errors. Physical failing-allocator tests still require `OutOfMemory`.

The full registry before the correction is `336ed33932ffcbf49d666eefe13fd926d72f29207002cfe4c423e38504de8813`. Its comparison with the final registry has **one changed file**, `src/tests/deflate_clone/encoder.zig`, and no added or removed files. The old test SHA is `d43945449094e52abe436afeae3371fa172ad73e2dfdf67fed9269f65796432b`; the final test SHA is `28bbb4e85e5f6a51fa59a1fd74618a5e37d760169ea645c381e4e94c58719f2b`. The final whole, Native and actual WASI receipts all select that final test SHA. The original test and [test-only patch](source/clone-types-only.diff) are retained; no failed gate is relabeled successful.

## Offline verification

```sh
python3 -B /path/to/codec-contracts-20261127/verify.py
```

The standard-library verifier works from a copied package without the original checkout or `/tmp` directories. It checks `SHA256SUMS`, gate receipts and their terminal summaries, both frozen registries, the exact test-only diff, and each source member's SHA. It streams [`source-overlay.tar.gz`](source-overlay.tar.gz) without extraction. The overlay contains all 2,267 registered `src`, `build`, `build.zig` and `build.zig.zon` files from the frozen snapshot. Source bytes are unchanged; tar metadata is normalized. It contains no caches, generated executables or dependencies outside that registered closure. The verifier does not launch Zig, Node, any codec or a performance measurement. See [`capture.json`](capture.json) and [`verification-receipt.json`](verification-receipt.json) for capture and actual offline checks, including relocation and corruption/rejection controls.

**Out of scope:** the separate 540-wire formal preflight, any ongoing benchmark or resource measurement, deployment/merge acceptance, and industry rankings. None is included or promoted to passed by this package.
