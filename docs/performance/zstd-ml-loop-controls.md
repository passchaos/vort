# Zstd sampled ML loop control experiments

The current encoder at `5f38d682` already prices sampled ML range endpoints
with their known symbol. This experiment isolates further loop-control work
without changing endpoint order, first maximum, short exhaustive lengths,
complete mode, prices, budget admission, row tags or output. The full
ten-format functionality/performance goal remains active.

## Skipping the inactive table prefix

btopt visits lower endpoints above its exhaustive cutoff 16 and has no upper
endpoint path. The first possible table entry is code 14, lower/upper 17.
Ultra modes use cutoff 64 and both endpoints; code 39, lower 59/upper 66, is
the first possible entry. All earlier entries fail the original endpoint
predicates. Starting those table slices at 14/39 preserves every visited
length and known symbol, including the upper-66 behavior under a higher
private minimum.

The isolated prototype changes only `search_edges` table slices and enumeration
start. The native candidate function grows from 628 to 644 bytes. Frozen
current-edge contracts pass 7/7 in native Debug/ReleaseFast and actual x86
Debug. An independent trace checker compares 1,572,900 complete ordered
sequences over maximum 1...131075, six minimum values and both cutoffs.
Length order, duplicates and symbol indices agree; the check does not merely
compare final compressed bytes or unordered sets.

| Silesia 4 KiB | btopt candidate/baseline time | btultra2 candidate/baseline time |
| --- | ---: | ---: |
| Dickens | 1.0368 | 0.9879 |
| Mozilla | 0.9825 | 0.9610 |
| MR | 0.7976 | 0.9931 |

Ratios divide median candidate time by median baseline time across two balanced
AB/BA rounds. Dickens btopt is slower in both rounds. MR btopt's second
baseline ordinary call is 11.904 ms compared with 8.164 ms first and a
subsequent independent profiled call of 8.298 ms; the 0.7976 aggregate is not
claimed as a 20% gain. The other ultra rows also include mixed directions.
This prefix-slice implementation is not adopted from these measurements.

## Hoisting the upper-endpoint strategy branch

A separate prototype keeps all 53 entries but selects an inlined sampled-range
helper once per offset choice. Its compile-time mode enables upper endpoints
for ultra and disables them for btopt. Original predicates and order remain;
the function grows from 628 to 740 bytes. This variant has no prefix slicing
and is measured against the same verified baseline binary.

| Silesia 4 KiB | btopt candidate/baseline time | btultra2 candidate/baseline time |
| --- | ---: | ---: |
| Dickens | 0.9724 | 0.9869 |
| Mozilla | 0.9913 | 1.0270 |
| MR | 0.8840 | 0.9650 |

Mozilla btultra2 is slower in both rounds. MR btopt's first baseline call is
10.341 ms and later 7.958 ms; its two paired ratios are 0.7917/1.0038, so the
aggregate does not demonstrate a stable improvement. This code shape also
remains a private unadopted prototype.

## Guarding an entirely inactive ML loop

The third isolated prototype leaves the original full table loop intact but
skips it after the first maximum and short exhaustive edges when
`maximum <= 17` for btopt or `maximum <= 66` for ultra. Those are the smallest
possible ML endpoints, and the original endpoint tests require strict
`length < maximum`. No later candidate edge can be admitted in that range.
Complete mode never executes the guard. The generated candidate function
grows from 628 to 672 bytes.

| Silesia 4 KiB | btopt candidate/baseline time | btultra2 candidate/baseline time |
| --- | ---: | ---: |
| Dickens | 0.9924 | 0.9833 |
| Mozilla | 0.9943 | 0.9694 |
| MR | 1.0805 | 0.9756 |

Dickens results have mixed rounds and Mozilla btopt is near parity. MR btopt's
first candidate ordinary/profile calls are both around 10.1/10.0 ms, versus
7.9/7.9 ms in its next run, while baseline stays around 8.3 ms. Its aggregate
is not corrected or removed; this prototype is also not adopted. All output
and profile fields agree in 24 encodes/48 native decodes. Frozen current-edge
and full ordered-trace contracts pass 7/7 in native Debug/ReleaseFast and x86
Debug, including every guard boundary, model and price allowance. The guard
has its own archive and audit so its timing is not mixed with earlier variants.

## Measurement and exactness

Each screen completes 24 ordinary encodes and 48 native decodes with complete
wire and profile equality. Local libzstd 1.6.0 independently decodes all 72
wire artifacts across the three variants. All other source files are verified
against the same baseline snapshot.

Both experiments use Zig 0.16.0 LLVM ReleaseFast/Skylake with the same ordinary
allocating runner, CPU 2, window log 15, block maximum 32768 and checksums.
Compiler processes start with affinity restricted to CPUs 4/6. Background
records still show system/compiler activity, and no whole-host isolation is
claimed. Input setup, caller frame release, decode and independent diagnostic
encoding are outside the ordinary timer. Generated code is inspected in the
non-FP binaries; no additional timed round is added to select a favorable result.

The [evidence package](data/zstd-ml-loop-controls-20261029/) preserves the exact
shared source, candidate overlays, ordinary commands, identities, raw timings,
profiles, wires and frozen trace contracts. The findings keep small speculative
loop edits from entering the default path without a reproducible speed benefit.
