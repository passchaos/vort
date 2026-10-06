# x86-64 Brotli full-tier noalias reader

Date: 2026-10-06. Baseline: `b40f7b9d` production source, functionally
identical to performance baseline `b1c327d1`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`).

## Scope and safety

The paired 129--256-literal-tree wrapper creates its `fast_bit_reader.Reader`
as private stack storage immediately before entering the noinline payload. It
cannot alias caller output, compressed-header state, recent-distance history,
or the three wrapper-owned lookup planes. The payload parameter now states
that existing invariant with Zig's `noalias` contract.

Unlike the rejected payload-local reader copy, this change does not copy or
synchronize reader state on every error exit. It adds no branch, allocation,
state field, format restriction, or public API behavior. Truncation and other
errors still update the same wrapper-owned reader directly, and the wrapper's
existing defer synchronizes its exact logical cursor to the scalar reader.

LLVM changes scheduling rather than fully scalarizing the reservoir. The
selected UTF-8/direct-context payload grows from `0x14c0` (5,312) to `0x14e6`
(5,350) bytes and the generic payload from `0x1690` (5,776) to `0x1698`
(5,784). The paired section grows only 32 bytes, from `0x3b0b` to `0x3b2b`;
the following wide10 and wide9 sections keep their addresses, sizes, and exact
bytes. A final source rebuild reproduces the measured paired section exactly.

## Performance

The frozen roadmap q9/q5 streams remain 335,220/350,069 bytes for the
1,251,399-byte input. Decoder-only processes use 500 iterations and
same-process Vort/libbrotli comparisons use 100. Launch order alternates on
CPU 2. A continuous 0.2-second Zig-process monitor rejects every contaminated
attempt.

| Input | Decoder-only median / geometric | Wins | Range | libbrotli-normalized median / geometric | Candidate / libbrotli median / geometric |
| --- | ---: | ---: | ---: | ---: | ---: |
| roadmap q9 | 1.0060x / 1.0067x | 15/15 | 1.0009x--1.0177x | 1.0053x / 1.0035x | 0.7818x / 0.7817x |
| roadmap q5 | 1.0067x / 1.0066x | 14/15 | 0.9953x--1.0158x | 1.0063x / 1.0069x | 0.8046x / 0.8060x |

Both longer target campaigns and the independent libbrotli normalization are
positive. Five initial q9 attempts and three reference attempts per quality
overlapped external Zig builds and were discarded. The candidate still trails
libbrotli by roughly 19%--22%, so this is a bounded full-tier improvement, not
decode leadership.

Three seven-pair controls exercise unchanged decoder sections:

| Input | Median / geometric | Wins | Range |
| --- | ---: | ---: | ---: |
| source q9 | 0.9994x / 0.9994x | 3/7 | 0.9966x--1.0035x |
| source q5 | 1.0008x / 1.0017x | 4/7 | 0.9785x--1.0267x |
| clustered q8 | 1.0034x / 1.0027x | 4/7 | 0.9868x--1.0195x |

Their combined 21-pair geometric mean is `1.0013x`. The source-q5 and
clustered ranges include host-noise outliers, while their medians and combined
result show no stable non-target regression. Twenty-eight clustered attempts
that overlapped the external build were discarded.

Exact executable and section hashes, raw nanosecond and MiB/s observations,
discarded-attempt counts, and validation totals are in
[brotli-full-noalias-reader-x86-20261006.json](data/brotli-full-noalias-reader-x86-20261006.json).

## Validation

- All 551 direct ReleaseFast Brotli tests pass, including the full-wide
  transition/truncation oracle.
- The upstream differential passes 7,056 generated one-shot cases, 7,056
  progressive cases, 1,401 fragmentation schedules, 64 high-tree truncations,
  and seven Large Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases across four required categories.
- The 13-row libbrotli reference gate and three-row path smoke pass.
- The full project test suite, `zig build check -j2`, CLI help smoke, and
  AArch64 Linux ReleaseFast compilation pass.

The same proven ownership contract was subsequently evaluated independently
for the 65--128-tree executor. Its retained results are in
[brotli-middle-noalias-reader-x86.md](brotli-middle-noalias-reader-x86.md).
