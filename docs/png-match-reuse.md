# Adjacent reverse-match reuse

The existing dense-prefix jump backend reuses one exact match query from the
adjacent reverse position and the same distance. An equal first byte extends
its validated prefix. An uncapped result also proves the next mismatch; a
capped result is clipped or extended against the current maximum. The helper
is local to one immutable-input parse, with 32 bytes of logical state on the
64-bit host and no new heap owner.

`src/lz77/optimal/match_reuse.zig` owns the helper and byte-scalar tests for
all mismatch/tail/maximum transitions and overlapping queries. Complete
scalar DP controls and 144 frozen-parser cases preserve costs, compact
predecessors, decisions, tokens and non-clock search diagnostics. Logical
match-query counts include cache answers. Prefix order, candidate budgets and
complete ordinary/filtered arbitration remain intact.

The owning imx corpus retains all 120 level-1/6/8/9 Adaptive/Up PNGs and
allocator records exactly, with 720 independent complete image-png/libpng
original-pixel observations. LZ77 and selected DEFLATE pass 120/120 each,
focused optimal ReleaseFast passes 34/34, owning Debug scalar/DP controls
pass 4/4, and both imx bounded PNG modes pass 87/87. Baseline x86 and
big-endian PowerPC64 compile the matching controls.

The full 60-case, three-round process-CPU matrix gives
1.029631x geomean and 1.033077x aggregate
gain. Native throughput changes from 3.36 to
3.47 MiB/s versus image-png's 26.08 MiB/s.
The reference ratio is 0.133199x and the minimum is
0.983350x. Twelve measured cases remain below the baseline;
all are retained. This preserves compression output rather than establishing
format-wide performance leadership.

```sh
zig test src/lz77.zig -OReleaseFast
zig test src/deflate.zig -OReleaseFast --test-filter best --test-filter optimal --test-filter dictionary --test-filter numeric
zig test src/lz77.zig --test-filter 'optimal range minima' --test-filter 'reverse match'
```

Complete source/binary identities, samples and decoder roles remain in
[imx evidence](https://github.com/passchaos/imx/blob/main/docs/evidence/png-match-reuse.md).
The active objective still requires less DP/queue work, better actual wire-cost
models/block planning and broader complete functionality/performance evidence.

A five-round imx icon follow-up retains the measured regression: 0.981236x aggregate across all four cases. Activation/control costs and wider DP/queue efficiency remain open performance work.
