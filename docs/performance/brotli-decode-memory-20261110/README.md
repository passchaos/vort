# Brotli decode memory functional gate, 2026-11-10

The independent `feat/brotli-decode-budget-20261110` worktree starts from
`28bbbe5159439b638a0cfdfe6ab4264786f3f92d`. This is a functional requested-heap
and alias-ownership milestone. It contains no timing, ratio, or performance
comparison claim. The public contract is documented in
[the format note](../../formats/brotli-decode-memory.md).

All gates in [summary.json](summary.json) completed with exit code zero on the
frozen source. The reference report's source hashes were checked against the
worktree after execution, with zero mismatches. The two public budget suites
run hundreds of matrix assertions inside the named tests; Zig runner totals
also include imported module roots.

| Gate | Result |
| --- | --- |
| Native Debug total-memory suite | 24/24 Zig tests |
| Native ReleaseFast combined public budget suites | 25/25 Zig tests |
| Actual x86-linux-musl ReleaseFast suites | 25/25 Zig tests |
| Executed wasm32-wasi ReleaseFast suites, 8 MiB stack | 25/25 Zig tests |
| Native ReleaseFast decode regression selection | 198/198 Zig tests |
| Native ReleaseFast counter regression selection | 89/89 Zig tests |
| libbrotli/Python Brotli forward fixtures | 108 frames, 216 native/ELF32 executions |
| Public API mode receipts | 4,320 rows, 4,752 measured D-1 quota refusals |
| Vort stored/RLE reverse fixtures | 7 wires, both references decode successfully |

The reference matrix uses system libbrotli 1.0.9 and Python Brotli 1.0.9,
qualities 0/5/11, generic/text/font, and empty/tiny/random/repetitive/source/run
payloads. Artifact hashes, loaded library hashes and paths, commands, source
identities, and actual WASI execution provenance are retained in the summary.
Full generated plain/frame/suffix fixtures and API receipts are archived in
`reference-receipts.tar.xz`, with checksums in `SHA256SUMS`. The matrix was
re-run after combining the Deflate commits and verified against every recorded
source hash. Re-run the checked-in driver to reproduce the working copies under
`zig-out/br-decode-memory-reference/`. Build binaries remain identified by hash.

The independent allocator forces moving growth and observes real requested
bytes. Measured peak D succeeds with and without instrumentation; D-1 refuses
before publication. The suites cover owned/full/prefix/exact/chunked decoding,
Large Window, RAW and parsed serialized dictionaries, OOM, zero-heap paths,
existing destination capacity, overlapping input in spare capacity, RAW
bytes/descriptors, serialized backing/view, direct legacy append, diagnostics,
output limits and prefix tails. A surviving shared owner explicitly opens each
new classification interval with `beginOperation`; zero-heap children preserve
its live profile and prior failure interval.

The first broad decode run occurred before the inherited-owner test's interval
was corrected and was superseded by the final 198/198 run. The first WASI run
found excessive test-stack lifetime overlap; separate `noinline` decoder cases
fixed it while preserving the existing 8 MiB stack. These were verification
corrections, and the final package identifies the current successful source.

This package covers the independent branch. Main integration, full library
`test/check/check-wasm`, rebase and push remain with the root agent. The broader
compression leadership objective remains active.
