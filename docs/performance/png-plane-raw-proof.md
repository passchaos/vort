# PNG length-plane raw-storage proof

The internal eight-bit optimal-decision length plane can now prove that raw
storage wins by counting unequal adjacent values in vector batches. Every
positive run costs at least one count byte plus one payload byte, so reaching
ceil(N/2) runs proves that coding cannot beat N raw bytes. Prefix checks can
skip the vector pass when it is unlikely to pay off; only the complete
lower-bound proof permits the early raw result. Otherwise the existing exact
run-size calculation and scanner remain authoritative.

Raw eight-bit encoding and reconstruction copy the complete byte plane
directly. Payload bytes, run/raw selection, exact allocation geometry,
distance-plane representation, parser decisions and owned tokens remain
unchanged. The sixteen-bit distance plane retains its original path after
candidate trials showed mixed-run costs and code-layout sensitivity.

The final eight-bit raw controls measure 12.135357x and 18.465098x
encode/free throughput; a mixed raw control gives 1.606204x. The eight-case
complete PNG control is effectively neutral: 0.998643x throughput geomean,
1.000149x aggregate and 0.993548x minimum with six regressions retained.
All 120 PNG buffers and complete allocator records stay exact. Internal
plane gains therefore do not imply a significant complete-encoder speedup.

This optimization follows a sample of the complete PNG encoder: the text
input spends about 74.5% in optimal parsing, 1.5% in sealing chunks and 0.8%
in reading them. It improves a limited part of complete encode time. Native
word scratch was rejected because its five-input pilot added 128 KiB and
did not improve complete-encoder throughput.

The owning imx evidence records exact complete PNG and allocation checks,
isolated raw/run-plane timing, and focused complete-encoder timing in
[the consumer report](https://github.com/passchaos/imx/blob/main/docs/evidence/png-plane-raw-proof.md).
Compiler and runtime resource caps remain 4 GiB and 1 GiB; build jobs and
encoder experiments stay serial. This milestone does not establish complete
PNG/JXL speed, ratio, feature or memory leadership. Larger remaining costs
include the optimal DP/minima loop, complete token ownership, actual-wire
block planning and broader PNG/JXL quality/resource coverage.

```sh
zig test src/lz77.zig -OReleaseFast
zig test src/deflate.zig -OReleaseFast --test-filter best --test-filter optimal --test-filter dictionary --test-filter numeric
zig test src/lz77.zig -ODebug --test-filter chunked --test-filter 'plane vector' --test-filter 'plane word' --test-filter 'plane runs'
```
