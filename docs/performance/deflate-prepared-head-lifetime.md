# DEFLATE prepared-index lifetime and match-store screen

The prepared optimal owner no longer retains the 32K-entry hash head after it
has materialized the immutable predecessor links. It now builds `compact_prev`,
releases `compact_head`, and only then allocates the DP cost and step arrays.
The two complete fixed and modeled solves, candidate ordering, tokens and
raw/zlib/gzip arbitration are unchanged.

This is a follow-up to
[`deflate-prepared-optimal.md`](deflate-prepared-optimal.md). The baseline is
clean `c01ff424`; the candidate changes only `src/lz77.zig`.

## Industry match-store study

libdeflate 1.26 builds a compact BT match frontier once, then replays it through
several cost solves. A direct Vort equivalent is not simply an allocation
change: Vort's current hash-chain parser examines a much denser exact candidate
stream. On the level-9 Silesia prefixes, representative valid-candidate counts
include:

- `nci-16384`: 2,607,596 candidates, about 159 per input byte;
- `mr-16384`: 1,938,613 candidates, about 118 per byte;
- `mozilla-16384`: 1,619,421 candidates, about 99 per byte.

A four-byte `(length,distance)` entry would require about 10.4 MiB for the
first case alone. Unlike libdeflate's deliberately reduced length frontier,
blindly storing Vort's exact chain is therefore not an acceptable replacement
for the current sub-megabyte prepared path.

Two bounded match-length caches were implemented and screened before the
retained lifetime change:

| Prototype | All 36 | 4 KiB | 16 KiB | Worst |
| --- | ---: | ---: | ---: | ---: |
| first eight checked candidates per position | `1.038527` | `1.028071` | `1.089965` | `1.154883` |
| first checked candidate per position | `1.036266` | `1.022709` | `1.081210` | `1.157082` |

Both preserve exact wires, but the cache write stream and an extra conditional
in the dense candidate loop cost more than the saved match-length calls. All
cache fields, branches and allocations were removed. A future shared match
store needs to reduce the candidate representation itself—for example, an
explicit DEFLATE distance-cost-class frontier—not merely memoize the existing
chain traversal.

## Ordinary A/B evidence

Separate ReleaseFast executables ran on logical CPU 2 of an Intel Core
i7-10700K. The matrix is all twelve Silesia files at 4, 16 and 64 KiB prefixes.
The 65,536-byte inputs remain disabled controls.

| Mode | All 36 | 4 KiB | 16 KiB | 64 KiB control | Worst |
| --- | ---: | ---: | ---: | ---: | ---: |
| named `best` / level 9 | `0.982905` | `0.957335` | `0.994603` | `0.997288` | `1.015586` |
| numeric level 8 | `0.979977` | `0.956292` | `0.994453` | `0.989631` | `1.008998` |

Level 9 uses five order-alternating process sweeps with seven timed encodes
after warmup. Level 8 uses five sweeps with five timed encodes. All 72 size
comparisons tie. The speedup is largest at 4 KiB, where retaining the 128 KiB
head was disproportionate to the active input and DP working set.

## Memory and compatibility

The requested-byte probe excludes the input and includes the returned raw
wire. Allocation count and cumulative requested bytes are identical; only
lifetime overlap changes.

| Level-9 input | Peak requested bytes | Reduction |
| --- | ---: | ---: |
| `nci-16384` | `729,104 -> 532,368` | `26.98%` |
| `mr-4096` | `400,274 -> 221,440` | `44.68%` |
| `x-ray-16384` | `903,494 -> 706,758` | `21.78%` |
| `xml-65536` control | `2,009,084 -> 2,009,084` | unchanged |

Five alternating `nci-16384` processes move median maximum RSS from 3,716 to
3,568 KiB (`-3.98%`). Baseline and candidate each emitted level 8/9 raw, zlib
and gzip streams for all 36 inputs. All 216 corresponding lengths and SHA-256
values match exactly, and system zlib 1.2.11 decodes every stream to the input
hash.

Prepared equality, OOM ownership, full DEFLATE, x86, external zlib and project
Wasm gates are archived in
[`data/deflate-prepared-head-lifetime-20261030/`](data/deflate-prepared-head-lifetime-20261030/).
