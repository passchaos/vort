# PNG token ownership with source-bound literal runs

Large one-shot optimal parsers and lazy parsers with a minimum match of at
least five now stage contiguous literal runs alongside ordinary matches,
then expand backwards into the same token owner.
The public result still contains one owned literal token per source byte and
the original match tokens. Search order, candidate budgets, ties and wire
selection remain unchanged. Parsers that reuse caller buffers or use a
nonempty dictionary keep their existing ownership.

A private zero-distance record represents up to 65,535 literal bytes.
Real matches keep their existing u16 distance and 3..258 length. Each record
represents at least one output token, so backward expansion writes at or
above the unread record boundary. Source bytes are copied into the result;
the returned owner retains no borrowed input. Capacity growth preserves
records before expansion and final transfer keeps the usual allocator ABI.

This improves intermediate token geometry without an additional match search
or traversal of the completed decision chain. Literal runs coalesce while
parsing/reconstructing, final token count is known, and expansion reserves the
exact result size. Allocators can remap the same storage or fall back to
allocating and copying records. The final complete token array still scales
with input; this change does not promise constant total memory.

A 1-MiB all-literal public plan now completes within a 7.5-MiB fixed allocator
budget. The frozen published parser returns OutOfMemory under that same
budget. Unit and scalar-reference controls cover runs across the u16 limit,
matches, empty input, overlapping backward writes, ownership transfer and
allocation failures. The owning imx report records full PNG bytes, actual
heap/RSS, complete CPU samples and the rejected two-pass reservation trial:
[consumer evidence](https://github.com/passchaos/imx/blob/main/docs/evidence/png-token-runs.md).

All 120 complete PNG outputs retain exact bytes. Levels 1/6 keep allocation
records; levels 8/9 each lower twenty-three of thirty heap peaks by about 4%
geomean. Their complete CPU matrices remain effectively neutral, while small
code-layout regressions remain in the samples. Physical memory does not
improve uniformly: three additional Palette/Adaptive pairs confirm RSS
increases about 4.4 MiB despite a 6.9-MiB requested-heap decrease. The
Lohengrin pair instead reduces RSS about 3.5 MiB. These are allocator/input
tradeoffs, not a whole-corpus RSS leadership claim.

Compiler builds use one job and a 4-GiB address-space ceiling. Encoder
measurements run serially within a 1-GiB ceiling. Remaining work includes the
lazy parser's input-sized predecessor links, complete token ownership, the
optimal DP/minima loop, actual-wire/block planning and broader PNG/JXL
quality, feature and resource coverage. Overall industry leadership remains
unproven.

```sh
zig test src/lz77.zig -OReleaseFast
zig test src/deflate.zig -OReleaseFast --test-filter best --test-filter optimal --test-filter dictionary --test-filter numeric
zig test src/lz77.zig -ODebug --test-filter 'literal token runs' --test-filter chunked
```
