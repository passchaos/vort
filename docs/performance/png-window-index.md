# Bounded reverse-parser indexes

One-shot fixed-cost optimal parsing keeps predecessor and raw/prefix ordinal
arrays inside a 128-KiB chunk, 32768 bytes of past history and 258 bytes of
lookahead. A first-occurrence table distinguishes an absent chain from an
expired predecessor. Global dense/sparse policy samples are captured in one
forward scan. Ordinal offsets cancel inside the live history, retaining exact
candidate counts and strict ties. DP cost windows and decision reconstruction
continue across chunk boundaries.

The active chunk uses a read-only address snapshot. Integer biases are turned
into pointers only after adding an in-range absolute position; the result is
the original owned-array address. The large one-shot planner has a separate
function boundary. Reusable and caller-modeled scratch retain their full arrays.
Fixed proxy costs that exceed the 32-bit representation are rejected before
input-sized allocation; modeled costs keep their own validation.

The final consumer covers fifteen original rasters, Adaptive/Up and numeric
levels 1/6/8/9: 120 complete native PNG pairs and 720 independent image-png/
libpng original-pixel observations. Every native buffer is byte-identical to
the released compact-decision source. Every candidate requested-heap peak is
no larger and all live heap returns to zero after destruction.

Level-8/9 requested-heap geomean ratios are 0.652961x/0.651909x. Each level
changes 24 of thirty allocator records; levels 1/6 retain every record.
Exoplanet/Adaptive level 9 retains its 781,539-byte PNG while peak requested
heap changes from 303,225,356 to 105,588,892 bytes. Dense index arrays occupy
1,577,488 bytes regardless of the larger input length. Decision and returned
token arrays still scale with the input.

Validation includes 129 ReleaseFast LZ77 tests, 129 selected DEFLATE tests,
six Debug bounded-index controls, public profiling diagnostics, baseline x86/
PowerPC64 compilation, the high-coordinate affine-address control and both
imx bounded PNG modes (87 tests each). The current frozen baseline comparison
retains all 192 parser-state cases after the local code commit and pull.

```sh
zig test src/lz77.zig -OReleaseFast
zig test src/deflate.zig -OReleaseFast --test-filter best --test-filter optimal --test-filter dictionary --test-filter numeric
zig test src/lz77.zig --test-filter 'optimal bounded index'
zig test --dep index -Mroot=src/lz77/optimal/tests/read_view.zig -Mindex=src/lz77/optimal/window_index.zig
zig test -OReleaseFast --dep lz77 -Mroot=src/lz77/optimal/tests/window_profile.zig -OReleaseFast -Mlz77=src/lz77.zig --test-filter 'bounded index profile'
```

The complete sixty-case three-round CPU matrix gives 1.025239x geomean and
1.058915x aggregate throughput. Native aggregate changes from 3.49 to 3.70
MiB/s versus image-png's 26.07 MiB/s (0.141777x). All twenty-four regressions
remain visible; the minimum is 0.942616x for the 128-pixel rsvg icon/Adaptive
level 9, which remains below the window threshold. The small-input planner
and code-generation boundary remain a follow-up performance target.

Eight exact final RSS pairs include the same complete PNG and allocator
records as the full corpus. Exoplanet/Adaptive changes from 329,252,864 to
131,596,288 bytes RSS; Lohengrin/Up changes from 151,257,088 to 108,421,120.
The full CPU process-family maximum is 330,997,760 bytes, including the released
peer. Builds use one job and a 4-GiB process address-space ceiling; runtime
evidence uses a 1-GiB ceiling with serial peers, successful exits and zero swaps.
Requested heap, process RSS and address-space limits remain distinct.

Complete samples, all per-image regressions, source/executable/reference roles
and actual file identities are in
[the imx evidence](https://github.com/passchaos/imx/blob/main/docs/evidence/png-window-index.md).

Further decision storage, actual-wire cost/block planning, broader PNG
compression/decode measurements and JXL functional/perceptual-quality/resource
coverage remain open. This milestone does not establish whole-format leadership.
