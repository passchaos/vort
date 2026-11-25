# Bounded Brotli recent-match evidence correctness prototype

Status: proof passed; encoder optimization is **not adopted**. Main encoder
source remains unchanged. Base source is
`b1656a4e338833064b0ba5fb47166b96f218b73c`, whose parser matches the current
mainline parser before applying this isolated patch.

The [source audit](../../brotli-recent-match-evidence-20261123.md) identifies
repeated recent-distance length probes between beam states. This prototype
caches actual-distance byte facts within one immutable input/parser call,
reuses positive verified spans and extends capped tails. Failed prefixes are
reused only at compatible identical position/minimum/effective-limit queries.
It preserves transitions, order, ties, prices, recent rings and logical budget
charges; ordinary candidate caching is unchanged.

Debug and ReleaseSafe each pass 25 selected tests with:

- 65,400 scalar/cached match-query comparisons, including minimum 2/3/4,
  maximums through 258, failed prefixes, EOF, capped spans, skipped/backward
  positions and eviction;
- 699 exact parser token/command and statistic comparisons for beams 2/4/8,
  starting rings and learned/tied/varied models, including 12 pairs at 8 KiB;
- identical allocator failure behavior at indices 0--11, request counts,
  live/peak requested heap and exact-cap/cap-minus-one behavior.

The parser's existing minimum-two rejection is unchanged; the helper separately
tests minimum-two byte facts. The automatic owners occupy 560/1072/2096 bytes
on the x86-64 proof host for beams 2/4/8. No additional heap request is made.
These sizes are **not** generated stack-peak or RSS measurements.

[`proof-source-and-results.tar.xz`](proof-source-and-results.tar.xz) contains
the modified parser, helper, two dedicated test modules, exact baseline parser,
patch, provenance, final logs and earlier fixture/wrapper diagnostics.
[`proof-results.json`](proof-results.json) and
[`source-sha256.json`](source-sha256.json) bind final exit codes and hashes.
The patch applies to the current main parser, and the final log hashes were
verified before archiving.

For reproduction, start an isolated copy of the base revision and apply the
archive's `proof-artifacts/prototype.patch`. Run the direct Zig commands in the
archived README; they avoid the snapshot build wrapper's unrelated missing
`../vail/archive_crypto` dependency. Direct parser/command tests succeeded in
both modes. Complete encoder wire materialization and performance are outside
this proof.

Before timing/adoption, review the direct-map collision behavior: for beam 2,
distances 32/64/96 share one slot under the current XOR-fold hash. Eviction
preserves correctness but may lose useful spans. The prototype also records
six diagnostic counters; generated code must establish their timing cost.
Measure actual stack and text growth, complete q10/q11 wire identity and full
API interleaved speed/ratio/memory controls on a quiet host. The default 8 KiB
control and explicit 64/32 KiB ceiling cases remain distinct measurement rows.
No throughput, ratio or industry-leadership claim follows from this proof.
