# Zstd short-edge batching: rejected native experiments

This screen starts from the preceding repeated-offset choice optimization and
fixed-window shipping source. Eight isolated prototypes were implemented and
measured, but none supplied a satisfactory overall ordinary-API speed benefit.
The live library is unchanged. This is negative engineering evidence, not a
new codec optimization or an industry-performance claim.

## Candidates and correctness

The first candidate uses a validated ML lower bound to reject four short edges
when that bound is strictly greater than every destination row's final cost.
Each edge is inside both the original short loop and length 3...34, where ML
extra bits are zero. The original maximum edge is priced first, preserving
validation, coordinate checks and the largest considered length. Skipped
edges reserve their original logical allowance. Generic contexts, finite
limits and invalid/near-overflow inputs retain their original path.

The next variants use per-four-length bounds and a deterministic gate after
position 64: the first 128 probes must include at least 32 hits. Independent
tests preserve nodes, tags, spills, entropy state, logical allowance, finite
quota prefixes and non-price profile fields. Boundary controls demonstrate
why the original loop endpoint, length-35 exclusion and strict comparison are
necessary. Native Debug/ReleaseFast pass for the original, grouped and gated
implementations; gated probe freeze/reset and 31/32-hit thresholds also pass.

Two vector prototypes calculate four exact sequence totals, account for all
four original evaluations/admissions and insert in the original length order.
All profile fields remain identical. The vector source passes 43,848 actual
four-node price comparisons, saturation/admission tests, 7,444 full Context
comparisons, 2,820 finite prefixes and 69 fallbacks in native Debug/ReleaseFast.
Long-match and outlined variants change only the batching threshold and body
placement. An initial runtime vector-index compilation error in the loop
variant was corrected by explicitly converting to a four-element array.

The final prototype applies the existing strict target-cost rejection rule to
literal insertion in both DP paths. Complete checked node construction occurs
first; equal costs still enter the original tag/key comparison. Independent
native tests pass 2,592 ordered row/tag cases, 84 real parser plans across
three strategies, whole/complete modes and dictionary/history sources,
96 finite N/N-1 cases, 144 requested-memory boundaries and resource-overflow
checks. Plan fields, profiles, heap bytes and errors remain identical.

## Ordinary measurements

Independent Zig 0.16.0 LLVM ReleaseFast executables run one codec thread on
CPU 2 of an Intel i7-10700K. All five campaigns use three alternating process
sweeps, two Vort/libzstd rounds per process, and exact frozen 4/16 KiB Silesia,
trained-dictionary and synthetic inputs. Repetition batches 100 calls and
random input batches 20. Input setup, verification and profiles stay outside
ordinary allocating encode/free timing. Compilers and codec validation finish
before each campaign. Local libzstd 1.6.0 is identified in every raw report.

| Prototype | Real 4 KiB btultra2 | Real 16 KiB btultra2 | Real 4 KiB btopt | Periodic btultra2 |
| --- | ---: | ---: | ---: | ---: |
| Global short-price bound, first screen | `1.009302` | `1.000149` | `1.046692` | `1.033237` |
| Group bounds, four-way screen | `1.016872` | `1.006863` | `1.026104` | `1.047484` |
| Group bounds plus gate | `1.054856` | `1.038630` | `1.040657` | `1.027952` |
| Four exact vector prices | `0.994918` | `1.002266` | `1.040754` | `0.914478` |
| Array loop over vector prices | `1.006576` | `0.993888` | `1.045601` | `0.913976` |
| Long-match vector gate | `1.059999` | `1.061394` | `1.036954` | `0.949347` |
| Long-match outlined vector helper | `1.044395` | `1.032323` | `1.036918` | `0.947024` |
| Literal strict-cost guard | `0.993733` | `0.983622` | `1.012258` | `0.991476` |

The global bound reduces Mozilla4K physical prices from 8,314,457 to 5,771,737
but saves none of the periodic btultra2 prices. Local bounds reduce more
real-file work without overcoming probe overhead. Vector pricing improves
periodic input by about 7%-9%, while ordinary btopt files regress. Literal
filtering supplies a small larger-file gain with regressions in other controls.
Every complete wire, requested/resolved setting and logical allowance agrees.
Pure-repetition timings vary despite zero priced edges; those rows are retained
and are not attributed to price savings. Point estimates from different
campaigns are not chained or treated as statistical significance.

## Decision and evidence

All eight prototypes are rejected for production. The source archive,
ordinary process JSON/CSV, binary hashes, native oracle code/logs/terminals,
guard controls and independent reducer are retained in
[`data/zstd-short-batch-screen-20261031/`](data/zstd-short-batch-screen-20261031/).
The frozen audit verifies all 286 baseline/live codec files are unchanged and
recomputes 80 case rows across five campaigns. No full-repository runtime or
cross-platform performance result is inferred from these isolated native
experiments.

Further work should change the representation or generation of rejected work,
then remeasure the actual parent implementation. Scanning row costs beside
the existing dense loop or expanding inline vector bodies is insufficient.
Brotli command/context preparation and Deflate multi-block planning remain
priorities within the full compression objective.
