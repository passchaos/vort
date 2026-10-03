# x86-64 Brotli middle-tier zero-postfix distances

Date: 2026-10-04. Baseline: `39c9c676`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`).

## Scope and safety

The frozen source q9/q5 frames use 104/117 literal trees and therefore select
the 65--128-tree external nine-bit executor. Every compressed block in both
frames also uses `NPOSTFIX=0, NDIRECT=0`; regular distance codes account for
77.53%/77.68% of their applied copies. The generic prepared-distance path
still loads `NPOSTFIX` and emits a variable shift even for this common block
shape.

The meta-block dispatcher now selects a compile-time zero-postfix instance
once per block when both fields are zero. That instance preserves all symbol,
extra-bit, and truncation checks, but evaluates a regular distance as the
prepared offset plus its unshifted extra bits. Every other distance shape and
executor continues to use the generic calculation. The exhaustive prepared-
distance test compares the specialized and generic results and bit positions,
including every truncated suffix.

The selected generic command/distance-lookup instance remains `0x1482` bytes;
the new zero-postfix instance is `0x1472` bytes and does not load `NPOSTFIX` or
emit the dynamic `shlx`. Keeping the generic fallback increases
`.vort_br_wide_lookup9` from `0x4382` to `0x58b2` bytes and the executable from
6,126,296 to 6,155,592 bytes. The measured candidate and final source rebuild
are identical at SHA-256 `85afe32f...01faa`; their complete nine-bit section
is also identical at `cf3da803...f915`.

## Performance

The baseline and candidate were emitted through the same explicit
`-femit-bin` path and frozen before measurement. The q9/q5 frames are the
unchanged 141,001/147,580-byte libbrotli outputs for the 1,726,567-byte source
fixture. Decoder-only processes use 500 iterations; same-process
Vort/libbrotli runs use 100 iterations. Launch order alternates on CPU 2.
Every retained pair used the corrected one-second process monitor and observed
no concurrent Zig process; contaminated attempts were discarded.

| Input | Decoder-only median / geometric | Range | Wins | Reference raw median / geometric | Reference-normalized median / geometric | Candidate / libbrotli median / geometric |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| source q9 | 1.0110x / 1.0125x | 1.0026x--1.0258x | 15/15 | 1.0085x / 1.0120x | 1.0091x / 1.0116x | 0.7729x / 0.7720x |
| source q5 | 1.0128x / 1.0125x | 1.0055x--1.0196x | 7/7 | 1.0203x / 1.0201x | 1.0156x / 1.0185x | 0.7678x / 0.7675x |

Three non-target decoder-only controls remain neutral as a group:

| Input | Median / geometric | Range | Wins |
| --- | ---: | ---: | ---: |
| roadmap q9 | 1.0032x / 1.0018x | 0.9973x--1.0071x | 4/7 |
| roadmap q5 | 0.9966x / 0.9978x | 0.9941x--1.0035x | 2/7 |
| clustered q8 | 1.0045x / 1.0028x | 0.9965x--1.0144x | 4/7 |

The 21 control pairs have a combined geometric mean of `1.0008x`. The target
gain is therefore isolated from the normal whole-process drift and is retained.
It does not establish broad Brotli leadership: the same-process candidates are
still only about 0.77x libbrotli on these two source frames, and the extra
specialized instance costs approximately 5.2 KiB of hot-section code.

Exact hashes, nanosecond observations, derived ratios, and validation counts
are recorded in
[brotli-middle-zero-postfix-x86-20261004.json](data/brotli-middle-zero-postfix-x86-20261004.json).

## Validation

- Five focused ReleaseFast Brotli tests cover middle-tier routing, lookup
  behavior, prepared distances, specialized equivalence, and every truncated
  suffix.
- The full project `zig build test -j2` suite passes.
- The upstream differential passes 7,056 generated one-shot cases, 7,056
  progressive cases, 1,401 fragmentation schedules, 64 high-tree truncations,
  and seven Large Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases across four required categories.
- The 13-row libbrotli reference gate and three-row path smoke pass.
- `zig build check -j2`, the CLI help smoke, and AArch64 Linux ReleaseFast
  compilation pass.
