# Zstd merged frequency preparation

Date: 2026-10-25. Baseline production: `df05f9fe`, after the
[single-sequence cost increment](zstd-single-sequence-cost.md).
The objective of industry-best functionality and performance remains open.

Each exact candidate prepares a frequency vector from the histogram's four
streams and then scans that vector to count nonzero symbols. This increment
merges eight symbols at a time and counts their nonzero mask in the same pass.
The fixed output remains 256 u32 frequencies. The histogram gains an internal
`totalFrequenciesAndCount` entry; the original `totalFrequencies` traversal
stays available and unchanged. Candidate preparation replaces only its merge
and count calls, keeping histogram updates, header calculation, errors and
the legacy prefix/tail literal view.

## Arithmetic and ownership

Four-row additions retain the original left-to-right order:
`((row0 + row1) + row2) + row3`. A valid bounded histogram has nonnegative
frequencies and each symbol's combined count at most the regenerated length,
which is at most 131072. All intermediate u32 sums therefore remain in range.
This function does not validate arbitrary externally fabricated frequency
rows; the checked histogram and certificate admission contracts stay distinct.

Every input row is complete and initialized. Loads require only ordinary u32
alignment, and output consists of exactly 256 entries including zero symbols.
Production uses a separate local output array; the helper does not retain
input, allocate memory, add histogram state or mutate stream frequencies.
The histogram's existing cut/counter admission and subsequent state changes
stay unchanged.

## Independent checks

The histogram/merge suite passes 13/13 in native Debug, native ReleaseFast and
actual 32-bit x86 ReleaseFast. A separate u64 per-symbol oracle checks complete
frequency output and unique counts for zero, RLE, sparse/dense support, maximum
symbol totals and all stream partitions. Tests cover non-SIMD-aligned u32
arrays, input preservation and output guards. Another oracle counts the actual
`block[0..prefix] ++ block[tail..]` bytes across one/four-stream and large-length
boundaries, comparing both histogram interfaces and retaining state unchanged.

## Complete merge/count microbenchmark

`zig build run-zstd-frequency-merge-bench -- 250000` compares the original
two-pass scalar reference with the new merged traversal in one process. All
64 generated input arrays per pool first pass exact output/active-count
equality. Five rounds alternate call order. The measured loop includes runtime
input selection, a noinline merge call, writing caller output and checksum work;
it is not an exclusive source-function CPU profile.

On i7-10700K, ReleaseFast, target `skylake+pku+sgx`, CPU8, Zig 0.16.0:

| Pool | Original median ns/query | Merged median ns/query | Point throughput ratio |
| --- | ---: | ---: | ---: |
| Medium four streams | 193.830 | 50.784 | 3.8167x |
| Dense four streams | 196.158 | 44.911 | 4.3677x |
| Single stream | 197.165 | 51.920 | 3.7975x |

The original reference is two complete loops, matching merge-then-count
behavior; it is not the earlier fused-scalar prototype. Source/executable
identities and zero compiler observations are retained. One warm process and
these generated pools cannot establish a whole-encoder speedup or a repeated
all-platform ranking.

Independent disassembly confirms the micro reference writes the complete
output and rereads it for counting, while the merged path counts from the
merged AVX2 registers during the same traversal. The public encoder inlines
the merged path and uses its active count for raw/RLE and Huffman admission.
Later preparation/plan copies and active-symbol construction still exist;
this optimization does not claim all subsequent frequency visits disappear.

## Public encoder and final verification

A newly captured fourteen-input five-round old-production baseline uses frozen
64 KiB inputs, the complete level-3 policy, the same CPU/build and explicit
local libzstd 1.6.0 file from checkout `01b7154f`. No compiler process is observed
and all input/source/executable/reference identities stay fixed. New public
measurements now use the same frozen inputs and full level-3 policy. Each
version has five alternating Vort/reference rounds in a separate process;
builds complete between the runs, which observe no compiler processes.
Requested reference-file identity is retained without claiming complete loader
dependency verification.

| Input | Old public median | New public median | Version point speedup |
| --- | ---: | ---: | ---: |
| XML | 840.216 ms | 586.070 ms | 1.43364x |
| MR | 669.157 ms | 499.548 ms | 1.33952x |
| Source code | 322.126 ms | 224.770 ms | 1.43314x |

The fourteen-row version throughput geometric speedup is 1.15165x. Twelve
median point estimates improve, while Samba/SAO are 0.97209x/0.97323x. Small
changes have no assigned statistical significance. Every Vort/reference frame
size and hash remains unchanged. Ratio stays 310,437/328,241 total bytes, with
thirteen smaller Vort frames. The new throughput/reference geometric ratio is
0.00396409x, with zero competitor throughput wins. These local controls do not
establish a repeated-process, all-level/platform or memory ranking.

The complete native ReleaseFast Zstd family passes 1098/1098. XML/MR
diagnostics preserve every recorded candidate work field and exact block hash;
their elapsed values are excluded because those checks run during unrelated
builds. The complete build check passes 172/172. Compression settings, search
limits and mode selection are unchanged.
Broader platforms, all levels, streaming, 1 MiB and symmetric competitor memory
measurements remain separate work.

After pulling with rebase, the histogram/merge suite passes 13/13 again with
unchanged source manifests. CLI help passes its seven-step check and the new
benchmark route passes a three-step one-query smoke. Smoke durations are not
used as performance evidence. Commands, source/input/reference identities,
raw rounds and independent source/ELF reviews are retained in the
[evidence package](data/zstd-frequency-merge-20261025/artifact-manifest.json).
