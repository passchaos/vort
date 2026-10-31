# Zstd match-end-driven index skip screen

Date: 2026-10-31. This algorithm candidate is not adopted.

The final local-optimal/adaptive-matcher source still rebuilds a full history
index for each block. A diagnostic of three actual 1 MiB inputs counts 917,504
history seed positions per frame. Sampling identifies ordinary matcher process
and exact extension as major costs; the profile includes reference work and is
not an ordinary A/B timing claim.

Local zstd commit `01b7154f1172432f8abe9b3bb9909e14a1176b7d` uses the farthest
referenced match end to advance `nextToUpdate`, skipping repeated regions. The
isolated Vort candidate adopts that principle for full-table local parsing:
after collecting matches it computes the maximum `candidate + length - 8`,
then omits ordinary BT insertion/search before that position. Repeat-code
probes still run, logical progress remains exact and dictionary/history prefixes
remain fully indexed. Small-table local parsing and beam/whole/complete paths
retain the preceding behavior. This is an algorithm heuristic with potentially
different interoperable output, not an exact-frontier optimization.

## Ordinary screen

Independent LLVM ReleaseFast Zig 0.16.0 binaries run serially on CPU 2 of an
Intel i7-10700K, with two alternating sweeps and two raw rounds per process.
Input setup, diagnostic profiles, determinism and both decoder directions are
outside the ordinary allocating encode/free interval. No compiler or separate
codec validation overlaps the timers. Requested btultra2, depth 64, nice 64,
minimum 3 and frame flags match the preceding reference harness. The reference
is the same pinned local libzstd 1.6.0; hash/chain algorithms still differ.

| Scope | Candidate / baseline time | Candidate / baseline size |
| --- | ---: | ---: |
| All twelve 64 KiB Silesia prefixes | `0.992040` | `1.000292` |
| All twelve 128 KiB prefixes | `1.008642` | `1.000241` |
| Three actual 1 MiB inputs | `1.008531` | `1.000062` |
| Three 64 KiB files with a trained dictionary | `0.987076` | `1.000578` |
| 128 KiB periodic control | `0.433795` | `1.000000` |
| 128 KiB random control | `1.032527` | `1.000000` |

Rows are geometric means of case medians where there are multiple files.
The screen contains 20 successful benchmark processes and 32 case/configuration
rows. Periodic work improves substantially, but the real 128 KiB and multi-block
groups take longer with slightly larger output, and the random control regresses.
The candidate does not establish a useful broad tradeoff and remains isolated.

## Validation and next algorithm work

Debug and ReleaseFast each run four named candidate tests, 17 tests total.
They validate exact returned bytes, omitted indexing and input progress, dense
prefix stamps, independent moved/forked ownership, every allocation failure,
exact requested memory, and the actual public parser's finite N/N-1 price caps.
These focused checks validate the prototype boundary, not a production adoption.
The initial copied-binary execute-permission failure occurred before codec work
and is retained separately from the successful campaign.

The [frozen evidence](data/zstd-match-coverage-screen-20261031/manifest.json)
contains source snapshots, raw rounds and decoder-bound wire identities,
scripts, terminal records and diagnostic sampling reports. Its `audit.py`
independently recomputes medians and geometric means, verifies all 20 terminal
process records and 32 case/configuration rows, checks source/input/report
hashes, and confirms the four named tests ran in both modes. Native binary
identities are recorded; their bytes and raw perf data remain in the local
experiment root `/tmp/vort-zstd-persistent-index-20261031`. No production matcher
or routing change from this screen is present in the live tree.

Persistent cross-block index reuse needs its own source-rebinding, generation,
window transition, memory growth and retry contracts. This screen tests selected
repetitive insertion, and does not remove the 917,504-byte history rebuild.
The full Deflate/Zstd/Brotli objective remains active.
