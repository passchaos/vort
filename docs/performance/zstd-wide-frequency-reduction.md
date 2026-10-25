# Zstd wide frequency reduction

Date: 2026-10-25. Baseline: `452445f4`, following the
[winner cost bound](zstd-winner-cost-bound.md). The industry-best objective
remains incomplete.

The certificate's current-frequency inspection visits 256 symbols on each
bound query. This increment specializes that exact inspection using eight
lanes, numerically widening u32 frequencies to u64 before accumulating totals
and negative frequency changes. Support masks and active counts are also
reduced exactly. Other alphabet sizes, certificate initialization/publication
and the final signed lower-bound arithmetic retain their scalar behavior.

Any complete 256-symbol u32 array sums to at most `2^40-256`; each accumulation
lane sums at most `2^37-32`. Negative mass has the same unconditional bound.
Therefore the wide additions cannot overflow even for malformed frequencies.
Checking the completed total before narrowing negative mass preserves the
original `InvalidFrequencyTotal` versus `IntegerOverflow` priority. The normal
128 KiB frequency cap is still checked from the actual complete array; no
unchecked `Prepared` shortcut is added.

`prior-min(prior,current)` computes negative changes without unsigned
underflow. Loads need ordinary u32 alignment, do not overread either 256-entry
array and retain no input pointer. Certificate layout, owned snapshot,
trusted-cost contract and allocator behavior are unchanged. A small reduction
module owns the optimized kernel, while `analyzeReference` retains the original
checked scalar inspection for diagnostics and comparisons.

## Independent validation

The focused test passes in native Debug, native ReleaseFast and actual 32-bit
x86 ReleaseFast. It compares complete errors and every analysis field using
both the old scalar path and a separate u128/i128 oracle. Cases include legal
131072 totals, 131073, all-u32-max, all-2^24 (sum exactly 2^32), support changes
with equal cardinality, empty/RLE, corrupted previous mass and trusted scalar,
error priority, generic n=2/3/4/257, bit caps 1/3/11/255, non-SIMD-aligned u32
arrays and publication failure preserving the previous witness. The fixed
certificate remains smaller than 2 KiB; the combined cache has no new heap.

## Complete-analysis microbenchmark

`zig build run-zstd-weighted-bound-bench -- 250000` compares `analyzeReference`
and `analyze` in one ReleaseFast process with five alternating rounds. Every
pre-generated input first passes exact field/error equality. A noinline call
and runtime index selection retain query work; measured loops also include
input selection, final signed analysis, call/loop work and a checksum. They
are not exclusive inspector CPU-time samples.

On the i7-10700K, target `skylake+pku+sgx`, CPU8, Zig 0.16.0:

| 64-array input pool | Scalar median ns/query | Wide median ns/query | Scalar/wide throughput ratio |
| --- | ---: | ---: | ---: |
| Medium support | 248.209 | 53.785 | 4.6148x |
| Dense support | 248.097 | 53.619 | 4.6271x |
| Invalid totals | 6.157 | 51.160 | 0.12034x |

Invalid pools exceed the cap immediately in the scalar path, whereas the wide
path completes the array before returning the same error. This slower error
path is recorded explicitly; the kernel does not claim to accelerate every
input. The valid paths motivating this change come from bounded literal
histograms. Compiler lowering and throughput on other targets require their
own measurements. Warm microbenchmark input pools and five rounds do not
establish whole-encoder speed or a repeated-process statistical ranking.

Independent disassembly verifies the pinned executable uses AVX2/YMM
zero-extension (`vpmovzxdq`) before qword addition (`vpaddq`), including its
horizontal sum. The backend transforms the nonnegative difference into
`max(prior,current)-current` before widening. Normal unaligned vector loads
retain the ordinary u32 alignment contract. Each input array's accessed span
is exactly 1024 bytes; current frequencies are physically loaded more than
once, so load traffic is separate from the unique readable range. The public
encoder contains the same inlined wide reduction. These instructions verify
this target's lowering, rather than establishing a ranking on other CPUs.

## Public API and final checks

The old production and new executables each have a compiler-free fourteen-row
five-round run with frozen 64 KiB inputs and the unchanged complete level-3
policy. Compilation and verification complete between those separate version
processes. The CPU, target and build mode match the kernel evidence; the
reference is the explicit local libzstd 1.6.0 file from checkout `01b7154f`.
Input, source, executable and requested reference-file identities stay fixed.

| Input | Old public median | New public median | Version point speedup |
| --- | ---: | ---: | ---: |
| XML | 1286.290 ms | 993.477 ms | 1.29474x |
| MR | 966.697 ms | 780.514 ms | 1.23854x |
| Source code | 499.534 ms | 385.181 ms | 1.29688x |

The fourteen-row version throughput geometric speedup is 1.11958x. Twelve
median point estimates improve; NCI and schema JSON are 0.99845x and 0.98851x.
Small differences are not assigned statistical significance. Every Vort and
reference frame size and SHA-256 stays unchanged. Ratio remains 310,437/328,241
total bytes with thirteen smaller Vort frames. The new throughput/reference
geometric ratio is 0.00330414x, with zero competitor throughput wins. These
single-process five-round controls do not establish all-level/platform
leadership or a repeated-process ranking. Requested reference-file identity
does not prove complete loader dependency closure.

XML and MR candidate diagnostics preserve every recorded work field, including
queries, selected matches, actual Huffman plans, refusals, certificate ages and
histogram scans, along with their exact block hashes. That correctness run
occurs during unrelated builds, so its elapsed fields are excluded from speed
claims. No candidate, match, Huffman or level limits change in this increment.

The complete native ReleaseFast Zstd family passes 1093/1093 and all build
checks pass 170/170. Narrow native/x86 oracle checks and the public sample gate
are recorded alongside source hashes and raw rounds in the
[evidence package](data/zstd-wide-reduction-20261025/artifact-manifest.json).
