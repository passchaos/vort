# DEFLATE prepared optimal workspace

These measurements describe the earlier hash-chain prepared path. The
[subsequent BT increment](deflate-bt-optimal.md) uses a separate compact
DEFLATE-only owner for one-shot refinement; the generic `PreparedOptimal`
interface and its arbitrary distance-cost behavior remain available.

Levels 8 and 9 still perform the same fixed-cost seed parse and one
dynamic-Huffman-aware modeled proposal described in
[`deflate-dynamic-optimal-refinement.md`](deflate-dynamic-optimal-refinement.md).
This follow-up changes only how the two solves obtain their match candidates
and scratch memory. `lz77.PreparedOptimal` builds one compact predecessor index
for the borrowed input, retains the DP and token capacities, and then runs two
complete, independent shortest-path solves over that immutable index.

Raw, zlib and gzip retain the established complete-wire arbitration. The seed
and modeled token streams, stored/fixed/dynamic selection, wrapper checksums,
strict-shorter replacement rule, eligible levels, input-size limits and all
excluded paths are unchanged.

## Industry implementation study

The design follows an invariant used by mature near-optimal DEFLATE encoders,
without copying their storage layouts:

- Zopfli 1.0.3 separates match discovery from the repeated `GetBestLengths`
  cost solves. Its longest-match cache can replay length/distance frontiers
  across statistics-driven iterations, while every iteration recomputes the
  path and retains the best complete block cost.
- libdeflate 1.26 (`92e6a0db`) fills a binary-tree `match_cache` once per block,
  then calls `deflate_find_min_cost_path()` repeatedly with updated Huffman
  costs. It separately evaluates true dynamic cost, a static-tree solution and
  literal-only output before flushing the winner.
- Vort already has deterministic bounded hash-chain search and a compact
  predecessor representation. Reusing that immutable representation preserves
  Vort's exact candidate order and tie behavior; materializing a new
  libdeflate-style frontier would add another representation and a larger
  change surface. Both DP passes therefore still rewrite every cost, step and
  token choice.

The public prepared owner explicitly borrows the input and owns only its
workspace. Direct tests compare its fixed and modeled plans with the two
independent allocating APIs, including exact tokens and statistics, and sweep
every allocation failure.

## Ordinary A/B evidence

The frozen baseline is `803834d3`, which already contains the refinement. The
candidate changes only `src/lz77.zig` and `src/deflate.zig`. Separate
ReleaseFast executables ran on logical CPU 2 of an Intel Core i7-10700K. The
matrix contains all twelve Silesia files at 4, 16 and 64 KiB prefixes. The
64 KiB inputs are 65,536 bytes and intentionally exercise the unchanged side
of the 65,535-byte production cap.

| Mode | All 36 | 4 KiB | 16 KiB | 64 KiB control | Worst |
| --- | ---: | ---: | ---: | ---: | ---: |
| named `best` / level 9 | `0.945438` | `0.922432` | `0.915492` | `1.000713` | `1.013408` |
| numeric level 8 | `0.945764` | `0.920620` | `0.915784` | `1.003400` | `1.012798` |

Each number is candidate time divided by baseline time. Level 9 uses five
order-alternating process sweeps with seven timed encodes after an untimed
warmup. Level 8 uses five sweeps with five timed encodes. All 72 case-level
size comparisons tie, so the speedup changes no selected member.

## Requested heap and RSS

The allocator probe excludes the caller-owned input, includes the returned raw
wire, and verifies zero live requested bytes after the caller frees it.

| Level / input | Peak requested bytes | Cumulative requested bytes | Successful allocations |
| --- | ---: | ---: | ---: |
| level 9, `nci-16384` | `1,025,646 -> 729,104` (`-28.9%`) | `1,732,973 -> 788,625` (`-54.5%`) | `19 -> 14` |
| level 9, `mr-4096` | `623,147 -> 400,274` (`-35.8%`) | `998,993 -> 460,149` (`-53.9%`) | `19 -> 14` |
| level 9, `xml-65536` control | `2,009,084 -> 2,009,084` | `2,868,034 -> 2,868,034` | `15 -> 15` |

Levels 8 and 9 have the same peak results on these inputs. Five alternating
`/usr/bin/time -v` processes for `nci-16384` report median maximum RSS moving
from 3,900 to 3,720 KiB (`-4.6%`); the raw samples span 3,896...3,900 KiB and
3,712...3,720 KiB respectively. Requested-byte accounting is the primary heap
evidence; RSS is only a process-level corroboration.

## Compatibility and validation

The baseline and candidate each emitted levels 8 and 9 through raw, zlib and
gzip for all 36 inputs. All 216 corresponding wire lengths and SHA-256 values
match exactly, and Python's system zlib 1.2.11 independently decodes every
stream to the input hash.

Debug and ReleaseFast each pass the complete 551-test DEFLATE unit, including
prepared equivalence and allocation-failure coverage. The focused x86 target,
Python-zlib differential, parameter/partial-flush/sync-recovery interop and
incremental encode gate also pass. Project and Wasm results are recorded with
the archived command output for this epoch.

This establishes an exact-wire speed and memory improvement for the current
one-round, one-shot refinement boundary. It does not establish DEFLATE-wide
leadership, does not add more refinement rounds, and does not change
dictionary, split, incremental or inputs above 65,535 bytes. Raw samples,
wrapper hashes, memory measurements, source overlay and replay commands are in
[`data/deflate-prepared-optimal-20261030/`](data/deflate-prepared-optimal-20261030/).

The subsequent
[`prepared-index lifetime screen`](deflate-prepared-head-lifetime.md) releases
the build-only hash head before allocating DP state, further reducing peak
memory and improving the ordinary 4 KiB path without changing any wire.
