# Brotli match-evidence screen and modeled-prefix follow-up

The bounded exact match cache is rejected. Three independent programs compare
the current encoder, the same helper layout without reuse, and actual reuse.
The serial three-sweep q10/q11 campaign uses Dickens, MR and NCI at 16/32 KiB,
with fifteen ordinary samples per side and row. Complete input, wire and
settings identities agree.

| Scope | Reuse / baseline time | Layout / baseline time |
| --- | ---: | ---: |
| q10 | `1.042078` | `1.002215` |
| q11 | `1.050528` | `1.002227` |
| Combined | `1.046294` | `1.002221` |

The cache preserves every prefix-admitted distance. Fixed-price prefix-bound
rejections retain an unknown-length marker; modeled replay recomputes those
lengths. Partial rows rewind their tentative entries and use the independent
original search. Seed DP/hash capacity is released, and evidence is released
before modeled command/wire construction. Finite total-heap limits disable
optional cache allocation before requesting memory.

Independent unchanged-parser comparisons pass 384 fixed/modeled pairs,
including 50,929 retained unknown markers and 32,890 fallback rows. Native
allocation-failure and retry tests also pass. These establish exactness rather
than a performance benefit.

The diagnostic exposes the limiting factor. Four entries per input byte plus
eight row bytes cost 393,216/786,432 requested bytes at 16/32 KiB. The retained
known lengths eliminate only `0.23%–11.77%` of second-pass length requests.
Most records are unknown, and dense MR/NCI inputs invalidate most rows. Full
q11 NCI 32 KiB evidence would require 19,713,252 bytes. Enlarging the cache is
therefore not adopted.

An initial cache run briefly overlapped a new bound campaign. Those clocks and
the interrupted bound output are retained and explicitly excluded. The numbers
above come from a fresh serialized cache run.

## Modeled-prefix follow-up

The modeled parser can use the same mathematically exact known-prefix price
bound as the fixed parser. A candidate proved to mismatch within a verified
prefix cannot beat the minimum price over lengths through that prefix plus its
distance price. Rejected candidates still consume the original candidate
budget, and they cannot be full-length early stops. Native predecessor layout
is retained separately from bound selection.

An unconditional four-sweep screen preserves all wires/settings but reaches
only `0.990155` combined time and consistently regresses 16 KiB Dickens/MR.
The next isolated candidate gates the bound on input length, normalized
candidate budget and chain depth: at least 32 KiB and `8 * 1024 * 1024`
potential candidate-position visits. It passes scalar oracle, large-parse and
routing contracts. Four serial AB/BA sweeps cover Dickens, MR, NCI, Mozilla,
OOffice and X-ray at 32/64 KiB, with twenty samples per side and row.

| Scope | Gated / baseline time |
| --- | ---: |
| q10, 32 KiB control | `0.998410` |
| q10, 64 KiB | `0.976708` |
| q11, 32 KiB | `0.986426` |
| q11, 64 KiB | `1.002379` |
| Combined | `0.990929` |

All complete input/settings/wire signatures agree. The wider result still does
not justify adoption: q11 64 KiB Dickens/Mozilla/OOffice ratios are
`1.015732/1.014177/1.016184`, each winning only one of four pairs. Those calls
inherit q10's winner before running their remaining quality pipeline, so a
q10 improvement alone cannot prove a q11 improvement. Both modeled-prefix
performance variants remain isolated and are rejected. Further work should
sample the ordinary complete q10/q11 API before changing more match-search
control flow.

Testing also found an existing zero-window model-validation panic: `std.mem.max`
received an empty distance slice. The worktree now treats the unused distance
range as zero, yielding literal-only plans for valid models. Allocating,
reusable and prepared APIs retain validation of invalid price tables. Focused
native Debug/ReleaseFast, x86 and executed Wasm checks pass. The complete live
LZ77 Debug suite passes 94/94 tests. Final public memory and smoke results are
recorded separately in the evidence package.

The public two-version comparison passes all 24 quality/file/size configurations:
complete wires, requested peak and exact-peak limits agree, and the final live
budget is zero. The retained fix also passes 94/94 LZ77 ReleaseFast tests,
66 total-memory tests and the complete wasm32-wasi library compilation.

## Ordinary q10 target refresh

A separate allocating public q10 runner performs 32 OOffice 32 KiB encodes,
checks each complete wire against its startup result and decodes once. No
reference or diagnostic encoder runs in the sampled process. CPU-2 cycles
sampling at 999 Hz records 10,611 events with no lost samples. The exact global
cycle-period shares are `65.7383%` in joint literal-context `chooseAlloc` and
`10.0370%` in its descendant memcpy, totaling `75.7753%`.

The record includes startup decode, allocator/free and loop wire comparison;
other compiler/validation jobs were active on the host. This is a bounded
target-selection profile, not a general timing or competitor claim. The next
optimization should reduce joint-context assignment/scoring work and histogram
copies, then verify it through ordinary q10/q11 calls before adoption.

Current campaign state, comparisons and coverage are in
[`data/brotli-match-evidence-20261030/`](data/brotli-match-evidence-20261030/).
The package retains raw reports, source overlays, identities and an independent
reducer. No performance candidate has been applied to the main worktree.
