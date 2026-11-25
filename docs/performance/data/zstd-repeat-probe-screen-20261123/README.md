# Zstd repeat-probe pruning screen, 2026-11-23

All three variants were rejected and the production matcher was restored to
`bdb6368b3ab52e57f2588cdfc16cb0d453b63a1d`. This is an early whole-frame
screen, not a current industry ranking or a fixed-host adoption campaign.

The previous [encoder handoff](../zstd-encode-baseline-20261123/README.md)
identified double-fast match evaluation as a shared cost at levels 1--3.
These experiments tried to avoid evaluating repeat matches that cannot change
the existing candidate decision. None changed the measured wire output, but
none passed the 3% overall improvement and 0.98x control floor.

| Variant | Level 1 | Level 2 | Level 3 | All 12 rows | Rows below 0.98x |
| --- | ---: | ---: | ---: | ---: | ---: |
| Repcode rank before full rep0 probe | 1.0041x | 1.0311x | 0.9858x | 1.0068x | 2 |
| Rank plus replacement-length endpoint check | 0.9902x | 0.9732x | 1.0207x | 0.9945x | 5 |
| Maximum-length continuation endpoint check | 0.9802x | 0.9935x | 1.0266x | 0.9999x | 1 |

The first variant tests repcode rank before computing a rep0 match length.
The second also rejects replacement candidates whose byte at the minimum
winning length differs. That minimum is the current best length minus one,
with the existing four-byte match minimum retained. Successful probes return
the complete exact length. The third changes only the anchor continuation
probe: it requires a complete `max_match` match and checks that endpoint
before extending. Both the token and compact sequence-record parser were
changed together. The separate endpoint helper adds another call/control-flow
path; these measurements do not prove that reduced extension work outweighs
its cost. The isolated level-2 rank win does not justify adopting the variant
when the common levels fail the controls.

## Evidence scope

- Intel Core i7-10700K, Linux x86-64 GNU, Zig 0.16.0 ReleaseFast,
  `skylake+pku+sgx`, one codec thread, inherited affinity 0--15, no pinning.
- The ordinary allocating `encodeFrameWithLevelAlloc` lifecycle is identical
  before and after. Reference samples use the explicit system
  `/usr/lib/x86_64-linux-gnu/libzstd.so.1.4.8`, version 1.4.8; the decision
  compares Vort before/after, not nominal-level parity with libzstd.
- Four Silesia 64 KiB prefixes: `dickens`, `mozilla`, `nci`, `x-ray`, levels
  1/2/3. Each row has three alternating baseline/variant process pairs, with
  10 encode iterations and five alternating Vort/reference rounds per process.
  There were no simultaneous builds during the paired samples.
- Each process first checks Vort output with libzstd and reference output with
  Vort. Every paired row checks both wire hashes and sizes. Endpoint and
  continuation variants additionally passed 36 such checks over all twelve
  128 KiB Silesia prefixes at levels 1/2/3.
- A row's speed ratio is the geometric mean of the three paired baseline
  median/variant median ratios. The table aggregates row ratios geometrically.
  These short, unpinned screens do not carry confidence intervals or memory/RSS
  measurements. The 24-row 64 KiB/1 MiB campaign was not run because each
  variant already failed the preliminary controls.

[`manifest.json`](manifest.json) binds the base revision, baseline/variant
executable hashes, archived source hashes, every row ratio and level summaries.
[`raw-samples.tar.xz`](raw-samples.tar.xz) retains 54 paired CSV/JSON process
reports and 12 CSV/JSON wide-wire process reports, including raw round times,
input/wire hashes, public settings, executable hashes and command lines.
The archive also includes the derived summaries and the two 36-row identity
receipts. Reference file hashes identify the requested file; the existing
report does not attest its transitive loader dependencies.

## Reproduction

Start from the base revision above and build `run-zstd-encode-bench` with the
same Zig/target. Preserve its compiled executable as `baseline` beside the
scripts. Apply one of `rank-first.patch`, `endpoint.patch` or
`continuation.patch` to the base source, rather than stacking patches. For the
endpoint and continuation variants, also copy `repeat_probe.endpoint.zig` to
`src/zstd/match/double_fast/repeat_probe.zig`. Build the same step again and
preserve the executable as `variant`. The two `*.before.zig` files preserve
the exact changed baseline modules; the rest of the source is identified by
the base revision.

With the local Silesia files at the path recorded in the scripts:

```sh
python3 screen.py paired-screen 3
python3 wire_screen.py wide-wire-screen
```

Raw commands for every original invocation are in the archived provenance.
Future matcher work should address shared match analysis or repeated parser
work with whole-operation evidence. These three checks and the earlier explicit
rep0 cache should not be retried as assumed wins.
