# PNG one-shot optimal decision planes

Large one-shot fixed-cost optimal parses can now store source-bound literal
markers and match decisions in separate distance and length planes. Scratch
arrays cover 128 Ki source positions, using 384 KiB in total, while reverse
parsing seals each chunk into exact-sized
payloads. Each plane chooses positive-count run coding only when it is smaller
than raw storage. Reconstruction restores literals from the immutable input
and copies them into the complete owned token result.

The existing whole-input short-match policy selects the original three-byte
array for inputs whose matching shape cannot amortize coding. This selection
changes decision storage only. Candidate ordering and budgets, tie decisions,
costs, tokens and final PNG bytes retain their previous behavior. Reusable and
caller-modeled parsing keep their established representations.

Distance and length planes together use at most three bytes per input
position, plus bounded scratch and chunk records. This representation does
not promise constant total memory: raw fallback payloads, filtered PNG data
and complete token ownership can still scale with input size. The finite
memory control parses 2 MiB of mostly repeated input and owns its complete
result within a 2-MiB allocator budget; the old decision array alone needs
6 MiB for that input.

Plane encoding compares complete native words after its short-run entry,
using the first unequal element in memory order on either endian. Scalar
tests cover every word boundary, starting offset, mismatch and bounded tail.
Checked run decoding rejects truncated, zero, oversized and trailing data.
Chunk owners reject skipped reverse chunks and premature finalization, and
allocation-failure tests cover partial reservations and payload ownership.

The ordinary imx PNG consumer provides complete-buffer, requested-heap,
process-RSS and CPU-time evidence in
[the imx report](https://github.com/passchaos/imx/blob/main/docs/evidence/png-decision-planes.md).
Compiler commands use one build job and a 4-GiB address-space limit; encoder
children run serially within a 1-GiB limit. The memory reduction retains a
measured CPU tradeoff: the thirty-case Level-9 throughput geomean is
0.988001x, aggregate 0.986228x, with twenty-five regressions and a 0.958511x
minimum. Levels 8/9 each reduce eleven of thirty heap peaks, with a
0.835070x geometric-mean ratio and no peak increases in the corpus.
This milestone does not establish overall PNG/JXL
performance leadership. Remaining work includes complete token memory,
decision admission and scanning costs, actual-wire cost/block planning,
broader PNG decoding and JXL resource/perceptual/feature coverage.

```sh
zig test src/lz77.zig -OReleaseFast
zig test src/deflate.zig -OReleaseFast --test-filter best --test-filter optimal --test-filter dictionary --test-filter numeric
zig test -OReleaseFast --dep lz77 -Mroot=src/lz77/optimal/tests/window_profile.zig -OReleaseFast -Mlz77=src/lz77.zig --test-filter 'bounded index profile'
```
