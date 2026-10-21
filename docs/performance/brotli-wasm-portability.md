# Brotli wide-literal WASM portability

The wide external-literal executor keeps its 64-byte-aligned native entry point,
while WebAssembly selects an otherwise identical wrapper without a function-
alignment attribute. The complete decoder body is forced inline into either
wrapper, following the established Zstd wide-Huffman portability boundary.

Correctness evidence:

- `zig build check-wasm -j1` compiles the complete Vort library for baseline
  `wasm32-wasi`.
- zsvg's WOFF2 consumer compiles for `wasm32-wasi` and its import-free
  `wasm32-freestanding` browser ABI reconstructs a valid WOFF2, registers it as
  the only active font, and renders nonempty text.
- `zig build -j1 run-br-reference-bench-gate` passes all 13 rows against
  libbrotli 1.1.0 (`reference_version=1001000`).
- Both the clean `dc2aa36f` baseline and candidate full suites reach 1683/1684.
  Their identical only failure is the independent self-embedding `allocating
  summary follows ratio matches beyond fixed history` expectation; every
  wide-literal decode test passes.

Native ReleaseFast evidence uses baseline commit `dc2aa36f`, an independent
shared clone, CPU 8 on an Intel Core i9-13900K, and separately linked
`vort-br-reference-bench` executables. The two instantiated aligned executors
retain the same addresses and sizes in both binaries:

- address `0x1102940`, size `0x0a7e`;
- address `0x1104380`, size `0x10fb`.

Extracting only each function's instruction bytes with `objdump` produces the
same baseline/candidate SHA-256 digests:

- `545dd948f629ba2a7f609f47554649e49624ec3485ad0c8ed156941f0918faa7`;
- `2a4113d171262ce44579a8c9631bf8bb66759073ef86cc2e18279b06b51ea567`.

This proves the native hot functions are byte-identical; a timing-only A/B
cannot provide stronger no-regression evidence for this target split.
