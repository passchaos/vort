# Quantum encoding and decoding

Vort exposes the shared pure-Zig Quantum codec through `vort.quantum` and root
aliases. It supports 10...21-bit windows (1 KiB through 2 MiB), adaptive
arithmetic coding, literal selectors 0...3, fixed 3-/4-byte match selectors 4/5,
and variable 5...259-byte matches through selector 6. Arithmetic registers
reset at each 32 KiB frame; adaptive symbol models and decoded history continue
across frames. Ordinary and split [CAB archives](cab.md) use this same codec.

```zig
var encoded = try vort.encodeQuantumWithSummaryAlloc(allocator, input, .{
    .window_bits = 18,
    .strategy = .greedy,
    .hash_log = 15,
    .max_match_distance = 128 * 1024,
});
defer encoded.deinit(allocator);

const decoded = try vort.decodeQuantumAllocLimited(
    allocator, encoded.bytes, input.len, decoded_limit, 18,
);
defer allocator.free(decoded);
```

Quantum's raw stream has no self-contained decoded-size or window header. The
caller supplies the expected decoded size and the same window used to encode.
The standalone encoder adds `0xff` after every complete 32 KiB frame, including
a complete final frame. A shorter final frame has no mandatory sentinel.
Empty input produces an empty stream. Frame APIs return only codec payload
bytes, without the sentinel; callers assembling a standalone stream append it
after each complete frame. CAB stores these payload bytes in CFDATA records
and its extraction path injects a sentinel once a logical block is complete,
including when that block is split across cabinets. A payload can contain
`0xff` as arithmetic data; the omitted sentinel is the framing byte after its
bounded null padding.

## Strategies and frame selection

The default `.greedy` strategy uses a deterministic three-byte hash with two
candidate positions per bucket. It considers only distances allowed by the
configured window and `max_match_distance`, indexes bytes covered by a match,
and emits a frame-bounded item plan. Fixed 3-byte matches have a distance
alphabet capped at 4 KiB and fixed 4-byte matches at 256 KiB, or the smaller
declared window; variable matches can use the full configured distance bound.
An unrepresentable short match is discarded.

Each greedy frame is encoded alongside the literal reference. The match
payload is selected only when its complete byte length is strictly smaller;
ties keep the reference. Both candidates begin with the same current models,
and only the selected frame's models become the next frame's state. Choosing
matches can change later model history, so the complete greedy stream is not
guaranteed to be smaller than a separate literals-only stream encoded from a
fresh state. Reported greedy/literal sizes are corpus observations rather than
a guarantee across streams. `.literals` bypasses matching and preserves the
existing literal reference bytes, including across adaptive frame boundaries.
`encodeQuantumLiteralAlloc(allocator, input, window_bits)` is the convenience
entrypoint for this strategy, and `vort.quantum.LiteralEncoder` remains
available for reference frame encoding. Its allocation failures preserve its
reusable models.

Quantum length and position extra fields share the bit reader with a 16-bit
arithmetic lookahead. The item encoder first produces an arithmetic-only tape,
replays exact symbol decisions to locate each extra field after lookahead,
then interleaves the fields in item order. A second replay verifies symbols
and extras and establishes complete-frame padding. Multiple fields may occupy
the same arithmetic bit cursor and retain their original order.

This is a functional greedy encoder. The CAB `quantum_level` values 1...7 are
declared header values, without corresponding speed or high-quality policies.
Deeper parsing, persistent hash reuse, calibrated levels and throughput work
remain open. The current evidence supports correctness and encoded-size
comparisons, without a throughput or high-quality leadership claim.

## Public APIs and ownership

`encodeQuantumAlloc(allocator, input, options)` returns an owned standalone
stream; release it with the same allocator. `encodeQuantumWithSummaryAlloc`
returns `QuantumEncoded`, containing owned `bytes`, `summary`, and
`peak_working_bytes`; call `deinit(allocator)` to release it. The summary reports
literal counts, fixed and variable matches, matched bytes, maximum offset,
extra bits, and the number of selected literal-reference frames. Summary
accumulation checks integer overflow.

`encodeQuantumInto(allocator, input, output, options)` and
`encodeQuantumAppend(allocator, output_list, input, options)` return the number
of bytes written or appended. They encode before changing caller output;
encoding failure or an undersized caller buffer preserves the output bytes.
These APIs still allocate temporary encoded data, and caller-owned output
does not make encoding allocation-free.

`decodeQuantumInto(input, output, window_bits)` writes into caller-owned output
whose length is the expected decoded size. A malformed stream may leave a
decoded prefix. `decodeQuantumAlloc` returns owned decoded bytes;
`decodeQuantumAllocLimited` checks the requested decoded size against
`max_output_len` before allocating. The decoder uses the caller's complete
decoded output as match history.

`QuantumEncoder.init(options)` returns caller-owned model/progress state. The
state stores no allocator, input buffer or history slice and needs no
`deinit`. Its two frame interfaces share the same model state and selection
rules:

- `encodeFrameAlloc(allocator, full_input, start, end)` borrows the complete
  input prefix. `start` must equal `input_read`, and only the configured history
  suffix preceding `start` is considered. `encodeFrameWithSummaryAlloc` returns
  an owned `QuantumEncoded` instead of a byte slice.
- `encodeFrameWithHistoryAlloc(allocator, history, input)` accepts a separate
  borrowed history buffer and the current frame's input, so callers can discard
  older input. The history length must not exceed `input_read`, so the first
  call requires empty history. Greedy matching uses the most recent
  `min(history.len, options.historyLimit())` bytes;
  `.literals` ignores history content. `encodeFrameWithHistoryAndSummaryAlloc`
  returns an owned `QuantumEncoded`.

The caller supplies actual preceding decoded bytes as history and keeps both
borrowed slices valid for the duration of the call. The encoder retains neither
slice; history content is the caller's responsibility. The complete-prefix
interface borrows its history directly. The separate
history interface temporarily copies nonempty greedy history's selected suffix
and the current input into a bounded scratch allocation; it counts that
allocation toward the working budget and releases it before returning. Empty
history and `.literals` avoid this copy.

Each frame must be nonempty and at most 32768 bytes, and `input_read` must be a
multiple of 32768 before the call. Success advances the global count by the
current input length and commits the selected models. Calls are contiguous;
a frame shorter than 32768 bytes ends the stream and continuation is rejected.
Initialize a new encoder to begin another stream. Invalid input, allocation
failure, integer overflow, or an output/working limit failure leaves model and
progress state unchanged, so a failed frame can be retried.

For caller-planned items, `vort.quantum.PlanEncoder` and
`vort.quantum.EncodeItem` expose the same literal/match serializer without
automatic match planning. A match item carries `length: u16` and `offset: u32`.
The serializer validates frame size, length, representable position slots,
configured window and available history before committing state.

## Options and resource accounting

| `QuantumEncodeOptions` field | Default | Contract |
| --- | --- | --- |
| `window_bits` | `18` | 10...21, declaring a 1 KiB through 2 MiB window. |
| `strategy` | `.greedy` | Deterministic match planning or explicit `.literals`. |
| `hash_log` | `15` | 8...20; greedy hash storage requests `8 * 2^hash_log` bytes. |
| `max_match_distance` | Maximum `usize` | Must be nonzero; `historyLimit()` is its minimum with `2^window_bits`. |
| `max_working_memory` | Maximum `usize` | Bound on live requested dynamic allocation bytes for the encoding operation. |
| `max_output_len` | Maximum `usize` | Compressed-byte bound: one returned frame payload for frame APIs, or the complete standalone stream including sentinels for one-shot APIs. |

The default hash table requests 256 KiB. Hash storage depends on `hash_log`,
rather than total input size. Match plans cover at most one 32 KiB frame, and
the matcher borrows bounded history instead of owning an input-sized chain.
The separate history interface's temporary copy is limited to
`historyLimit() + 32768` bytes. The hash index is rebuilt for each frame.

The working budget tracks the requested sizes of live hash tables, item plans,
separate-history scratch, arithmetic/replay buffers, simultaneous
reference/candidate payloads, returned encoded allocations, and, for one-shot
encoding, the accumulated stream. It does not include caller input/history,
model stack storage, allocator
bookkeeping, or an underlying allocator remap's internal transient memory.
`peak_working_bytes` reports this same accounting and includes the returned
encoded allocation. Caller output storage is outside the codec budget.

A greedy candidate allocation failure propagates the error and preserves
state; it does not silently switch strategies to fit a smaller budget.
The budget therefore needs room for reference/candidate comparison even when
the selected payload is small. CAB maps its Quantum controls to these options,
but `quantum_max_working_memory` and `quantum_max_output_len` apply separately
to each codec frame, excluding archive construction and container bytes.

## Errors and validation

Invalid encoder options, frame ranges or supplied history lengths, invalid
planned match lengths/positions/reach, skipped input or continuation after a
partial frame return `InvalidBlockPlan`.
Tracked working-budget exhaustion returns `WorkingMemoryLimitExceeded`;
underlying allocator exhaustion remains `OutOfMemory`. Compressed output
budget failure and allocating decoder size preflight return
`OutputLimitExceeded`. Encoding into an undersized buffer returns
`OutputTooSmall`. Progress or summary arithmetic overflow returns
`IntegerOverflow`.

Unsupported decoding windows return `UnsupportedCabinetFeature`. A bit stream
or complete-frame trailer that ends prematurely returns `TruncatedFrame`;
invalid arithmetic state, frame overshoot or damaged padding/sentinel returns
`InvalidQuantumStream`. A decoded match outside the declared window or already
decoded history returns `InvalidMatch`. A complete standalone frame without
its sentinel is truncated.

```sh
zig build test-quantum test-cab
zig build run-quantum-match-diff -Doptimize=ReleaseFast -- \
  --mspack-dir /path/to/libmspack --report /tmp/quantum-matches.json
zig build run-cab-diff
```

The targeted regressions cover every legal match length from 3 through 259,
position-slot endpoints across every 10...21-bit window, all three match
selectors with nonzero extras, overlapping matches, extras sharing an
arithmetic cursor, complete and partial frames, cross-frame models/history,
literal reference bytes, precise malformed/truncated errors, deterministic
output, caller output transactions, and allocation-failure rollback with
successful retry.

The dedicated differential uses unmodified libmspack to decode matched output
and fragmented CAB sets independently across all supported windows. It also
checks summaries, resource limits, literal-reference size arbitration and
repeated output determinism. See the retained
[functional size baseline](../performance/quantum-match-functional-baseline.md)
for corpus details, reference provenance and reproduction commands. These
results establish this compatibility slice; throughput and high-quality
comparison remain future measurements.
