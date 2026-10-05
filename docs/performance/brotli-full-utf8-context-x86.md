# x86-64 Brotli full-tier UTF-8 context specialization

Date: 2026-10-06. Baseline: `e44b22d8`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`).

## Scope and safety

The frozen roadmap q9/q5 streams use 143 literal context trees and therefore
select the paired 129--256-tree full-tier executor. Their 47,239/53,639
literal bytes all use RFC UTF-8 context mode, but the payload retained a
runtime `utf8_context_only` branch and dynamic context-mode state for every
literal.

After preparing the paired literal, command, and distance roots, the wrapper
now selects a compile-time UTF-8 payload only when every declared literal
block type is UTF-8. That instance calls the dedicated UTF-8 classifier
directly and lets LLVM remove the dynamic mode branch and mode state. Mixed
LSB6, MSB6, signed, and UTF-8 streams retain the original generic payload.
All Huffman fallback, block switching, truncation, dictionary, distance-ring,
and output-boundary behavior is shared.

The selected payload shrinks from `0x1690` (5,776) to `0x14bd` (5,309) bytes.
Retaining the generic fallback grows `.vort_br_paired_literal` from `0x259b`
(9,627) to `0x3afb` (15,099) bytes. The new instance shifts the paired section
by 64 bytes and the following 10-bit and 9-bit sections by 5,504 bytes, so
middle-tier and clustered controls are measured explicitly.

## Performance

The roadmap q9/q5 frames remain 335,220/350,069 bytes for the 1,251,399-byte
roadmap fixture. Decoder-only processes use 500 iterations and same-process
Vort/libbrotli comparisons use 100. Launch order alternates on CPU 2. Every
pair has a 0.2-second continuous Zig-process monitor; contaminated attempts
are discarded and repeated.

| Input | Decoder-only median / geometric | Wins | Range | libbrotli-normalized median / geometric | Candidate / libbrotli median / geometric |
| --- | ---: | ---: | ---: | ---: | ---: |
| roadmap q9 | 1.0160x / 1.0170x | 15/15 | 1.0030x--1.0348x | 1.0104x / 1.0094x | 0.7738x / 0.7740x |
| roadmap q5 | 1.0146x / 1.0157x | 15/15 | 1.0096x--1.0251x | 1.0143x / 1.0184x | 0.7962x / 0.7968x |

All 30 longer target pairs win, and the independent reference-normalized
campaign agrees. The candidate still trails libbrotli, especially on q9, so
this is a full-tier improvement rather than a broad leadership claim.

Three seven-pair controls cover the shifted downstream layout:

| Input | Median / geometric | Wins | Range |
| --- | ---: | ---: | ---: |
| source q9 | 1.0032x / 1.0032x | 6/7 | 0.9989x--1.0059x |
| source q5 | 1.0018x / 1.0024x | 6/7 | 0.9997x--1.0059x |
| clustered q8 | 1.0012x / 1.0008x | 5/7 | 0.9967x--1.0042x |

Their combined 21-pair geometric mean is `1.0021x`; no control row regresses
at the median.

Exact executable and section hashes, raw timing pairs, discarded attempts,
controls, and validation totals are in
[brotli-full-utf8-context-x86-20261006.json](data/brotli-full-utf8-context-x86-20261006.json).

## Validation

- All 551 direct ReleaseFast Brotli tests pass, including exhaustive clustered
  UTF-8 classifier equivalence across every byte pair.
- The upstream differential passes 7,056 generated one-shot cases, 7,056
  progressive cases, 1,401 fragmentation schedules, 64 high-tree truncations,
  and seven Large Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases across four required categories.
- The 13-row libbrotli reference gate and three-row path smoke pass.
- The full project test suite, `zig build check -j2`, CLI help smoke, and
  AArch64 Linux ReleaseFast compilation pass.
