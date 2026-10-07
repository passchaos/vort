# x86-64 Brotli full-tier zero-postfix instance reuse

Date: 2026-10-07. Baseline: `e8743c95`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`).

## Scope and safety

The selected 129--256-literal-tree payload already specializes UTF-8 literal
contexts and the dominant direct distance context. The frozen roadmap q9/q5
frames also use `NPOSTFIX=0, NDIRECT=0`, but the selected payload still used
the generic prepared-distance reader and therefore retained the dynamic
postfix shift.

The meta-block wrapper now selects that existing payload only when every
literal context mode is UTF-8 and `NPOSTFIX=0`. Its regular-distance path uses
the existing compile-time zero-postfix reader. UTF-8 blocks with nonzero
postfix bits fall back to the already present generic payload. This is
materially different from the rejected three-instance experiment: no payload
is added, and the generic instance continues to cover mixed literal contexts
and nonzero postfix distances.

The full-tier transition oracle explicitly changes the regular-distance
fixture to UTF-8 while preserving its `NPOSTFIX=1` header. It compares the
generic fallback with the prior canonical executor across every input
truncation, output boundary, bit position, recent-distance state, block state,
and caller suffix byte. The existing zero-postfix distance oracle covers the
selected regular-distance calculation and every truncated extra-bit suffix.

Both payload functions retain their addresses and sizes: selected is `0x1557`
bytes and generic is `0x1698` bytes. The paired section stays `0x3b9b` bytes at
the same address. Ordinary `.text`, `.rodata`, Large Window, wide10-auxiliary,
and wide9 sections are byte-identical; only the paired section content changes
among those production sections. The complete candidate executable is 64 bytes
smaller, and the final source rebuild is byte-identical to the measured
candidate.

## Performance

The baseline and candidate were frozen before measurement. Each retained
process performs 500 decoder-only iterations on CPU 2, retaining the
benchmark's best internal round. Launch order alternates by pair. A continuous
20-millisecond `ps -C zig` monitor rejects the whole campaign if another Zig
process appears.

| Input | Pairs | Median | Geometric mean | Wins | Range |
| --- | ---: | ---: | ---: | ---: | ---: |
| roadmap q9 | 15 | 1.0062x | 1.0058x | 15/15 | 1.0001x--1.0128x |
| roadmap q5 | 15 | 1.0040x | 1.0037x | 15/15 | 1.0001x--1.0081x |

Same-process libbrotli normalization was attempted repeatedly, but another
Trae task continuously ran Spectra Zig gates. Every campaign that reached
sampling was discarded when any external Zig appeared; one short local
`zig version` probe was also conservatively invalidated even though the
20-millisecond monitor missed it. No reference-normalized samples or new
Vort/libbrotli ratio are published for this change.

The target rows improve consistently without code-size expansion or downstream
layout movement. This supports retaining the specialization, but it does not
establish broad Brotli decode leadership. The preceding retained full-tier
result remained below libbrotli on the same host, and that gap remains open.

Exact executable and section hashes, raw nanosecond pairs, monitoring
disposition, and validation totals are in
[brotli-full-zero-postfix-reuse-x86-20261007.json](data/brotli-full-zero-postfix-reuse-x86-20261007.json).

## Validation

- All 555 direct ReleaseFast Brotli tests pass, including the explicit UTF-8
  plus nonzero-postfix full-tier fallback oracle.
- Generic x86-64 and AArch64 Linux ReleaseFast compilation pass.
- The 13-row libbrotli reference gate and the three-valid/five-invalid path
  smoke pass.
- The upstream differential passes 7,056 generated one-shot cases, 7,056
  progressive cases, 1,401 fragmentation schedules, 64 high-tree truncations,
  and seven Large Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases across four required categories.
- All 1,701 project ReleaseFast tests, all 104 build-check steps, and CLI help
  pass.
