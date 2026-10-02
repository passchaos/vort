# Brotli zero-insert branch layout

Date: 2026-10-02. Baseline: `9b32f783`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`), CMake Release (`-O3 -DNDEBUG`).

## Measured shape

Hardware sampling was unavailable because the host has
`perf_event_paranoid=4`, so a temporary non-timing counter pass measured the
actual command and distance distributions before changing layout. The probe
was removed after collection.

| Input | Commands | Zero insert | Implicit distance | Regular explicit distance | Context-three explicit distance |
| --- | ---: | ---: | ---: | ---: | ---: |
| roadmap q9 | 109,100 | 88,384 (81.01%) | 990 (0.91%) | 104,884 (97.02%) | 107,157 (99.12%) |
| roadmap q5 | 118,278 | 93,272 (78.86%) | 1,135 (0.96%) | 114,916 (98.10%) | 116,728 (99.65%) |

The command lookup already embeds copy length and implicit-distance metadata
for zero-insert root hits. The retained change marks this 79%--81% arm as
likely immediately after the command countdown is committed. It changes no
table representation, state, bit consumption, or malformed-input behavior.

LLVM consequently lays out the common command path contiguously. The
129--256-tree payload shrinks from `0x1767` to `0x16a0` bytes (199 bytes), and
the existing 9-bit auxiliary payload shrinks from `0x159f` to `0x14e6` (185
bytes). The complete benchmark executable shrinks from 6,081,352 to 6,079,200
bytes in the frozen builds.

## Rejected alternatives

Two shape-derived alternatives were measured and removed:

- Localizing command-block remaining state increased the full-tier payload to
  `0x17d1` bytes and added live state across the literal/distance loop. Seven
  target pairs measured q9/q5 at `0.9843x`/`0.9792x` median, both 0/7 wins.
- Marking the short-distance arm unlikely looked justified by its 1.90%--3.00%
  frequency, but it grew the full-tier payload by 24 bytes relative to the
  retained candidate. Seven pairs measured q9/q5 at `0.9935x`/`0.9870x`
  median, with 1/7 and 0/7 wins.

These failures reinforce the current constraint: reduce hot layout and live
state rather than adding state or moving the already compact distance helper.

## Whole-frame measurements

The frozen 1,251,399-byte roadmap input is from commit `488c5415` and has
SHA-256 `f1da3a855bd2c0370e3cc1e3ac6894cd6de62243e8273e0278b7d8c8973f6ba9`.
Each process runs five warmed alternating Vort/libbrotli rounds. Baseline and
candidate process order reverses for each pair; every pair checks input hash,
encoded size, iteration count, and decoded checksum.

| Input | Pairs won | Median | Geometric mean | Minimum | Reference-normalized geometric | Candidate/libbrotli median |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| roadmap q9 | 15/15 | 1.0155x | 1.0152x | 1.0112x | 1.0136x | 0.7627x |
| roadmap q5 | 7/7 | 1.0216x | 1.0220x | 1.0030x | 1.0257x | 0.7799x |

Seven-pair decoder-only controls were also positive: source q9 improved
`1.0062x` median / `1.0096x` geometric with 7/7 wins; source q5 improved
`1.0093x` / `1.0088x` with 7/7; clustered q8 improved `1.0039x` / `1.0031x`
with 6/7. The change is therefore retained in the shared multi-tree fused
command helper instead of only the full-tier executor.

This closes a repeatable branch-layout cost but does not establish overall
Brotli decode leadership: the target rows remain about 22%--24% behind this
local libbrotli build.

## Validation

- The zero-insert command-state test now also covers the non-zero-insert arm
  and exact countdown behavior.
- The full wide executor's prior-transition and every-bit truncation oracle passes.
- `zig build test -j2`: passed.
- `zig build run-br-reference-bench-gate run-br-reference-bench-path-smoke -j2 -Dcpu=native`: 13 rows plus three valid and five rejected path cases passed.
- `zig build run-br-upstream-multiblock-diff run-br-real-corpus-diff -j2 -Doptimize=ReleaseFast`: 7,056 generated one-shot, 7,056 progressive, 1,401 fragmentation, 64 high-tree truncation, seven Large Window, and 16/16 real-corpus cases passed.
- `zig test src/br.zig -OReleaseFast -target aarch64-linux-gnu -fno-emit-bin`: passed.
- `zig build check -j2` and `zig build run -j2 -- --help`: passed.

Raw paired samples, audit counts, executable hashes, and rejected screens are
retained in
[brotli-zero-insert-branch-x86-20261002.json](data/brotli-zero-insert-branch-x86-20261002.json).
