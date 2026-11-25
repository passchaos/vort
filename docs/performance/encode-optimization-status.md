# Encoder optimization status

## 2026-11-25 current allocating-preset checkpoint

The [current 64 KiB checkpoint](modern-encode-refresh-20261125/README.md)
binds source `4a9796b0` to all twelve Silesia files, six declared policies and
408 measured primary pairs. Its complete 72-row cohort gives throughput
ratios to pinned references of 0.39837/0.52638 for raw Deflate L6/L9,
0.09814/0.66500 for public Zstd L3/L19, and 0.01363/0.27483 for Brotli q8/q11.
The Deflate HQ reference is L12. Brotli uses generic/window16, with an explicit
8 KiB command-state cap only on q11. Size tradeoffs and intervals remain
separate in the linked report. The declared 216-row run continues through
1 MiB and actual full files; this checkpoint does not establish those results.

The [measurement contract repair](encoder-evidence-contracts-20261125.md)
eliminates Deflate's independent fastest-round selection and reference
compressor reuse outside the timer. It also aligns Brotli's HQ preflight and
timing options, declares the effective window/HQ mode, and warms both sides
before a numeric-quality round. These are measurement fixes, not codec wins.

## Next measured structural boundary

Current q8 can execute a lazy seed plus four optimal proposals, followed by
context and split candidate families. Static dictionary proposals are already
precomputed, and command-model lifetime reuse is already present. Do not
repeat those completed changes or apply old two-pass/wire-count descriptions
to the current source.

The strongest isolated remaining boundary is the fixed command/distance split
family: several literal/context variants still reconstruct entropy plans and
physical wires. `encodeEntropySplitCandidateAllocRecorded` enumerates the
variants; `encodeEntropySplitWireCandidateInternalAllocRecorded` then reaches
the complete command writer. A shared symbol/entropy plan with exact counting
could retain the existing candidate order and strict-smaller rule while
emitting only that family's winner. `prepared_command_distance.supported`
currently excludes split shapes, so its common plan cannot simply be reused.

First record the complete `QualityQ8Profile` events with the exact explicit
window16 settings and compare the resulting wire hash to this matrix. Count
successful physical wire events that do not become the final returned wire;
`accepted=false` alone is not a losing-wire count. Dropped/truncated event
logs cannot establish complete counts. Four optimal parsers also rebuild
indices and walk matches; existing search profiles can quantify that separate
model-independent evidence opportunity. No new encoder prototype is adopted
from this checkpoint alone.
