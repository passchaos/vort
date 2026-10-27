# Exact sparse-anchor jumps in fixed-cost optimal parsing

The fixed-cost compact optimal parser can skip candidates that cannot extend a
match already covered by a closer distance. It selects the existing three-byte
index chain whose newest predecessor is farthest away within the covered
prefix. Candidates from that suffix are translated back to their original
positions; exact original-prefix checks reject hash collisions.

Two u16 ordinal arrays count original hash-chain nodes and valid three-byte
prefix candidates. Their differences preserve both configured budgets through
skipped nodes. All comparisons stay within a32768-byte physical window, making
ordinal wrap unambiguous. No new large hash index is introduced. Original
closest-distance, strict cost improvement and longest-length ties are retained.
Caller-supplied modeled costs and noncompact indices keep their generic path.

A deterministic256-position density sample avoids repeated row/channel offsets.
Only inputs>=1024bytes with>=75% near exact prefixes, minimum3, chain>=16 and
candidate budget>=8 enable jumps. The normal and jump backends compile
separately. Sparse/photo blocks retain their previous allocator behavior;
dense blocks own two exact-capacity arrays totalling4bytes per source byte.
Owners release all failures and retain capacity on independent reuse.

The owning modules live under src/lz77/optimal/: prefix_jumps.zig provides
ordinals/density selection, rarest_anchor.zig selects the existing chain, and
candidate_cursor.zig owns budget-preserving traversal. Tests live beside them.
All scalar DP costs, steps and reconstructed tokens match across both budget
boundaries, active/fallback inputs and positions beyond65536. Index oracles
check full-window rank differences and cycles; every allocation failure is
traversed. All107 LZ77 ReleaseFast tests and23 selected DEFLATE tests pass;
22 optimized Debug controls and both87-test PNG modes pass. Baseline x86_64
and big-endian PowerPC compile the same controls.

Ninety original-corpus complete PNGs at levels1/6/9 and Adaptive/Up remain
byte-identical to the d5eb7f7 baseline. Image-png and libpng reproduce every
original pixel in180 fresh complete decodes. Twelve dense level-9 cases add
the two index allocations and exact4n request bytes; all destroy counters
return to zero. The largest extra request in this corpus is99,541,440bytes.

Thirty-six alternating complete-encoder CPU cases give a level-9
geomean/aggregate gain of1.391382x/1.425020x against d5eb7f7. Every selected
level-9 case improves; weak low-level controls remain visible. Selected
reference throughput is still0.192976x at level9. The full ninety-case reference
comparison remains a separate gate; no overall PNG/compression leadership is
claimed. Resource evidence covers requested heap, not process RSS.

Failed global lower-bound, fixed8-byte-prefix and suffix-only experiments are
excluded from production. Their scalar tests passed but complete-operation
pilot timings regressed; the imx evidence retains those source and timing
records to explain the chosen index and resource tradeoff.

```sh
zig test src/lz77.zig -O ReleaseFast
zig test src/lz77.zig -O Debug --test-filter optimal
zig test src/deflate.zig -O ReleaseFast --test-filter level --test-filter 'fixed bit planning'
```

Full frozen binaries, PNGs, causal/reference timings and resource records are
retained by imx under /nav_env/Temp/imx-png-pruning/. Further parsing/block
selection, ratio/resource frontiers, PNG decoding and JXL coverage remain open.
