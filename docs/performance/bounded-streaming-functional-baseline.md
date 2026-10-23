# Bounded incremental decoding functional baseline

Date: 2026-10-24. Zig 0.16.0, Linux x86-64. This records input/output progress,
retained-memory limits, compatibility and error behavior; throughput and
cross-library memory leadership are not claimed.

Native LZ4 and Zstd now default to `core.CompressedInputPolicy.block_stream`.
The decoder accepts only the bytes needed by the current header/block stage
and publishes output before collecting an entire frame. Explicit
`.prevalidated_frame` preserves the previous preflight/direct paths, including
their existing checksum timing; it does not promise atomic rejection before
all output for every path. Callers must advance by the returned input progress
and resubmit unconsumed suffixes.

| Surface | Default retention and validation |
| --- | --- |
| LZ4 raw/token blocks without block checksums | Caller input is consumed directly; no payload-sized decoded scratch. |
| LZ4 checksummed blocks | One encoded payload is retained and verified before output, including raw blocks; capacity is bounded by the declared block size. |
| Zstd compressed blocks | At most the standard 128 KiB block payload plus control/header state; no decoded-block scratch. Dictionary/window history remains supported. |
| LZFSE raw/LZVN blocks | Byte-progressive input, bounded opcode/header state and direct caller output; no compressed-payload buffer. |
| LZFSE reverse FSE | Only the suffix needed by declared counts and table bit widths is retained; unused prefixes are discarded directly. |

The native probe dashboard passes 582 cases across frame and dictionary
surfaces: 304 LZ4 frames, 11 LZ4 dictionary cases, 242 Zstd frame cases and
25 Zstd dictionary cases. LZ4's external corpus includes 253 liblz4-generated
frames. Existing whole-frame-specific probes opt in explicitly, while normal
incremental and dictionary probes retain default block streaming. Their loops
check per-step and cumulative input/output progress rather than assuming the
first call accepts all input. The complete ReleaseFast Zstd test suite passes
743 cases, and focused LZ4 tests pass 47 cases.

LZFSE's 223-case native/Apple differential uses 65 corpora under three input/
output schedules, plus zero-buffer, limit, reset, allocation-failure, malformed
and stopped-stream concatenation cases. Four resource groups execute 20 exact
boundary checks; four OOM groups inject 12 failures and verify reset/retry.
Both V1/V2 and all block types, zero literal payloads, maximal L/M/D values,
ring wrap and mixed-block history are covered. Apple reference is pinned to
`e634ca58b4821d9f3d560cdc6df5dec02ffc93fd`.

| LZFSE observation | Retained compressed bytes | History / working evidence |
| --- | ---: | --- |
| Entire corpus maximum | 22136 | Maximum history 262139; observed working maximum 264341 bytes. |
| 401056-byte V2 stream with unused prefixes | 2219 | 398670 bytes discarded directly; working peak 10440; 8192 output bytes equal Apple. |
| 302240-byte LZVN stream | 0 | Compressed buffer limit zero; 300001 decoded bytes equal Apple. |

FSE's general worst-case retained suffix is 117502 bytes: at most 50001 literal
and 67501 L/M/D bytes. Actual tables can require fewer bits. The decoder does
not materialize a decoded block or a 40000-byte literal staging buffer. It
uses caller-bounded history and allocates only retained payload/history state.
Caller input/output, stack tables and allocator bookkeeping are excluded from
the requested-live-allocation budget.

Snapshots preserve actual progress on failure. Retained examples include
15 accepted/1 published bytes for a bad LZVN match, 102/90 for trailing data,
52/48 for insufficient history, and 1884/8192 for a concatenation quota error.
Repeated calls after failure return the same error with zero new progress;
reset begins a new operation. `nextStream` clears stream history and retains
the cumulative output quota and working peak.

```sh
zig build test-zstd test-lz4 test-lzfse-stream -Doptimize=ReleaseFast
zig build run-native-codec-probes-dashboard -Doptimize=ReleaseFast
zig build run-lzfse-stream-diff -Doptimize=ReleaseFast -- \
  --lzfse /path/to/apple/lzfse --report /tmp/lzfse-stream.json
```

Exact LZFSE corpus/source/probe hashes and measurements are retained in
[the streaming JSON](data/lzfse-stream-x86-20261024.json). Native probe evidence
is in [the dashboard JSON](data/native-bounded-stream-x86-20261024.json).
Zstd/LZ4's per-frame decoded limit and logical-stream exact-size pledge remain
distinct from their cumulative output and live requested-allocation quotas.
The added quota and dictionary-recovery evidence is recorded in
[the stream-contract baseline](stream-contracts-functional-baseline.md).
XZ decoded-block staging and broader real-file throughput, allocation and RSS
comparisons remain open.
