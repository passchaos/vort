# Brotli generic wide10 distance codegen audit, 2026-11-14

Status: static audit increment, no production decode change. The audit decides
which structural distance-decode candidate remains credible after five
rejected micro-optimizations, using disassembly of the current
`vort-decode-compare` probe (source at `743db39c`, ReleaseFast, skylake) plus
a new table-space measurement in the distance-shape probe (schema v3).

## What the generic wide10 hot loop actually looks like

The mozilla full q11 cliff row routes 98.65% of its commands through
`processWideExternalLiteralLookupCompressedPayloadNative` (the
`auxiliary_tail_lookups=false` specialization). Codegen facts from the
current binary:

| Symbol | Text bytes | Frame | Notable |
| --- | ---: | ---: | --- |
| generic wide10 payload | 4,123 | 312 B (6 pushes + `sub $0x138`) | 124 rbp/rsp-relative accesses |
| `readMinimalDistance` | 962 | 48 B (5 pushes + `sub $0x28`) | standalone `call` every explicit distance |
| `distancePrefixForDecode` | 2,110 | leaf | inline branch is 5 instructions |
| prepared (small) payload | 2,957 | 856 B (`sub $0x358`) | 135 stack accesses despite cached pointers |
| auxiliary wide10 payload | 5,371 | 376 B | no `readMinimalDistance` call; inlined fixed-9 helper |

### The inline tree resolve is not the cost

On q11 every referenced tree is inline, so `distancePrefixForDecode` takes:
index bounds compare, `<= 63` tier compare, `imul $0xea8` (tree stride),
pointer write, `ret` — five instructions, no stack. The 2 KiB function body
is the cold packed-expansion path (memcpy of a 3 KB PrefixCode), unreachable
on this corpus. Caching the resolved pointer (2026-11-14 screen) removes at
most the imul and one load; the measured parity confirms this was not the
bottleneck.

### The real per-match costs

1. **Call/frame overhead.** Every explicit distance is a `call` to the
   962-byte `readMinimalDistance`, which spills five callee-saved
   registers plus 40 bytes of frame. The caller passes state through stack
   slots (`-0x110(%rbp)` result aggregate, `-0x90(%rbp)` remaining pointer).
2. **Lazy prepared-lookup build.** First use of each inline tree runs a
   512-byte YMM zeroing loop (16 `vmovups`) inside
   `readMinimalDistance` before the 9-bit `prepared_lookup` is usable. This
   is the memset-family weight the profiler attributes to table setup; it
   happens once per tree but there are 534 referenced trees on the cliff row.
3. **Carried header state.** Block type, remaining counter and the
   context-map base are reloaded from the header struct on every match; the
   312-byte payload frame exists because literal and distance bookkeeping
   cannot all stay in registers.
4. The cached-pointer prepared payload proves pointer caching alone does
   not shrink the frame: it still subtracts 856 bytes and touches 135 stack
   slots, because the surrounding state (reader, ring, block switches) is
   unchanged.

## Table-space measurement (schema v3)

A nine-bit internal tail lookup needs 512 bytes of free entry-array space
(`canBuildTailLookup9`). The probe reports this separately from code width
and only for inline-tier trees (packed trees carry no expandable table, so
the two space counts sum to the referenced inline tree count):

| Mozilla full q11 quantity | Trees |
| --- | ---: |
| Referenced distance trees | 534 |
| Referenced inline trees | 463 |
| Referenced packed-tier trees | 71 |
| Max code width > 9 bits (all tiers) | 361 (67.6%) |
| Inline trees with tail-9 table space | 463 (100% of inline) |
| Inline trees lacking tail-9 space | 0 |

Across all 49 frame runs every referenced inline tree has tail-9 table
space; the earlier 71-tree "ineligible" reading was an accounting bug that
folded packed trees into the inline count, caught by the new unit-test
reconciliation assertion. The true binding constraint is therefore code
width, not table space: the 361 wide trees (67.6%) can host a nine-bit tail
lookup structurally, but symbols longer than nine bits still miss it and
take the canonical long-code fallback. Width and space are independent
properties and this corpus is space-unconstrained.

Consequence: an internal tail-9 plane costs no extra allocation on the
inline tier, but it cannot cover the >9-bit symbols that dominate the
cliff row. External `PackedLookup(9)` planes (the 2026-11-12 screen) add
512 KiB for 256 trees and still cannot cover >9-bit codes, which is why
they returned only ~1.05x.

## What this rules out and what remains

Ruled out on codegen/shape evidence:

- Replacing the inline tree pointer load (five instructions) — parity result
  already observed, mechanism now confirmed.
- Any nine-bit-only lookup plane — 67.6% of cliff-row trees exceed nine bits
  and 13.3% lack table space; full coverage would require wide external
  planes whose 2026-11-12 cost/benefit already failed.
- A context-three-only kernel — 29% of cliff-row copies use contexts 0-2.

The only structurally credible direction is a **hot/cold split of distance
resolution inside the generic wide10 payload**: an inlined fast path for the
steady state (no block switch pending, inline tier, prepared-lookup hit,
short/regular staging) with block switches, lazy lookup builds and long-code
fallbacks moved behind noinline cold roots. This attacks the actual costs
(call frame, register spills, lazy build) rather than one pointer load, and
mirrors the layout the auxiliary payloads already use successfully.

Hard constraints for that candidate:

- The 2026-11-12 semantic kernel failed when cold expansion was inlined into
  the payload (5.6 KB text, 9.8 KB stack). Cold roots must stay noinline.
- Packed-tier q6 frames and every >9-bit symbol must retain existing
  fallbacks; the fast path needs a cheap eligibility branch.
- Every prior layout change moved unrelated rows by several percent. A/B
  evidence with the 0.98x control floor is mandatory; the audit does not
  pre-claim a win.

## Artifacts

- Disassembly notes retained under `/tmp/vort-br-codegen-20261114/`
  (ephemeral; addresses and sizes reproduced in this note).
- v3 JSON for 49 frame runs and `aggregate.csv` with the
  `tail9_space_eligible` / `tail9_space_ineligible` columns are in
  `docs/performance/br/distance-shape-20261114/`.
- Production decode paths are unchanged; the only code additions are
  diagnostic fields and probe output.
agnostic fields and probe output.
