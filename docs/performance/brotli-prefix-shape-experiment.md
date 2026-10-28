# Prefix shape memo: withdrawn

The complete code-length-shape memo against 293964c1 was withdrawn after the
first ordinary-call sweep. Code and diagnostic changes were restored unchanged.
[Raw evidence](data/brotli-prefix-shape-experiment-20261028/) retains the exact
source overlays, source/executable identities, reports and validation.

A fixed 64-entry/two-way cache encoded all 256 u4 code lengths into 128 bytes
and required complete key equality after hashing. The cache was used only for
cluster scores on inputs >=8 KiB; baseline/suffix and the reference did not use
it. Huffman construction and frequency-weighted payloads stayed independent.
No heap allocation was added; fixed stack storage was under 10 KiB.

The pure key is valid when sparse symbols exactly enumerate every non-zero
length in ascending order. A scorer contract compared different frequency
vectors with identical lengths: the prefix memo hit while total scores retained
their independent 2400-bit payload difference. Cache tests passed 4/4 on native
Debug/ReleaseFast/x86 and actual Wasm; full context/reference/randomized checks
plus the scorer contract passed 84/84. Diagnostics distinguished logical
complex scores from actual prefix calls and retained old/new CSV compatibility.

Actual memo hits were only 35/1980 requests on Mozilla, 32/599 on Dickens and
23/815 on MR across two recorded preferred groups. The single-sweep 36-prefix
candidate/baseline time ratio was **1.008117** (0.989652/1.003125/1.032038 for
4/16/64 KiB). All input/wire/settings identities agreed. This point does not
prove significance, but did not justify retaining the implementation.

The ordinary protocol uses the same Zig 0.16.0 ReleaseFast native
skylake+pku+sgx tool, one thread pinned CPU2 on Intel i7-10700K, twelve Silesia
4/16/64 KiB prefixes, five interleaved Vort/reference rounds of three calls,
and q8/generic/actual-lgwin16. Reference is the requested native GCC Brotli
1.2.0/558fc647 build (-O3 -DNDEBUG -march=native); actual loaded objects and
dependencies remain unverified. Vort has an untimed primary warmup, reference
none explicitly. Allocation/free are timed. Timing profiles are diagnostic.

Further inspection identified a smaller sufficient statistic: after RLE
summarization, the remaining complex-prefix score depends on the 18 symbol
frequencies, including repeat16/repeat17 extra-bit counts. Investigate reuse
there, retain actual RLE work and exact prefix scores, and verify ordinary calls.
The full ten-format goal remains active; no production speed claim is made.
