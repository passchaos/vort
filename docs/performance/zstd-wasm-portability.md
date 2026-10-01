# Zstd wide-Huffman WASM portability

The wide two-symbol Huffman decoder keeps a 64-byte-aligned, separately
sectioned native entry point, while wasm targets select an otherwise identical
wrapper without a function-alignment attribute. The shared decode body is
inlined into either wrapper, so the portable fix does not add a call to the
native hot path.

`zig build check-wasm` cross-compiles the complete Vort library plus both
out-of-line Brotli and Zstd optimized objects for `wasm32-wasi` without enabling
the WebAssembly threads/atomics proposal. `zig build test-zstd-huffman-x2`
separately covers the complete 14-bit paired lookup table and wide four-stream
decode oracle.

Native ReleaseFast evidence uses commit `683555ce` as the baseline, an
independent detached worktree, CPU 2, libzstd 1.5.5, and the built-in
`ascii64k` case for 5,000 iterations per process in A/B/B/A order. The two
baseline runs measured 1491.83 and 1502.74 MiB/s; the two candidate runs
measured 1497.86 and 1498.43 MiB/s. Candidate/baseline mean throughput is
1.0006x and every run produced checksum `655810000`. More strongly, dumping
the complete `.vort_zstd_huffman_wide_x2` section from the independent native
objects produced the same SHA-256 digest
`e822297f061435446d99f7e42e3242ca4511183c98e592f9efb790dc412fc7ea`,
which proves the native machine-code section did not change.
