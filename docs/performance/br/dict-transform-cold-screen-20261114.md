# Brotli static-dictionary scratch cold-path screen, 2026-11-14

Status: rejected before adoption. The redesign was lifetime-safe and passed
the full test suite, but paired A/B showed no aggregate gain and recurring
sub-0.98 control rows, so it was reverted. No production source changed on
main; this note records the codegen and screen evidence.

## Redesign

The payload's `transformed_dictionary_word[64]` scratch is loop-live but used
by only 0.262% of applied copies on mozilla full q11. The change:

- added `noinline dictionary_copy.appendStaticTransform`, which owns its own
  64-byte scratch, calls `static_dictionary.transform`, validates and writes
  straight into the output buffer;
- added `noinline appendMinimalStaticDictionaryWord` for the wire-distance
  bounds check and output-end check;
- replaced all eleven payload dictionary blocks with a call to that helper
  and deleted the ten payload-local 64-byte scratch declarations.

Lifetime is sound because every transformed word is consumed inside the
callee before its scratch frame ends; transform-zero still borrows the
embedded static slice. This fixes the dangling-slice problem that rejected
the earlier direct relocation attempt.

## Correctness and codegen

- Full `zig build test-br`: 1598 pass, 1 skipped, zero failures.
- Dictionary-focused tests: 308/308.

| Generic wide10 payload metric | Baseline | Redesign |
| --- | ---: | ---: |
| Stack frame | 312 B | 264 B (-15%) |
| Distinct rbp slots | 41 | 40 |
| Text | 4,123 B | 2,582 B (-37%) |
| Stack accesses | 124 | 129 |

The frame shrank by 48 bytes as intended, but stack accesses rose by five:
the cold call still needs arguments spilled at the boundary, and removing
the buffer let the compiler re-layout surrounding temporaries. The callee
correctly carries the 64-byte scratch (`sub $0x40`) only on dictionary
copies.

## Paired A/B (24 rows, three rounds, CPU 15 pinned)

| Round | Geomean (base/cand) | Rows below 0.98 |
| --- | ---: | ---: |
| 1 | 0.999574 | 2 |
| 2 | 0.996065 | 3 |
| 3 | 1.000784 | 0 |

Mean geomean 0.99881 — no aggregate improvement. Recurring weak rows
included reymont 64K q6 (0.9246 / 0.9780 / 1.0016), samba 64K q6
(1.0043 / 0.9755 / 1.0110), xml 1M q6 (0.9727 / 0.9905 / 0.9861) and
ooffice 64K q11 (1.0183 / 0.9785 / 0.9944). The spread across rounds shows
host noise dominating any frame-size effect, but the gate is explicit:
adoption requires no control row below 0.98, and rounds 1 and 2 breach it.

## Why a 48-byte frame win does not translate to throughput

The removed scratch is never touched on the 99.74% non-dictionary
iterations, so it costs no dynamic loads in the hot loop — it only reserves
stack address space. Shrinking the frame changes compiler layout and
instruction placement (text fell 37%), which perturbs unrelated rows by
several percent in both directions, exactly the mechanism seen in the
cached-pointer and hot/cold-split screens. Static frame size is not a
reliable proxy for hot-loop cost when the reserved memory is cold.

## Consequence

This is the seventh rejected structural variant. Payload stack-frame
shrinkage via cold-path relocation is now exhausted as a standalone lever:
both distance-call splitting and dictionary-scratch relocation move cold
state out without improving the measured steady state. Future decode work
should target work actually executed per common command (the prepared
lookup/reader staging sequence), or switch codec before further local
layout edits. The diagnostic instrumentation and audit docs committed
earlier remain the evidence base.
