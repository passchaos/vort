# Three-codec gap assessment, 2026-11-02

The goal of leading Deflate, Zstd and Brotli in both functionality and
performance remains active. The current source is `98c8a77e`. Broad format,
dictionary and streaming support is already present, but the measured encoder
tradeoffs and decoder latencies still leave substantial gaps. This assessment
routes to the latest relevant evidence; its rows retain their own source,
parameter and timing epochs.

The subsequent 2026-11-03 [tree-score order](br/score-order.md) and
[fixed-price prefix bound](br/fixed-prefix-bound.md) increments retain the
same q8 wires. The latter's separate current-source epoch measures 31.69
times reference latency at size 0.99556 times reference. The 32.28 row below
retains its original interval-cost epoch; no A/B gains are multiplied into it.

The further [exact ordinal index](br/ordinal-index.md) preserves old matching
candidate quotas and all q8 wires while improving the matched real-input
matrix by 1.95% geometrically, or 4.30% at 64 KiB. Its separate reference
epoch measures 31.27 times native Brotli latency, at size 0.99556 times
reference. An admitted 64 KiB plan uses 256 KiB more logical index storage;
caller allocator budgets and retained-capacity queries account for actual
allocations. These remain scoped speed/resource tradeoffs, not broad parity.

The [primary context count](br/primary-count.md) increment further preserves
candidate configs, exact sizes and final wires. Its separate matched matrix
improves real-input latency 1.22% overall and 3.05% at 64 KiB; the repetitive
control retains about 1.8% regression in longer pairs. Its current reference
epoch remains 31.02 times Brotli latency at size 0.99556 times reference.

## Encoding speed and compressed size

Ratios below are Vort/reference; lower is better for both columns. These are
different workloads and policies, rather than a shared codec ranking.

| Measured policy and scope | Time ratio | Size ratio | Evidence |
| --- | ---: | ---: | --- |
| Deflate level 9 / libdeflate 1.26 level 12, twelve 4/16/64 KiB Silesia prefixes | 1.85–1.92 | 1.0007–1.0124 | [BT optimal encoder](deflate-bt-optimal.md), 2026-10-31 source epoch |
| Native Zstd btultra2 / libzstd 1.6.0, twelve 64/128 KiB prefixes | 3.13–3.18 | 1.0048–1.0051 | [Adaptive matcher](zstd-adaptive-matcher.md), 2026-10-31 source epoch |
| Same Zstd policy, three actual 1 MiB inputs | 4.57 | 0.9928 | Same separate multi-block epoch |
| Brotli q8 generic, actual window 16, twelve 4/16/64 KiB prefixes | 32.28 | 0.99556 | [Interval-cost increment](br/interval-cost.md), 2026-11-02, current source |
| Brotli q10, twelve 32/64 KiB prefixes | 6.62 / 4.88 | 1.0724 / 1.0758 | [Command/model study](brotli-command-start-model.md), earlier source epoch |
| Brotli q11, twelve 32/64 KiB prefixes | 5.20 / 2.32 | 1.0986 / 1.1031 | Same earlier source epoch |

Deflate's two levels have different algorithms and search budgets; matching
their level numbers would not create an equal-strategy comparison. Zstd's
native strategy also differs from the reference parser. The q8 and q10/q11
Brotli rows use different settings and source epochs, so their ratios are
not combined. The earlier encoder rows remain the latest evidence for those
policies, rather than fresh measurements of every current-source encoder.

The q8 row makes the largest current tradeoff clear: about 32 times the
reference latency buys only 0.44% smaller output on average. Higher Brotli
qualities additionally need compression-ratio work. Native Zstd still needs
better matching/index lifetime across blocks and entropy pricing. Deflate
needs broader entropy-aware parsing and split planning across dictionaries,
streaming and multi-block inputs.

## Decode latency

The [2026-11-02 reference refresh](decode-reference-gaps-20261102.md) reports
one-shot Deflate at 1.29–1.53 times libdeflate 1.26 latency on eleven 1 MiB
Silesia sources, with a mean near 1.44. The [larger 2026-11-01 epoch](industry-decode-current-20261101.md)
puts Brotli q6/q11 one-shot latency near 1.12–1.49 times Brotli 1.2.0 across
64 KiB, 1 MiB and full files. These are warmed one-shot calls, with each
reference's documented lifecycle.

Zstd's Mozilla 1 MiB level-3 outlier was 2.08 times libzstd latency in the
reference refresh. The later [raw mixed-sequence increment](zstd/raw-mixed-sequences.md)
measures the retained target at approximately 1.72 times libzstd in its own
same-process reference rows. Its preceding optional-Huffman and small-table
gains are not multiplied into an estimated whole-corpus reference ratio.

Incremental Deflate now has a caller-owned two-window semantic path and
[lazy compact-table preparation](deflate/compact-tables.md). The earlier
Dickens semantic-path comparison left about a 1.47–1.49 times one-shot gap;
the table increment then improved whole-input group latency by 3.5–4.5% and
4 KiB-fragmented input by 0.4–1.1% against its preceding source. A current
zlib-ng streaming matrix is still required. Beating classic zlib 1.2.11 on
seven of eleven earlier rows does not establish the modern streaming bar.

## Functionality, resources and evidence

The [functional audit](industry-gap-audit.md#current-functionality) records
standard formats, streaming, dictionaries, checksums, windows, resource
budgets, Zstd training/seekable APIs and Brotli shared/Large Window support.
The remaining encoding gap is principally search/model quality and consistent
speed/ratio behavior. Finite match candidates and graph states can miss
cheaper parses; complete copy lengths within an admitted match do not make
the whole search globally optimal.

There is no complete current-source competitor matrix covering encoding,
decoding, compressed size, requested heap and RSS across all levels, full
files, cold/warm calls, reusable/streaming/dictionary APIs and CPUs. Caller
quotas and measured scratch reductions are useful contracts, but do not
establish lower memory use than competitors. Native x86-64 evidence and
Wasm/32-bit/BigEndian checks also do not establish ARM64 or cross-platform
throughput leadership.

The recent focused suites passed 590 Deflate tests, 1,261 Zstd tests and
1,505 Brotli tests with one Brotli skip. Zstd's external corpus passed 9,900
frames. The default `check check-wasm` gate passed 212/212 steps. An extra
ReleaseSafe whole-library compilation remains pending at this assessment;
its completion is not inferred from the focused checks.

## Next priorities

1. Reduce Brotli q8's dominant context search, optimal parsing and repeated
   candidate emission while preserving exact candidate ordering and wire
   behavior where required. Use actual-work counts to reject small cache
   opportunities before ordinary A/B timing.
2. Improve higher-quality Brotli and native Zstd search/model tradeoffs, with
   complete-wire accounting and held-out real inputs.
3. Continue Zstd sequence payload and per-block work, Deflate one-shot loop
   constants, and profitable streaming semantic-path admission.
4. Refresh symmetric competitor matrices, including zlib-ng/zlib-rs,
   streaming, dictionaries, full files, memory and ARM64. Report weakest
   cases alongside geometric averages.

Evidence retention uses repository-local `zig-out` artifacts. Older documents
may refer to external temporary paths; their documented measurements retain
their date, and availability of those old artifacts is not assumed here.
