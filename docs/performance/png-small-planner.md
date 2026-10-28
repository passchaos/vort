# Complete-index planner isolation

One-shot fixed-cost input at least 64 KiB that retains a complete compact
index now executes its reverse planner in a separate function frame. Inputs
below that size keep the inline path; the existing larger bounded-window path
returns before this dispatch. All variants call the same planner, retaining
candidate order, costs, decisions, allocation sequence and output ownership.
The new 65,539-byte profile control compares final tokens and all non-clock
search diagnostics with the reusable full-reference path.

The 128-pixel rsvg PNG icon's previously measured 0.94x regression is recovered
by nine-round complete-encode CPU controls. Adaptive/Up at levels 8/9 gives
1.068542x throughput geomean versus the published window-index executable.
Four separate direct pre-window controls give 1.003749x..1.007703x.
The same paired matrix keeps measured 16-pixel and 32-pixel costs visible:
0.992291x/0.985025x geomean, with minimum 0.978534x. Eight large-window
controls give 0.995456x geomean, minimum 0.990878x. These are focused controls,
not a whole-corpus speedup claim. Tiny/large code-generation overhead remains
an active performance target.

All 120 complete candidate PNG buffers and requested-heap allocator records
match the frozen window-index baseline. The baseline has the earlier
independent image-png/libpng full-pixel observations; reuse follows exact
native byte equality. All live requested heap returns to zero. ReleaseFast
LZ77/selected DEFLATE pass 129 each, owning bounded PNG passes 87 and both
window/mid-size public profile controls pass. Builds use one job with a
4-GiB address-space ceiling; runtime controls use a 1-GiB ceiling and report
successful exits with zero swaps.

```sh
zig test src/lz77.zig -OReleaseFast
zig test src/deflate.zig -OReleaseFast --test-filter best --test-filter optimal --test-filter dictionary --test-filter numeric
zig test -OReleaseFast --dep lz77 -Mroot=src/lz77/optimal/tests/mid_profile.zig -OReleaseFast -Mlz77=src/lz77.zig --test-filter 'mid-size outlined'
```

Exact sample counts, encoded sizes, source/executable identities, rejected
boundaries and retained regressions are in
[the imx evidence](https://github.com/passchaos/imx/blob/main/docs/evidence/png-small-planner.md).
Remaining decision/token memory, actual-wire cost/block planning and broader
PNG/JXL functionality/performance leadership are not established by this change.
