# DEFLATE adaptive split distribution-drift proposals

The dictionary-free one-shot adaptive encoder now plans each bounded horizon
once, scans that token stream for coarse distribution changes, and exactly
scores at most two drift proposals instead of reparsing every point on the
split grid.

The detector follows libdeflate 1.26's useful invariants:

- one observation per preliminary literal or match;
- eight literal classes from `((literal >> 5) & 6) | (literal & 1)`;
- two match classes split at length 9;
- a distribution check after every 512 new observations;
- integer-scaled L1 drift with the `200 / 512` cutoff, the short-block
  penalty, and the block-length bias.

Vort does not copy libdeflate's direct "detect and emit" policy. A detected
region is only evidence. The detector keeps the two widest changed plaintext
regions, maps each midpoint to the nearest complete token boundary, then maps
that approximate point to Vort's deterministic split lattice. The existing
full-horizon scorer reparses and evaluates both halves with stored, fixed, and
dynamic costs. An unsplit horizon remains the incumbent and exact ties remain
unsplit. If a full horizon has no detected drift, one three-quarter control
point protects small late-block wins that the coarse histogram cannot see.
The existing off-grid entropy heuristic is still scored when distinct.

The evidence plan is freed before any exact candidate reparse, so there is no
new overlapping input-sized owner. Detector state is fixed stack storage:
two ten-entry `u32` histograms and at most four compact `u16` intervals. All
histogram products and sums widen to saturating `u64` arithmetic.

The change is deliberately limited to dictionary-free one-shot adaptive
encoding. Preset-dictionary and incremental encoders keep the established grid
chooser and therefore keep their previous boundary behavior. The complete
adaptive wire is still compared against the complete one-shot wire before it
can be returned.

## Work reduction

For a common default horizon, the previous seven-point grid required one
unsplit plan, two plans for every point, and one final emission plan: sixteen
plans in total. Best-level horizons commonly required thirty-two.

The retained K2 policy requires:

```text
one evidence/unsplit plan
+ at most two prefix/suffix pairs
+ one final emission plan
= at most six plans per drift horizon
```

The distinct entropy heuristic can raise this to eight. A no-drift horizon
uses one three-quarter control and therefore needs four plans. A future owner
handoff can remove the final prefix reparse, but this increment leaves writer
ownership unchanged.

## K selection

K1 missed real boundaries: the 192 KiB screen grew Mozilla by 24 bytes and
Samba by 38 bytes; the 512 KiB screen grew Mozilla by 317 bytes and Samba by
361 bytes. K2 restored all fifteen baseline cases and made 512 KiB Samba 257
bytes smaller. K3 and K4 did not improve the retained aggregate, so K2 is the
smallest sufficient policy in this campaign.

## Ordinary A/B evidence

The baseline is clean `790ea6a3`. Independent ReleaseFast executables ran on
logical CPU 2 of an Intel Core i7-10700K. Each process performed the ordinary
untimed warmup and one timed adaptive-default zlib encode. Case order alternated
between baseline and candidate.

| Scope | Sweeps | Candidate / baseline geomean | Worst case | Baseline bytes | Candidate bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 12 Silesia 192 KiB prefixes | 5 | `0.434366` | `0.561967` | `910,041` | `910,041` |
| Dickens/Mozilla/Samba 512 KiB | 3 | `0.427806` | `0.528662` | `801,878` | `801,621` |

All five 192 KiB sweep geomeans are between `0.433250` and `0.440689`.
All three 512 KiB sweep geomeans are between `0.421549` and `0.430855`.
Every individual size is non-regressive; the 512 KiB gain is entirely Samba.

A separate probe emitted raw, zlib, and gzip streams for all twelve 192 KiB
inputs. System zlib independently decoded all 36 wires to their exact input
SHA-256.

This removes most repeated boundary-search work; it does not close every
DEFLATE gap. The exact split scorer is still history-free and byte-aligned,
incremental scoring still does not model the live writer bit offset, and the
192 KiB aggregate remains 4,261 bytes larger than zlib 1.2.11 level 9. Those
are separate follow-ups rather than claims covered by this result.

Raw timings, commands, executable and source identities, source overlay, exact
wires, and independent decode records are retained in
[`data/deflate-adaptive-split-drift-20261030/`](data/deflate-adaptive-split-drift-20261030/).

## Later bit-state follow-up

The K2 proposal policy remains unchanged, but dictionary-free one-shot scoring
now starts from the live writer bit offset and shares production's exact BTYPE
selector. See
[`deflate-adaptive-bit-state.md`](deflate-adaptive-bit-state.md).
