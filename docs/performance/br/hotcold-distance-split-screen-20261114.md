# Brotli distance hot/cold split screen, 2026-11-14

Status: rejected before adoption. No production source changed; the prototype
lived on a temporary branch, was measured, and was reverted. This note
preserves the codegen and paired A/B evidence so the direction is not
retried in the same form.

## Prototype

`readMinimalDistance` was split into an inlined steady-state path and a
`noinline readMinimalDistanceCold` complete decoder. The hot branch handled,
without a call frame: implicit distance, no pending block switch, inline
tree, prepared lookup already built, non-null nine-bit root hit, short or
regular staging. Every other condition (pending switch, packed-tier tree,
lazy prepared build, long-code fallback) jumped to the cold root before any
state mutation, keeping behavior bit-identical.

Correctness held: the full `zig build test-br` suite passed
(1598 pass, 1 skipped, zero failures) on the prototype.

## Codegen comparison (ReleaseFast, skylake)

| Metric | Baseline | Hot/cold prototype |
| --- | ---: | ---: |
| Generic wide10 payload text | 4,123 B | 4,621 B (+12%) |
| Payload stack frame | 312 B | 488 B (+56%) |
| rbp/rsp-relative accesses | 124 | 171 |
| Per-distance call in hot loop | `readMinimalDistance` (every explicit distance) | one cold call on the ~4.5% non-steady cases |

The split removed the per-match call as intended, but duplicated the full
decode sequence (context load, tree stride, prepared peek, short/regular
staging) inside the payload. Register pressure rose enough to grow the frame
by 176 bytes and add 47 stack accesses — the same layout-perturbation
mechanism that defeated the 2026-11-12 semantic kernel and the cached-pointer
screen. A smaller hot function did not translate into a smaller hot loop.

## Paired A/B (24 rows, three independent rounds)

Harness: pinned CPU 15, 40 iterations, four rounds, two warmup pairs,
baseline probe at `eda32508` versus prototype probe, same fixture bytes and
reference libraries.

| Round | Geomean (base/cand) | Rows below 0.98 |
| --- | ---: | ---: |
| 1 | 0.998771 | 2 |
| 2 | 0.999537 | 1 |
| 3 | 0.995937 | 2 |

Mean geomean 0.99808 — no aggregate gain. Recurring weak rows (at least one
sub-0.985 reading every round) included samba 64K q11 (0.9799 / 0.9937 /
0.9776), xml 64K q11 (0.9940 / 0.9727 / 0.9942), dickens 1M q11
(0.9972 / 0.9857 / 0.9840) and reymont 1M q6 (0.9907 / 1.0008 / 0.9791).
The cliff row itself (mozilla full q11) was not part of this 64K/1M screen
matrix, but the control-floor breaches on unrelated rows alone block
adoption under the project gate regardless.

## Why it fails

The measured 95.5% prepared-hit rate suggested a hot/cold split should win,
but hit rate is not the same as loop cost: the surviving hot path still
carries the block-state, reader reservoir, ring and literal bookkeeping
that force spills. Moving cold code out widened the hot function and
increased spilling, which offset the saved call frame. This is the sixth
micro/structural variant whose net effect is dominated by code layout
changes rather than the instruction it targeted.

## Consequence

Do not retry splitting `readMinimalDistance` by call boundaries alone. Any
future candidate must first reduce the live state the payload loop keeps
across the whole command (the 488-byte frame is the symptom), for example by
narrowing what the distance stage keeps live rather than relocating its cold
branches. The diagnostic counters and codegen audit committed earlier remain
valid and are the evidence base for that redesign.
