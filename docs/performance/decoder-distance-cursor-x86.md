# Distance and cursor experiments on x86-64

Date: 2026-10-01. Host: Intel Core i7-10700K, Linux x86-64, Zig 0.16.0,
ReleaseFast, one codec thread pinned to CPU 2. The local references are
libbrotli 1.2.0-dev (`558fc647`) and libzstd 1.6.0-dev (`01b7154f`).
All decoder candidates below were removed. The retained changes strengthen
distance-reader regression coverage and the Brotli comparison methodology;
they do not claim a decoder speedup.

## Zstd compact split output cursor

The resumed worktree contained a compact-split local-output-cursor experiment
plus 336 inline NOPs in a cold instance to restore following code addresses.
Prior completed measurements had a positive large-JSON result, but the padding
was an unguarded x86 jump and depended on the precise surrounding binary size.
It was removed before the new screens.

Two portable variants were measured against the frozen `cc519d45` decoder:

| Variant | large_json median / geometric | Wins | Representative concern |
| --- | ---: | ---: | --- |
| Local cursor with 4-KiB function alignment | 1.0210x / 1.0189x | 6/7 | `rle64k` median 0.9811x, 2/7 wins; unrelated rows fluctuate heavily |
| Local cursor only in the bounded-wildcopy instance | 1.0132x / 1.0131x | 6/7 | `ascii64k` median/geometric 0.9908x, 3/7 wins |

These complete 13-row screens used 1,000 iterations per row and alternating
baseline/candidate process order. Their broad variance and control regressions
do not establish an acceptable general improvement. Both variants, including
the experimental alignment, were removed. A future compact-executor change
must earn its improvement without preserving an incidental byte layout.

## Brotli regular-distance representation

The input is the same frozen 1,726,567-byte source snapshot used by the retained
wide external-distance-root change, SHA-256
`b75cf6294797c217c0e4a17054a65c5e2d6a355529eccd65c7fd94c24f26fff0`.
Local libbrotli quality 9 emits 141,001 bytes, with 104 literal trees and 37
distance trees. Baseline executable SHA-256 starts `3f01fdf7`, corresponding
to the retained `e860968c` implementation. Each process uses 100 iterations
and its best of five timing rounds; process order alternates for every pair.

| Candidate | Pairs | Median | Geometric | Wins | Reference-normalized geometric |
| --- | ---: | ---: | ---: | ---: | ---: |
| 32-bit roots embedding base and extra-bit width | 7 | 1.0070x | 1.0240x | 6/7 | 0.9926x |
| Same roots, combined Huffman/extra-bit consumption | 5 | 0.9905x | 0.9896x | 1/5 | 0.9832x |
| 16-bit roots encoding RFC factor, postfix, extra width | 5 | 0.9701x | 0.9729x | 0/5 | 0.9722x |
| One 64-bit base/extra metadata word per symbol | 5 | 0.9950x | 0.9957x | 2/5 | 0.9978x |
| Executor-local recent-distance array | 5 | 0.9859x | 0.9951x | 2/5 | 0.9988x |

The first variant doubles the root plane from 64 to 128 KiB. Its apparent
geometric gain is dominated by one 1.1286x process pair: reference throughput
also changes from 1,167.30 to 1,453.75 MiB/s across that pair. The modest median
and negative reference-normalized result do not justify the added memory.
Reconstructing the distance base in 16-bit roots keeps the original memory
footprint but adds arithmetic that loses every measured pair. Packing only
the metadata adds 1,560 bytes to the header and removes a dependent load, but
still fails to improve complete-frame throughput. Localizing the recent-distance
array also fails to improve the measured executor.

The root candidates passed focused comparisons with the canonical decoder
over all 64 RFC parameter combinations, direct/short/regular symbols,
long-code fallback, and truncated bit suffixes. The 32-bit combined variant
also passed all 543 then-current direct Brotli tests. These correctness results
are not performance evidence.

## Retained validation and measurement changes

`br prepared distance readers match RFC values and every truncated suffix`
now tests both production readers against the RFC resolver for every legal
ordinary distance symbol across all 64 parameter combinations. It checks
zero/maximal suffix values, each shorter suffix length, exact consumed-bit
positions, and out-of-alphabet rejection. This remains useful independently
of any distance-table representation.

The existing Zstd split-Huffman generic-parity test also retains the resumed
compact-executor short-output case. It requires `OutputTooSmall`, a nonzero
bounded progress cursor, and an untouched physical caller suffix after the
clipped output view. The cursor optimization and padding are not retained.

The Brotli reference benchmark now alternates Vort and libbrotli within each
of its five warmed rounds, reversing the first implementation on successive
rounds, as the Zstd benchmark already does. It retains each implementation's
best-of-five estimate and checks the full decoded buffers after timing.
The CSV schema, iteration counts, and throughput floors are unchanged. The
path smoke also checks exact checksums for paired and Vort-only sampling.
Alternation reduces exposure to drift; it does not eliminate scheduling,
frequency, or code-placement sensitivity, so repeated pairs remain necessary.

Three independent invocations per row with the new alternating sampler confirm
the next gap. Each invocation uses 100 iterations per round, the same CPU 2
affinity, and the same local libbrotli:

| Frozen input | Quality | Literal trees | Command types | Distance trees | Vort/libbrotli median |
| --- | ---: | ---: | ---: | ---: | ---: |
| source, 1,726,567 bytes | 9 | 104 | 10 | 37 | 0.7344x |
| roadmap, 1,251,399 bytes | 5 | 143 | 3 | 22 | 0.6300x |
| roadmap, 1,251,399 bytes | 9 | 143 | 3 | 27 | 0.6262x |

The inputs can be reconstructed with `git show 488c5415:src/br.zig` and
`git show 488c5415:docs/roadmap.md`. The JSON includes all nine observations,
their exact commands and executable hash. These measurements establish a
baseline and work priority, not an improvement caused by the sampler change.

The next performance target is the slower 129--256-literal-tree executor.
It still uses the ten-bit literal policy and lacks the middle tier's fused
command roots and external distance roots. Evaluate those transitions with
an isolated executor and a newly frozen alternating-sampler baseline across
roadmap qualities 5/9 and the existing source controls, before another
regular-distance micro-optimization.

Exact sample times, invariant checksums, input/binary hashes, commands, and
summary statistics are in
[decoder-distance-cursor-x86-20261001.json](data/decoder-distance-cursor-x86-20261001.json).

## Validation

The final changes pass 542 direct Brotli tests in ReleaseFast, the prepared
distance reader tests in Debug, the Zstd split-Huffman specialized/generic
parity and mutation test including its short-output guard, all 13 local
libbrotli reference-gate rows with existing throughput floors, and the input
path smoke (three valid rows, five rejected argument combinations). Changed
Zig files pass `zig fmt --check`; `zig build check -j2` and
`zig build run -j2 -- --help` also pass. The recorded experiment medians,
geometric means, and win counts were recalculated from the saved sample times.
