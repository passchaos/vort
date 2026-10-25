# Zstd winner-aware Huffman cost bound

Date: 2026-10-25. Baseline production revision: `27dcca45`, after the
[medium-alphabet workspace increment](zstd-medium-huffman-profile.md).
The industry-best functionality/performance objective remains incomplete.

The unindexed multi-duplicate finder previously priced every admitted candidate
with a complete fresh Huffman plan. XML and MR 64 KiB candidate stages execute
1,473,017 and 1,039,932 such queries. Their exact-frequency reuse was negligible.
This increment uses a proved lower bound to discard candidates that cannot
update the existing finder winner, preserving hash pairing, match lengths,
candidate limits, legacy literal views and complete selector arbitration.

## Certificate and byte bound

For the last completely priced frequencies `f`, retain total `Rf` and optimal
eleven-bit weighted Huffman cost `Cf`. For current frequencies `g` with the same
nonzero support, let `Rg=sum(g)` and `Dminus=sum(max(f-g,0))`. Every current
feasible code is feasible for `f`, and its lengths are between one and eleven.
Therefore:

```text
OptBits(g) >= max(Rg, Cf + (Rg - Rf) - 10 * Dminus)
```

The certificate owns one bounded frequency snapshot. Checked numerical
envelopes do not prove a caller's scalar is optimal: production publishes only
successful fresh plans from the existing weighted-optimal eleven-bit builder.
Tests compare weighted costs, rather than conflating tied per-symbol lengths.

Each stream has one end bit. Summing their individually rounded sizes is at
least `ceil((bit_bound + stream_count)/8)`; the four-stream jump table adds six
bytes. A fresh serialized tree has at least two bytes. The existing Huffman
header function with compressed size one gives its minimum for the regenerated
length (size zero is invalid). Take the minimum of this relaxed Huffman size
and the exact raw/RLE literal cost, then add the original minimum RLE/predefined
sequence-table cost computed with literal-section bytes zero.

Reject only when that payload bound is greater than the incumbent cost, or
equal with a candidate match no longer than the incumbent. Equal-bound longer
matches still receive complete pricing. The bound applies to one finder
candidate; it is not an outer-family bound for discarding the multi candidate.

## Ownership, errors and shadow validation

Literal preparation and pricing are separate internal operations so the
histogram is updated once before checking the bound. Prepared frequencies and
current stream histograms must describe the same cut; the wrapper consumes
them immediately without another update. Existing unlimited pricing retains
its literal-then-sequence error order. Preparation errors are recorded once,
including injected header failures after histogram admission.

The bounded API returns an exact price or a proof that the candidate cannot
update this finder. This finder already discards pricing errors; the bounded
contract is not an arbitrary Codec error-exact convenience API.

Shadow mode still fully prices every query and verifies `bound <= exact` and
that every potential refusal cannot update the old winner. It deliberately
does not refresh a certificate on a potential refusal, so certificate ages
match the decisions of actual pruning. Tree-cache activity can differ because
shadow still performs the skipped planning; shadow elapsed time is not a
production throughput claim.

Initial source-bound shadow evidence has zero lower-bound violations and
false refusals on both inputs. It preserves prior block hashes, query counts,
selected-match counts and histogram scan work:

| Candidate stage | Queries | Potential refusals | Fresh certificate publications |
| --- | ---: | ---: | ---: |
| XML | 1,473,017 | 1,443,518 | 29,499 |
| MR | 1,039,932 | 1,023,531 | 16,401 |

An initial actual-pruning diagnostic reproduces these refusal/publication
counts and block hashes, with 29,499/16,401 actual Huffman plans. Its
instrumented elapsed values are kept separate from public-API measurements.

## Validation and current public API

The certificate filter passes in native Debug, native ReleaseFast and x86
ReleaseFast. Its tiny independent Kraft enumeration checks 14,742 frequency
pairs; real 256-symbol tests compare FullWidth weighted optima and cover checked
publication, support changes and the 131,072 total limit. The winner filter also
passes those three configurations, covering strict refusal, longer equal-bound
matches, realistic age/refusal state, old finder winners, stream/header
boundaries, support/null/RLE/small fallbacks and injected preparation errors.
The fixed cache is below 8 KiB and introduces no heap allocation.

A five-round fourteen-input public level-3 measurement uses the unchanged full
level policy, frozen 64 KiB prefixes, i7-10700K, ReleaseFast, CPU8 and the explicit
local libzstd 1.6.0 file from checkout `01b7154f`. Input/source/reference/executable
identities remain fixed and no compiler process is observed. All fourteen
Vort/reference frame lengths and SHA-256 values remain unchanged.

| Input | Previous-production median | New median | Version point speedup | New-run reference median |
| --- | ---: | ---: | ---: | ---: |
| XML | 11,838.393 ms | 1,292.707 ms | 9.1578x | 0.093915 ms |
| Source code | 5,045.272 ms | 500.746 ms | 10.0755x | 0.172252 ms |
| MR | No matched five-round `27dcca45` control | 971.941 ms | Not assigned | 0.269758 ms |

The first two old controls are the preceding source-identical production
measurements, in separate version processes; this is not a repeated-process
statistical-significance claim. Historical MR timing is available separately,
but is not substituted for a matched baseline. All fourteen new throughput
rows still trail their reference. Ratio remains 310,437/328,241 total bytes,
with thirteen smaller Vort frames. Explicit reference-file identity is not a
proof of the complete dynamic loader dependency closure.

The complete native ReleaseFast Zstd family passes 1092/1092. Independent
Vort-only resource probes execute the old production and candidate once each
on XML: peak requested heap is 2,561,185 bytes in both, with the same 115
allocations, 51 remaps and all 282 request/free events. Both return the same
5078-byte frame, retain only caller-owned output on return and have zero live
bytes after caller release. Small backing-OOM probes return `OutOfMemory`
with zero live bytes. These are requested-heap/event proofs, not RSS or
competitor memory measurements; no duration was collected by this probe.

The new fourteen-row throughput geometric ratio is 0.00294786x reference,
with zero throughput wins. This leaves a substantial gap despite the local
version improvement. Build verification and post-rebase checks will be appended
after completion. Broader levels, incremental APIs, 1 MiB, ARM64 and symmetric
competitor memory evidence remain open.
