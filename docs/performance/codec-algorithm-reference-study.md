# Codec algorithm reference study, 2026-10-31

The current gaps require changes to the search algorithms and entropy models.
At the start of this study, the matched Zstd HQ time gap was roughly 48x–62x.
The adopted local-optimal parser reduces that gap substantially; the subsequent
matcher epoch still records about 3.13x–4.57x reference time on its larger inputs.
This study separates source-level findings
from measured prototype results. Local checkouts are identified below; no
throughput benefit is inferred from copying a reference design.

## Zstd: reduce the search graph

Reference: zstd commit `01b7154f1172432f8abe9b3bb9909e14a1176b7d`, especially
`lib/compress/zstd_opt.c:1077–1420` and its BT matcher at lines 598–817.
The matched benchmark explicitly selects btopt/btultra2, depth64, nice64,
minimum3 and equal frame flags. Hash/chain defaults and internal algorithms
still differ between implementations.

The reference keeps one optimal stretch per input position. Its score includes
the pending literal-length cost; extending a literal adjusts that cost by
`LL(new)-LL(old)`, which may be negative. A single-path replacement for Vort's
8/16-state beam therefore needs a different cost invariant, not only a smaller
beam width. Ultra also rescues a previous match followed by one literal when
LL1 is cheaper than LL0.

The reference only starts local DP after finding a match and advances to a
dynamic last reachable endpoint. The 4096-position table is a capacity bound.
Each strictly longer matcher candidate covers only lengths newly introduced
by that candidate. Long repeats can bypass BT search; a match beyond the
sufficient length terminates local parsing and triggers traceback. Its BT
index also skips insertion in selected repetitive regions.

Vort already produces a strictly increasing ordinary match frontier, but the
original beam re-enumerates short lengths for every candidate and traverses a
fixed horizon. Its full matcher still inserts each skipped position. These
costs multiplied rather than representing a single slow kernel; the new
local-optimal engine addresses the graph and termination costs separately.

The isolated experiment in `/tmp/vort-zstd-adaptive-frontier-20261031` tests
single-path pending-LL scoring, incremental length ranges and adaptive local
termination as separate variants. The first prototype retains the existing
fully indexing matcher; sparse BT insertion is a separate design step.
Finite and unlimited price quotas must run the same new graph. Whole-block and
complete-length modes retain their explicit original coverage contracts.
New frames may differ, so acceptance depends on interoperable decoding,
deterministic output, ratio/time/memory measurements and resource semantics.
Cold btultra2 still performs a statistics pass and a refined pass; unvisited
positions cannot be replayed as empty entries from the old dense frontier cache.

## Brotli: distinguish the actual encoding paths

Reference: Brotli commit `558fc647cdaf391228d614ca85f711e02e4e583b`, especially
`c/enc/backward_references_hq.c`, `literal_cost.c`,
`hash_to_binary_tree_inc.h` and `metablock.c`.

The current q10/q11 64 KiB reference matrix calls
`encodePlannedStreamWithOptionsAlloc` with `.quality` and `.mode`, and leaves
`.hq` null. It uses the default quality pipeline, which already enables
literal contexts, clustering, joint literal planning and symbol splits.
Findings about the separate explicit HQ engine must not be used to explain
this default matrix.

In the default pipeline, q10 uses lazy proposals, fixed-Huffman proxy optimal
parsing and a second parse under global separable entropy-feedback costs.
Those costs do not represent the final context/split plan, command pairings or
distance cache. At 64 KiB, q11 inherits the q10 pipeline but its own optimal
budget is limited to 32 KiB; full command-state proposals default to at most
8 KiB. A unified prepared entropy plan and command-cost parser should replace
repeated proxy proposals with work directed at the actual final format costs.

One isolated candidate combines the existing joint literal plan with already
computed command/distance splits. The current joint writer passes null for
those splits even when both plans are available. Full-wire arbitration can
test this additional entropy combination without a compressed-size regression;
the extra planning/serialization cost must still be measured.

The separate explicit HQ engine has additional gaps: its wire path does not
enable the existing context/split candidates, initial prices are largely
uniform, and its per-position beam repeatedly searches and prices candidates.
The reference uses a compact command-start queue ranked by cost minus literal
prefix cost, only a few active starts, incremental copy-length frontiers,
minimum useful-length bounds and selected long-match skips. q11 shares compact
ordinary matching evidence across both passes. Long-match indexing is sparse
with a dense tail. A Zig-native command-start parser and prepared entropy plan
should address these together, while charging retained evidence to memory caps.

## Deflate: generate compact matching evidence at its source

Reference: libdeflate 1.26 commit
`92e6a0db9fa848d742f9eb286c92afc60f2c3dda`, especially
`lib/deflate_compress.c:3593–3845` and `lib/bt_matchfinder.h`.

The near-optimal encoder gathers an increasing-length BT frontier once and
stores compact length/offset evidence for repeated cost solves. It omits
outgoing match evidence inside sufficiently long copies while maintaining the
needed index and literal edges. Its adaptive minimum match length influences
statistics, not the legal lengths priced by near-optimal DP. These are distinct
work/quality policies and should not be conflated.

Vort's existing best-level hash-chain search can examine roughly100–160 valid
candidates per byte on some 16 KiB prefixes. The earlier cache and cost-class
screens added bookkeeping alongside that dense search and regressed. A new
design should generate a compact frontier in the matcher, with 32 KiB history,
RFC258 maximum match length and explicit dictionary/window generations; it
should not materialize the entire old candidate stream. The same evidence can
serve fixed and modeled solves, including future streaming/multi-block work.

## Measured outcome of this study

The Zstd local-optimal/repeated-segment design is adopted with an explicit
beam alternative. [Its evidence](zstd-local-optimal.md) records roughly16x
all-twelve-file64KiB improvement and separate current-source/reference gates,
including the size tradeoffs. The additional Brotli entropy combination
improves some mixed synthetic inputs but leaves the real-file outputs unchanged
with added time, so it remains unadopted research evidence in the
[joint/symbol screen](brotli-joint-symbol-screen.md).

The [Deflate BT increment](deflate-bt-optimal.md) adopts three-byte BT matching,
per-distance-price-class maxima and a 258-length coverage policy, with complete
64 KiB input support. Three-byte records and checked `u32` reverse costs lower
the cached path's requested memory. Final-source level-9 time ratios versus
the preceding encoder are `0.630066/0.589154/0.456402/0.713807` across all twelve
4 KiB/16 KiB/65535/65536-byte cases; size ratios are
`0.999910/0.998569/0.997163/0.985241`. Pinned libdeflate level 12 still takes
roughly half the live time at similar sizes. Cache-free forward replay, exact
price intervals, lower coverage thresholds and initial scalar/word caches
retain their independent results and resource regressions. Full-file,
dictionary/streaming graphs and stronger entropy convergence remain work.

The subsequent [matcher sizing/index increment](zstd-adaptive-matcher.md)
isolates sized tables, sparse indexing, their combination and cold two-pass
reuse. Only smaller source/window intersections use the new matcher; retained
prefixes keep dense indexing. Real 4 KiB btultra2 time falls 12.4%, 256-byte
prefix time falls 79.9%, and one parser requested peak falls from 552,656 to
30,416 bytes. Larger inputs keep the original matcher and complete wires.
All-source sparse matching and capacity reuse have retained regressions and
remain unadopted. Persistent indexing across blocks and better entropy costs
are still separate algorithm directions.

The subsequent [Brotli command-model study](brotli-command-start-model.md)
implements complete-command endpoint queues with exact recent-distance
representations, actual ordinary Huffman/context costs and finite unseen-symbol
priors. Independent graph/equality oracles cover prices, history, resource
quotas, OOM and native/x86/WASI behavior. New-length frontiers and minimum-cost
bounds reduce graph work, but their full default encoder proposals still take
more time than the preceding encoder, including large control regressions;
none is adopted. Exact split-symbol projection/prepared emission and far-only
incremental admission fixes are adopted and validated with full family gates
and fixed Brotli1.2.0 decoding. The next bounded design is complete bit counting
and retained entropy plans for existing fixed-symbol-split literal variants,
with only the winning wire emitted; current Prepared types cover narrower
unsplit cases.

## Evaluation boundary

These are algorithm hypotheses. A source resemblance does not establish
quality or performance parity. Each adopted design needs real/full-file,
repetitive/random, dictionary/history, streaming and platform coverage,
explicit reference versions and settings, and ordinary timings separated from
compilers and codec-validation runs. Safety, checked ownership and interoperable
wire output remain requirements. The industry-best objective remains active.
