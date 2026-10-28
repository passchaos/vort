# Lossless compact one-shot optimal decisions

Fixed-cost `optimalPlanAlloc` and its profiled variant now retain three bytes
per input position for reconstruction, compared with the six-byte public
`Token` union. A zero distance denotes a literal; nonzero u16 distances and
lengths 3..258 are stored exactly. The three-byte array avoids the four-byte
ABI size of a Zig u24. Public reusable scratch and caller-modeled storage keep
their existing full views. All views share the search and reconstruction code.

The returned token list uses `toOwnedSlice` rather than unconditional copying.
Allocators that can shrink the list transfer its existing allocation; other
allocators retain the standard fallible copy fallback. Error cleanup releases
both decision and token owners. Candidate order, budgets, costs, ties and
complete DEFLATE candidate arbitration are preserved.

Complete imx PNG checks cover 15 original rasters, Adaptive/Up and levels
1/6/8/9: 120 exact native PNG pairs and 720 independent image-png/libpng pixel
observations. Level-8/9 requested-heap peaks decrease on every case, with a
0.755731x geomean ratio. Level-1/6 bytes and allocation records are unchanged.
Exoplanet/Adaptive level 9 changes from 381,268,148 to 303,225,356 requested
bytes; separate Linux process RSS changes from 407,240,704 to 329,252,864 bytes.
All live requested heap returns to zero after destruction. Complete records
and reference identities are in
[the imx evidence](https://github.com/passchaos/imx/blob/main/docs/evidence/png-compact-decisions.md).

The public finite-allocator regression requires a 32-KiB all-literal result to
succeed within 768 KiB. Frozen Vort `5595901` returns `OutOfMemory` under the
same budget. A 128-KiB candidate budget fails normally. Exhaustive decisions
cover all 2^24 literal/length/distance representations; audited parser controls
compare every cost, decision and token across dense budgets, wrap boundaries
and wide input positions. Public profile diagnostics remain exact.

```sh
zig test src/lz77.zig -OReleaseFast
zig test src/deflate.zig -OReleaseFast --test-filter best --test-filter optimal --test-filter dictionary --test-filter numeric
zig test src/lz77.zig --test-filter 'preserve every cost choice' --test-filter 'dense budgets wrapping' --test-filter 'finite memory budget'
zig test -OReleaseFast --dep lz77 -Mroot=src/lz77/optimal/tests/profile_window.zig -OReleaseFast -Mlz77=src/lz77.zig --test-filter 'suffix profile'
zig test src/lz77.zig -target x86-linux -OReleaseFast -fno-emit-bin --test-filter 'optimal compact'
zig test src/lz77.zig -target powerpc64-linux -OReleaseFast -fno-emit-bin --test-filter 'optimal compact'
```

Full predecessor/rank arrays and the returned tokens still scale with input
length. This change establishes a measured memory improvement. The separate
60-case complete-encoder CPU matrix is running; throughput leadership and
whole-format compression/resource leadership remain open.
