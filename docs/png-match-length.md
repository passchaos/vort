# Bounded short-match entry

The shared LZ77 match-length kernel first compares an eight-byte little-endian
word. A mismatch returns its exact first byte immediately; an equal word starts
the existing 32-byte vector loop after that validated prefix. Word and scalar
tails retain the caller's exact maximum and never require padded input.

`src/lz77/match/length.zig` owns this small kernel and its scalar controls.
Aligned/unaligned beginnings, every mismatch through 321 bytes, 7/8/9 and
31/32/39/40 boundaries, maximum tails and overlapping distances 1..32 retain
the original first-mismatch result. The existing full scalar-DP comparisons
continue to verify optimal costs, decisions, tokens and candidate budgets.

The imx level-1/6/8/9 Adaptive/Up matrix retains all 120 complete PNG buffers
and allocator records exactly. Baseline, candidate and Rust output receive
720 independent image-png/libpng complete original-pixel observations.
ReleaseFast LZ77 passes 118 tests and selected DEFLATE passes 118. Focused
optimal/match ReleaseFast passes 37; the owning kernel passes its Debug
comparison. Both imx bounded PNG modes pass 87 tests, and baseline x86/PowerPC64
compile the bounded match controls.

Five level-9 complete-encoder pilots retain the output sizes and improve
1.012419x..1.045782x. Final full-corpus timing, source/executable identities and
remaining throughput deficits are retained in the owning imx evidence.

```sh
zig test src/lz77.zig -OReleaseFast
zig test src/deflate.zig -OReleaseFast --test-filter best --test-filter optimal --test-filter dictionary --test-filter numeric
zig test src/lz77/match/length.zig
```

This removes avoidable work for short matches while preserving the same parse
and compression ratio. Full numeric-level throughput leadership still requires
less matching/DP work and stronger real-wire cost modeling. Complete PNG size
and resources remain separate from process RSS and total stack usage.

Final imx timing covers sixty original-raster level-8/9 cases, with
1.036960x geomean and 1.030889x aggregate throughput,
minimum 1.009469x. Current aggregate speed remains
0.128956x image-png. Every complete native PNG byte and
allocator record remains exact.
