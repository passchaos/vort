# Bounded suffix costs for one-shot optimal parsing

The fixed-cost one-shot optimal planner keeps its suffix costs in 512 native
integer slots instead of allocating one slot per input position. Its longest
DP edge is 258 bytes, so reverse traversal can reuse old slots after they leave
the live suffix range. Masked indexing avoids a non-power-of-two remainder.

`src/lz77/optimal/suffix_costs.zig` owns full, circular and audited cost views.
The existing scalar and optimized kernels share the same cost access, candidate
search and length minima. The public reusable scratch APIs continue to expose
their complete costs and decisions, and caller-modeled one-shot behavior stays
on its existing full owner. Normal and profiled fixed-cost one-shot allocation
use the circular view. Token ownership and reconstruction remain unchanged.

The audited view records every position before its circular slot is reused.
Tests compare every cost, decision and token against the complete scalar DP,
including empty inputs, 258/259 and 511/512/513 boundaries, repeated wrapping,
minimum/maximum match lengths, dense budgets and positions beyond 65536. Custom
modeled costs are independently compared through the shared view. Every failed
one-shot owner is released. Checked cost-extent addition also covers 32-bit
nonpacked controls.

ReleaseFast LZ77 passes 117 tests; selected DEFLATE
best/optimal/dictionary/numeric gates pass 118. The focused suffix Debug gate
passes seven. A standalone public profiling test compares reusable/full and
one-shot/circular tokens and all search diagnostics, excluding clock samples.
32-bit baseline x86 and big-endian baseline PowerPC64 compile the suffix gates.

The owning imx complete matrix has 120 original-raster cases at levels 1/6/8/9
with Adaptive/Up filters. All native PNG bytes remain identical to `588ef81`,
with 720 image-png/libpng complete original-pixel observations across baseline,
candidate and Rust output. Levels 1/6 retain every allocator record. Levels 8/9
reduce peak requested heap by 31.21% geomean, and every measured native heap
returns to zero. Exoplanet/Adaptive changes from 583,733,830 to 384,650,942 bytes
with the same 1,093,130-byte level-9 PNG.

The circular object's values occupy 4 KiB on the 64-bit host, plus two native
integer fields. It has no heap owner. The full decision and predecessor/rank
arrays still grow with the input. Requested heap, object size and process RSS
are distinct measurements.

```sh
zig test src/lz77.zig -OReleaseFast
zig test src/deflate.zig -OReleaseFast --test-filter best --test-filter optimal --test-filter dictionary --test-filter numeric
zig test src/lz77.zig --test-filter 'optimal suffix'
zig test -OReleaseFast --dep lz77 -Mroot=src/lz77/optimal/tests/profile_window.zig -OReleaseFast -Mlz77=src/lz77.zig --test-filter 'suffix profile'
```

The imx evidence retains complete sizes, per-case allocator records, independent
observers, source/executable hashes and paired CPU measurements. Numeric-level
throughput leadership, smaller decisions/indices, broader ratio/decode frontiers
and full-library functionality/performance remain under the active goal.
