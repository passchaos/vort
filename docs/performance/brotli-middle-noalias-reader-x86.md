# x86-64 Brotli middle-tier noalias reader

Date: 2026-10-06. Baseline: `c6fbf9cd`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`).

## Scope and safety

The 65--128-literal-tree wrapper creates one private `fast_bit_reader.Reader`
after preparing its literal and optional command/distance lookups. Every call
to the isolated nine-bit payload receives that wrapper-owned reader, which
cannot alias output, parsed header state, recent-distance history, or any
lookup plane. The payload now exposes this existing ownership invariant with a
`noalias` reader parameter.

The contract changes no state representation, branch, allocation, format
gate, or error ordering. The payload continues to mutate the same reader
directly, and the wrapper's established defer synchronizes its exact logical
cursor on success and failure. This avoids the copy and per-exit state sync
that regressed the rejected full-tier private-reader experiment.

LLVM changes each of the five nine-bit payload instances differently. The
selected UTF-8/zero-postfix instance grows from `0x12db` (4,827) to `0x1320`
(4,896) bytes and moves 64 bytes earlier. The two general command-lookup
instances each shrink by 15 bytes, while the two smaller fallback instances
grow by ten. The whole `.vort_br_wide_lookup9` section grows only five bytes,
from `0x6c1b` to `0x6c20`; paired full-tier and wide10 sections retain their
addresses, sizes, and exact bytes. A final source rebuild reproduces the
measured nine-bit section byte-for-byte.

## Performance

The frozen 1,726,567-byte source input has unchanged 141,001/147,580-byte
q9/q5 frames. Decoder-only processes use 500 iterations and same-process
Vort/libbrotli comparisons use 100. Launch order alternates on CPU 2, and a
continuous 0.2-second Zig-process monitor rejects every contaminated attempt.

| Input | Decoder-only median / geometric | Wins | Range | libbrotli-normalized median / geometric | Candidate / libbrotli median / geometric |
| --- | ---: | ---: | ---: | ---: | ---: |
| source q9 | 1.0030x / 1.0037x | 12/15 | 0.9963x--1.0147x | 1.0059x / 1.0034x | 0.7861x / 0.7861x |
| source q5 | 1.0067x / 1.0055x | 13/15 | 0.9879x--1.0133x | 1.0032x / 1.0024x | 0.7827x / 0.7809x |

The longer decoder-only campaigns and both libbrotli-normalized campaigns are
positive. The shorter q5 same-process direct geometry is `0.9992x`, so the q5
claim is bounded by the longer target and positive normalization rather than
that raw reference batch. The candidate still trails libbrotli by roughly 21%,
and no broad decode-leadership claim is made.

Non-target controls cover byte-identical paired and wide10 sections:

| Input | Pairs | Median / geometric | Wins | Range |
| --- | ---: | ---: | ---: | ---: |
| roadmap q9 | 7 | 1.0030x / 1.0029x | 5/7 | 0.9974x--1.0123x |
| roadmap q5 | 15 | 0.9985x / 0.9975x | 3/15 | 0.9906x--1.0023x |
| clustered q8 | 7 | 0.9967x / 0.9996x | 3/7 | 0.9950x--1.0049x |

Their combined 29-pair geometric mean is `0.9993x`. The repeatable roadmap-q5
binary offset remains below one percent and its executed paired section is
byte-identical; the minimum pair across all controls remains above `0.9905x`.
It is tracked as linked-binary/host noise rather than reported as a gain.

Exact hashes, code sizes, raw timing observations, discarded-attempt counts,
and validation totals are in
[brotli-middle-noalias-reader-x86-20261006.json](data/brotli-middle-noalias-reader-x86-20261006.json).

## Validation

- All 551 direct ReleaseFast Brotli tests pass.
- The upstream differential passes 7,056 generated one-shot cases, 7,056
  progressive cases, 1,401 fragmentation schedules, 64 high-tree truncations,
  and seven Large Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases across four required categories.
- The 13-row libbrotli reference gate and three-row path smoke pass.
- The full project test suite, `zig build check -j2`, CLI help smoke, and
  AArch64 Linux ReleaseFast compilation pass.
