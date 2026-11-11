# Brotli per-meta-block diagnostics

`vort.br.diagnoseMetaBlocksAlloc` discovers standard RFC Brotli meta-blocks,
materializes their output and records the actual shared prepared-dispatch
executor selection. A separate logical replay collects command, distance,
dictionary and copy counters. Each compressed block compares replay input bit
position, distance ring and complete retained history bytes with the decoder.

```zig
var report = try vort.br.diagnoseMetaBlocksAlloc(io, allocator, wire, .{
    .max_output_len = 64 * 1024 * 1024,
    .max_meta_blocks = 32,
});
defer report.deinit(allocator);
```

The report owns its full decoded `output` and `records`; it retains no caller
input borrow after the call. Failures release all internal allocations and
publish no partial report. The caller supplies both the allocator and I/O
clock. This diagnostic has the ordinary default RFC scope; it does not enable
Large Window markers or caller shared dictionaries.

Each record includes the physical meta-block index and kind, bit offsets,
decoded range, literal/command/distance tree counts, distance parameters, the
selected executor tag, independent logical counters and header/payload clocks.
Stored and metadata records carry no compressed executor tag. Final empty
markers are validated but excluded from the record count.

The dispatcher reports the exact top-level executor it invokes. Its tag does
not infer specializations selected inside a wrapper. Normal decode invokes
the same decision module with a known null diagnostic tag. Token loops do not
collect route events.

Output growth, record growth, header copying, counter replay and verification
are outside the header/payload clocks. The clocks still include clock-call and
diagnostic cache effects, so they are not competitor timing or acceptance
evidence. Small ordinary streams retain their existing generic decoder;
`small_payload_includes_header` marks its additional header reconstruction.

Defaults bound decoded output to 256 MiB and material meta-blocks to 4,096.
An exhausted limit returns `WorkingMemoryLimitExceeded`; a zero record limit
returns `InvalidBlockPlan`. These are logical bounds. Allocator capacity,
record capacity and parsed-header objects add memory overhead; the API does
not claim a requested-heap or RSS quota. `replay_history_bytes` reports the
explicit replay storage, bounded by the declared RFC window and output limit.
Diagnostic output/history/header allocations do not describe production Into
decoder heap use.

The dedicated contract tests compare known plaintext, public Into decoding
and all relevant public summary counters. They exercise Stored/metadata/mixed
streams, cross-block context and distance rings, command/literal/distance
switches, exact/exhausted limits, ownership, OOM cleanup, byte truncations and
public-oracle-classified malformed bit prefixes.

```sh
zig build -j2 test-br -Doptimize=ReleaseSafe \
  '-Dbr-test-filter=br meta-block diagnostic contracts'
```
