# Zstd repeat-key comparison on real files and a raw dictionary

The three-word HQ repeat-key comparison retained in `8bfcd26f` also benefits
real inputs in this expanded experiment. Three Silesia files and an actual raw
dictionary reference exercise the ordinary native encoder. All input, wire
and complete diagnostic-profile identities remain equal to baseline `b04a9019`.
The [evidence package](data/zstd-repeat-key-real-20261028/) contains the source
diff, compile commands, binary hashes, input bytes and all raw runs.

Runs use Zig 0.16.0 LLVM ReleaseFast, Skylake code generation, Intel i7-10700K,
one encoder thread pinned to CPU 4. This is a separate epoch from the prior
CPU-2 synthetic screen. The existing full-library RF compiler remained active
and is recorded in the background samples. Neither a clean-host timing claim
nor a comparison with competitor encoding throughput is made here.

Ordinary encoding occurs before an independent profiled encode for each
configuration. Input setup, hashing, output free, decode and writes are outside
ordinary timing; the allocating encode API is timed. Requested window log is
15 and block maximum is 32 KiB. Baseline/candidate order alternates by
configuration and reverses over three rounds. Medians use three ordinary
samples per variant and configuration.

| File | Size | btopt candidate/baseline time | btultra2 candidate/baseline time |
| --- | ---: | ---: | ---: |
| Dickens | 4 KiB | 0.6663 | 0.5942 |
| Dickens | 16 KiB | 0.6656 | 0.5946 |
| Mozilla | 4 KiB | 0.3336 | 0.2576 |
| Mozilla | 16 KiB | 0.3661 | 0.2838 |
| MR | 4 KiB | 0.5961 | 0.5266 |
| MR | 16 KiB | 0.3641 | 0.2625 |
| Raw dictionary fixture | 2084 B | 0.4141 | 0.3650 |

MR 16 KiB btultra2 changes from 5262.369 ms to 1381.251 ms. The dictionary
fixture includes two slices of the frozen raw dictionary plus a JSON tail;
both strategies report one actual dictionary sequence. Its 1084-byte wire
has SHA-256 `1fdf49b10797c41d60bef495442f60670bf498705f7c0669d82a3743ab91bcc5`
in every version/round. All 84 ordinary encodes, 168 native decodes and complete
profile-shape comparisons pass. These observations extend the earlier small
synthetic result, but do not establish a gain for every file, level, dictionary,
platform or block size. Trained dictionaries and 64/128 KiB blocks remain next.

## Brotli interval memo screens

A separate candidate cached complete weighted Huffman costs for immutable
fixed-grid literal intervals. Its reference policy, all proposal fields and
all ordinary wire/settings identities remain equal. The initial memo layout
passes 38 Debug and ReleaseFast component tests. The layout that reuses dead
context storage passes 38 Debug tests, including two cache contracts and 576
search comparisons over thresholds, distributions, scattered inserts and UTF8
cutoffs. A 24-configuration component screen measures time ratio 0.839658.

The ordinary q8 encoder does not establish a useful overall benefit. Three
interleaved sweeps of twelve Silesia 4/16/64 KiB prefixes give geometric
candidate/baseline time ratio **0.999257**, with per-size ratios
1.005272/0.998374/0.994158. MR 64 KiB improves to 0.944175, while Mozilla 4 KiB
regresses to 1.018844. Each point combines fifteen ordinary samples, and all
complete wires/settings agree. A three-file discovery run had an anomalously
large Dickens point that the full matrix did not reproduce; it is excluded.

The candidate reuses dead context-histogram storage for its memo instead of
adding a full additional array. An alternative moves refinement into a
separate function. That version retains all proposals in 38 Debug checks, but
an ordinary discovery screen still regresses Mozilla 4 KiB by 3.9%. Neither
version is included in production. The archive freezes both versions, reference
sources and raw reports. Further interval memo work needs stable ordinary-call
gains and attention to the early-rejection path; component speed is insufficient.

The original full-library RF compilation remains a separate tracked job.
These experiments preserve its running handle. Continue the complete ten-format
goal with wider real Zstd inputs and measured adaptive-distance Brotli candidate
preparation costs.
