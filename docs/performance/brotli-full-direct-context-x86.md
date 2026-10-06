# x86-64 Brotli full-tier direct distance context

Date: 2026-10-06. Baseline: `5334408b`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`).

## Scope and safety

The frozen roadmap q9/q5 streams use the paired 129--256-literal-tree
executor. Among their 108,109/117,142 explicit distance symbols,
107,157/116,728 use RFC distance context three: 99.12%/99.65%. The existing
full-tier executor cached that tree, but every explicit-distance command still
called the canonical `min(copy_length, 5) - 2` context calculation.

The all-UTF-8 full-tier instance now selects the cached context-three tree
directly when `copy_length >= 5`; lengths two, three, and four retain map
entries zero, one, and two. This is a compile-time option on the UTF-8
instance, so the mixed-context fallback keeps the canonical calculation and
no third payload instance is emitted. Existing direct-versus-canonical tests
cover every copy-length context and also compare decoded distance, recent-
distance ring, bit position, and block countdown.

The selected UTF-8 instance grows from `0x14bd` (5,309) to `0x14c0` (5,312)
bytes, while the generic `0x1690` (5,776-byte) instance is unchanged. The
paired section grows from `0x3afb` (15,099) to `0x3b0b` (15,115) bytes;
alignment moves following sections by 64 bytes, so the middle-tier and
clustered controls are measured explicitly. A final source rebuild reproduces
the measured paired section byte-for-byte.

## Performance

The roadmap q9/q5 frames remain 335,220/350,069 bytes for the 1,251,399-byte
roadmap fixture. Decoder-only processes use 500 iterations and same-process
Vort/libbrotli comparisons use 100. Launch order alternates on CPU 2. Every
pair has a 0.2-second continuous Zig-process monitor; contaminated attempts
are discarded and repeated.

| Input | Decoder-only median / geometric | Wins | Range | libbrotli-normalized median / geometric | Candidate / libbrotli median / geometric |
| --- | ---: | ---: | ---: | ---: | ---: |
| roadmap q9 | 1.0032x / 1.0029x | 13/15 | 0.9985x--1.0068x | 1.0032x / 1.0050x | 0.7784x / 0.7781x |
| roadmap q5 | 1.0014x / 1.0007x | 10/15 | 0.9940x--1.0045x | 0.9993x / 1.0001x | 0.7931x / 0.7955x |

Both longer decoder-only campaigns are positive. The independent
reference-normalized geometry agrees on q9 and is neutral on q5. The
candidate remains only about 78%--80% as fast as libbrotli on these frames,
so this is a narrow full-tier improvement rather than decode leadership.

Three seven-pair controls cover the unchanged generic path and shifted
downstream layout:

| Input | Median / geometric | Wins | Range |
| --- | ---: | ---: | ---: |
| source q9 | 1.0006x / 1.0009x | 5/7 | 0.9967x--1.0036x |
| source q5 | 1.0023x / 1.0019x | 6/7 | 0.9989x--1.0036x |
| clustered q8 | 0.9999x / 0.9993x | 3/7 | 0.9947x--1.0025x |

Their combined 21-pair geometric mean is `1.0007x`; the clustered result is
inside the measured host-noise band rather than evidence of a path change.

Exact executable and section hashes, raw timing pairs, discarded attempts,
controls, context counts, and validation totals are in
[brotli-full-direct-context-x86-20261006.json](data/brotli-full-direct-context-x86-20261006.json).

## Validation

- All 551 direct ReleaseFast Brotli tests pass, including direct-versus-
  canonical distance context selection.
- The upstream differential passes 7,056 generated one-shot cases, 7,056
  progressive cases, 1,401 fragmentation schedules, 64 high-tree truncations,
  and seven Large Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases across four required categories.
- The 13-row libbrotli reference gate and three-row path smoke pass.
- The full project test suite, `zig build check -j2`, CLI help smoke, and
  AArch64 Linux ReleaseFast compilation pass.
