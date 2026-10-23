# LZFSE and LZVN

Vort implements Apple's LZFSE stream format and raw LZVN codec in pure Zig.
The writer finds matches and encodes complete V1/V2 FSE blocks with four
interleaved literal states and L/M/D value states. The library uses explicit
allocators and runs without Compression.framework or a C codec binding.

Both encoding and decoding support these block representations:

| Magic | Representation |
|---|---|
| `bvx-` | Uncompressed data |
| `bvxn` | LZVN-compressed data |
| `bvx1` | LZFSE FSE data with uncompressed frequency tables; 772-byte header |
| `bvx2` | LZFSE FSE data with packed fields and compressed frequency tables |
| `bvx$` | Mandatory standalone stream terminator |

The decoder reconstructs repeated distances and overlapping matches, checks
frequency sums, state ranges, payload boundaries, literal and record counts,
decoded sizes and output limits, and rejects missing terminators and trailing
data. Empty input encodes as an eight-byte empty stored block followed by a
four-byte terminator, 12 bytes total.

**Strategies and compatibility**

`Options.strategy` defaults to `null`. With `use_lzvn=true`, this selects the
new `auto` policy. Existing callers with `use_lzvn=false` and a null strategy
retain stored-only encoding. An explicit strategy takes priority over that
compatibility switch.

| Strategy | Block selection |
|---|---|
| `auto` | Choose matched FSE when its complete serialized block is strictly smaller than both LZVN and stored representations of the same candidate input prefix; otherwise use the legacy LZVN/stored choice. |
| `fse` | Choose matched FSE when its complete block is strictly smaller than stored; otherwise emit stored data. |
| `lzvn` | Preserve the previous deterministic LZVN/stored wire for the same input and block size. |
| `stored` | Emit uncompressed blocks. |

`fse_version` defaults to `.v2`; `.v1` selects the larger fixed frequency-table
header. Both versions use the same literal and L/M/D payload encoding.

`block_size` is a maximum raw input span, with a default of 65,536 bytes. FSE
plans may stop earlier when their literal or record counts fill. A selected
FSE prefix advances by exactly `Plan.raw_size`, then the writer processes the
remaining input. If that prefix does not win, the writer emits the original
requested legacy block, avoiding raw or LZVN fragmentation caused only by an
unsuccessful FSE count cut.

This comparison includes headers and payloads over the same candidate prefix.
Block boundaries can differ from an independently encoded `.lzvn` stream, so
the policy provides a local size decision rather than a whole-stream size
ordering between strategies. Repeated calls with identical input and options
produce deterministic bytes.

**FSE blocks and history**

The writer implements the complete value ranges:

| Field | Range and meaning |
|---|---|
| L | 0–315 literal bytes preceding a match |
| M | 0–2,359 match bytes; zero carries a literal-only record |
| D | 1–262,139 real match distance; wire value zero repeats the preceding distance in that block |
| Literal count | At most 40,000 bytes, including terminal zero padding to a multiple of four |
| Record count | At most 10,000 L/M/D records, including literal-only records |

Long literal runs and matches split into legal records. Every record makes
output progress. The four literal lanes share a 1,024-state FSE table; the
L/M/D tables use 64/64/256 states. Encoded final states reside in the header. Each
LMD payload includes an eight-byte zero prefix for reverse-reader look-behind.
A single-symbol literal alphabet can produce a zero-byte literal payload.

FSE tables and repeated-distance state reset at each FSE block. The matcher
borrows preceding input bytes as history across stored, LZVN and FSE block
boundaries, subject to the requested distance limit. Blocks therefore need
their preceding decoded history when a match reaches across a boundary.
Count limits determine FSE cuts; there is no 32 KiB raw block cap. Matched
blocks can cover 96 KiB or larger requested spans while their counts fit.

**Public APIs and ownership**

The APIs are available through `vort.lzfse`. Root aliases include
`encodeLzfseAlloc`, `encodeLzfseWithSummaryAlloc`, `encodeLzfseAppend`,
`encodeLzfseInto`, `LzfseOptions`, `LzfseEncoded` and `LzfseEncodeSummary`.

```zig
const lzfse = vort.lzfse;
var encoded = try lzfse.encodeWithSummaryAlloc(allocator, input, .{
    .strategy = .auto,
    .fse_version = .v2,
    .block_size = 96 * 1024,
    .max_working_memory = 8 * 1024 * 1024,
    .max_output_len = 16 * 1024 * 1024,
});
defer encoded.deinit(allocator);

const restored = try lzfse.decodeAllocLimited(allocator, encoded.bytes, input.len);
defer allocator.free(restored);
```

| API | Ownership and progress |
|---|---|
| `encodeAlloc(allocator, input, options)` | Return an owned complete stream; free it with the same allocator. |
| `encodeWithSummaryAlloc(allocator, input, options)` | Return `Encoded` with owned `bytes`, `summary` and `peak_working_bytes`; release it with `deinit(allocator)`. |
| `encodeInto(allocator, input, options, output)` | Preserve the existing argument order. Build a complete temporary stream, then copy into the caller's destination and return its length. Failures preserve destination bytes. |
| `encodeAppend(allocator, output_list, input, options)` | Append a complete terminated stream and return the appended length. Failures preserve the list's existing logical contents. |
| `decodeAllocLimited(allocator, bytes, max_output_len)` | Return owned decoded bytes while bounding their declared total size. |
| `decodeInto(bytes, output)` | Decode into caller-owned storage and return the decoded length. |

Input is borrowed for the duration of encoding and is not modified or retained.
`encodeAppend` is useful for embedding a complete stream in a caller's buffer;
retain stream boundaries when storing multiple results.

`Summary` counts actual emitted stored, LZVN and FSE blocks. Its FSE literal,
matched-byte, record, maximum-distance and maximum-length fields describe
selected FSE plans; literal counts exclude the zero padding. Literal and LMD
payload byte totals describe the emitted FSE payloads. Rejected candidates do
not contribute to the summary.

Low-level `EncodePlan` and `EncodeRecord` expose explicit L/M/D planning.
`EncodePlan.init(history_len)` records available preceding history;
`append(allocator, literals, match_len, distance)` splits long values, and
`appendLiterals` creates canonical literal-only records. `Record.distance` is
always a real positive distance, including the dummy distance one for M=0;
the serializer owns conversion to repeated-distance wire zeroes. Plans own
their record and unpadded literal arrays and use `deinit(allocator)`.

`encodeFsePlanAlloc(allocator, &plan, version)` validates the plan and returns
one owned FSE block with payload-size metadata. Its `bytes` contain the block
header and payloads. The caller supplies preceding decoded history and adds
the standalone stream terminator when framing the result:

```zig
var plan = lzfse.EncodePlan.init(0);
defer plan.deinit(allocator);
try plan.append(allocator, "a", 2359, 1);
var block = try lzfse.encodeFsePlanAlloc(allocator, &plan, .v2);
defer block.deinit(allocator);
var stream: std.ArrayList(u8) = .empty;
defer stream.deinit(allocator);
try stream.appendSlice(allocator, block.bytes);
try stream.appendSlice(allocator, "bvx$");
```

**Incremental decoding**

`lzfse.IncrementalDecoder`, also exported as `vort.LzfseIncrementalDecoder`,
decodes stored, LZVN, V1 FSE and V2 FSE blocks through
`step(input, output) !core.StepResult`. Each result reports the input bytes
accepted and output bytes written during that call, with `need_input`,
`need_output` or `done`. Input and output slices are borrowed only for the
current call. The decoder neither retains a caller input slice nor requires a
complete decoded stream or block buffer.

The allocator supplied at initialization must remain valid until `deinit()`.
The decoder owns any history and compressed-tail storage allocated while
stepping; the caller owns the decoder value and both I/O buffers.

Stored and LZVN payloads consume input directly. LZVN keeps only a small opcode
header and unfinished literal/match state, including copies across arbitrary
output boundaries. For reverse FSE payloads, the frequency tables and declared
symbol counts bound the maximum bit reach. The decoder consumes unused payload
prefixes without retaining them and stores only the required literal and LMD
suffixes. Their combined theoretical maximum is 117,502 bytes, covered by the
default 128 KiB compressed-buffer limit. A stream or padded compressed payload
larger than 0.5 MiB can therefore be processed with a much smaller retained
suffix; the buffer limit does not cap the total compressed stream size.

Four-lane literal and L/M/D cursors decode lazily into caller output. They do
not materialize a 40,000-byte literal array or a complete decoded block. A
history ring grows only as needed, up to `max_history_len`, and preserves the
decoded suffix across stored/LZVN/FSE block boundaries within one stream.
Headers, unused payload prefixes and terminators may advance with zero output
space; data output stops when the caller buffer is full.

The following example decodes one strict standalone stream. It resubmits the
unconsumed input suffix on every call and continues draining when all source
bytes have already been accepted:

```zig
var decoder = vort.LzfseIncrementalDecoder.initWithOptions(allocator, .{
    .max_output_len = 64 * 1024 * 1024,
    .max_working_memory = 1024 * 1024,
});
defer decoder.deinit();

var decoded: std.ArrayList(u8) = .empty;
defer decoded.deinit(allocator);
var output_buffer: [4096]u8 = undefined;
var input_offset: usize = 0;
var eof_signaled = false;

while (true) {
    if (input_offset == compressed.len and !eof_signaled) {
        decoder.finish();
        eof_signaled = true;
    }
    const result = decoder.step(compressed[input_offset..], &output_buffer) catch |err| {
        const partial = decoder.snapshot().last_step_progress;
        input_offset += partial.input_read;
        try decoded.appendSlice(allocator, output_buffer[0..partial.output_written]);
        return err;
    };
    input_offset += result.progress.input_read;
    try decoded.appendSlice(allocator, output_buffer[0..result.progress.output_written]);
    if (result.status == .done) break;
}
std.debug.assert(input_offset == compressed.len);
```

Here `compressed` is the caller's encoded byte slice. The `decoded` list is
example-owned output collection, outside the decoder's memory budget; a file
or network consumer can publish each returned output slice instead. A reader
feeding separate source buffers must preserve the unconsumed suffix before
reading more. `need_output` can leave input unconsumed, and exhausting input
does not mean all output has drained. `finish()` signals source EOF; offer only
empty input afterward while continuing `step` until `done` or an error. A
missing header, payload or mandatory `bvx$` terminator fails as `TruncatedFrame`.

| Incremental API | State and ownership |
|---|---|
| `init(allocator)` / `initWithOptions(allocator, options)` | Return caller-owned value state without allocating. Options are validated when stepping. |
| `step(input, output)` | Borrow slices for this call and return actual per-call progress and status. |
| `finish()` | Mark input EOF; returns `void` and leaves output draining to subsequent empty-input steps. |
| `snapshot()` / `diagnostics()` | Report cumulative and current-stream progress, phase, retained storage, failure offsets and the last call's partial progress. |
| `reset()` | Clear stream/error state and reset operation counters and quotas while preserving allocated capacity. Retained buffers continue to count toward the working budget. |
| `resetWithOptions(options)` | Validate options, release old buffers and restart the operation; returns `!void`. Invalid options leave the previous state intact. |
| `nextStream()` | With `stop_after_end_marker=true`, require `done`, clear history/current-stream state and preserve cumulative quota, counters and peak memory. Options remain the same. |
| `deinit()` | Release decoder-owned history and retained compressed buffers. |

**Incremental limits, stream boundaries and errors**

These are `IncrementalDecoder.Options`, separate from the encoding options:

| Option | Default and scope |
|---|---|
| `max_output_len` | Unlimited. Cumulative decoded-byte budget for the operation, including streams entered through `nextStream()`. Each block's declared output is checked at its header before payload output. |
| `max_history_len` | 262,139; allowed range 0–262,139. Maximum retained history bytes, grown on demand. |
| `max_compressed_buffer_len` | 128 KiB. Maximum combined retained reverse-FSE suffix bytes, not complete payload or stream length. |
| `max_working_memory` | Unlimited. Maximum live requested dynamic allocation bytes, including buffers retained between calls. |
| `expected_output_len` | `null`. Optional exact decoded length for each stream; cannot exceed `max_output_len`. Checked against block declarations and at its terminator, with the same expectation after `nextStream()`. |
| `stop_after_end_marker` | `false`. Strict single-stream termination and trailing-data rejection; `true` stops at `bvx$` and leaves the following input unconsumed. |

The dynamic working budget includes owned history and FSE suffix capacity,
including retained allocations across calls. It excludes caller source and
output buffers, caller-owned state/header/FSE table storage, allocator
bookkeeping and underlying allocator remap transients. Raw/LZVN decoding does
not allocate a complete compressed payload, but may allocate history for later
matches. Snapshot `working_bytes` and `peak_working_bytes` expose this accounting.

The default decoder rejects bytes following the terminator. To decode ordered
concatenated streams or return a suffix to an outer parser, enable
`stop_after_end_marker`. Advance the input position by `result.progress.input_read`
before deciding what follows the completed stream. After publishing that call's
output, use `nextStream()` only when another LZFSE stream is expected, then
resubmit the unconsumed suffix. Do not skip the rest of the offered slice or
automatically reinterpret arbitrary trailing bytes as another stream. A reset
starts a new operation and clears the cumulative output quota; `nextStream()`
preserves it and clears cross-stream history. It also clears the EOF latch for
the next stream. Different per-stream size expectations require a new operation
or external validation rather than changing options during `nextStream()`.

For a caller slice containing ordered complete LZFSE streams, set
`.stop_after_end_marker = true` in the example's options and replace its
`done` branch with the following. The input offset remains cumulative, so the
next call receives the unconsumed suffix rather than replaying or discarding it:

```zig
if (result.status == .done) {
    if (input_offset == compressed.len) break;
    try decoder.nextStream();
    eof_signaled = false;
}
```

Errors are sticky. A failing call may already have accepted input and emitted
a decoded prefix. Capture `snapshot()` or `diagnostics()` immediately: its
`last_step_progress`, `error_input_offset` and `error_output_offset` include that
call's actual accepted and emitted bytes. The offsets describe cumulative
progress at failure. Subsequent `step` calls return the same error with zero
new progress; use `reset()` or `resetWithOptions()` to restart from the beginning
of the source. A returned prefix has not established that the complete stream
is valid.

`OutputLimitExceeded` identifies the cumulative output budget;
`HistoryLimitExceeded` means a globally valid match needs more retained history;
`CompressedBufferLimitExceeded` means the required FSE suffix exceeds its cap;
and `WorkingMemoryLimitExceeded` identifies dynamic-budget exhaustion. Backing
allocator failure remains `OutOfMemory`. Format corruption, missing input,
decoded-size mismatch and extra data retain the codec's precise format errors,
including `InvalidLzfseStream`, `InvalidLzvnStream`, `TruncatedFrame`,
`SizeMismatch` and `TrailingData`.

**Encoding resource limits**

| Option | Default and scope |
|---|---|
| `block_size` | 65,536; positive, at most `maxInt(u32)`. Maximum requested raw span; FSE count limits can cut earlier. |
| `hash_log` | 15; allowed range 8–20. Fixed two-position hash table size is `8 * 2^hash_log` bytes, or 256 KiB by default. |
| `max_match_distance` | 262,139; positive requests are capped to the format's maximum distance. |
| `max_working_memory` | Unlimited by default. Bounds live requested dynamic allocations used to construct the stream. |
| `max_output_len` | Unlimited by default. Bounds the newly encoded stream, including block headers, payloads and final terminator. |

The working budget includes the output under construction and returned slice,
hash table, Plan arrays, candidate headers and literal/LMD/LZVN payloads. It
excludes borrowed caller input, stack storage, allocator bookkeeping and
underlying allocator remap transients. Caller-owned destination capacity is
outside the reported encoding peak. `WorkingMemoryLimitExceeded` identifies
a budget denial; backing allocator failures remain `OutOfMemory`.

The matcher indexes only a selected history suffix and current candidate,
using fixed anchor/latest positions per hash bucket. It has no input-sized
link array or copied history window. These one-shot APIs retain the complete
encoded output, so total allocation use also depends on stream size. Auto
constructs candidates before selecting a block, so its peak can exceed stored
mode for the same input. `peak_working_bytes` reports the observed requested
allocation peak rather than an estimated multiplier.

**CLI and reproducible validation**

```sh
zig build run -- encode-lzfse-file input.bin output.lzfse 65536 auto
zig build run -- encode-lzfse-file input.bin output-v1.lzfse 98304 fse --fse-version=v1 --hash-log=15 --max-distance=262139 --working-memory-limit=8388608 --output-limit=16777216
zig build run -- encode-lzfse-file input.bin output-lzvn.lzfse 65536 lzvn
zig build run -- inspect-lzfse-file output.lzfse 536870912
zig build run -- decode-lzfse-file output.lzfse restored.bin 536870912
zig build test-lzfse
zig build test-lzfse-stream
zig build run-lzfse-diff
```

The encode command accepts `[block_size] [auto|fse|lzvn|stored]` followed by
`--fse-version=v1|v2`, `--hash-log=8..20`, `--max-distance=bytes`,
`--working-memory-limit=bytes` and `--output-limit=bytes`. It reads and encodes
the input before atomically replacing the destination. Input and output may
use the same path; failed encoding or temporary-file writes preserve the
existing destination.

The dedicated FSE differential exercises direct plans independently of
matching, both header versions, strategies and legacy switches, count cuts,
cross-block history, summaries, resource limits and allocation failures. It
decodes native output through Apple and Apple output through Vort, and checks
V2-to-V1 header conversion while retaining the same FSE payload. A pinned
local Apple checkout can be used as follows; adjust the path to its build:

```sh
LZFSE_REFERENCE=/tmp/vort-lzfse-ref.XSy743/lzfse
zig build run-lzfse-diff -- --lzfse "$LZFSE_REFERENCE/build/bin/lzfse" --report /tmp/vort-lzfse-cli.json
zig build run-lzfse-fse-diff -- --lzfse "$LZFSE_REFERENCE/build/bin/lzfse" --reference-dir "$LZFSE_REFERENCE" --report /tmp/vort-lzfse-fse.json
zig build run-lzfse-stream-diff -- --lzfse "$LZFSE_REFERENCE/build/bin/lzfse" --report /tmp/vort-lzfse-stream.json
```

Apple's command-line decoder treats a zero-byte return as failure, which is
ambiguous for valid empty output. Empty-stream validation therefore uses a C
status wrapper linked to the unchanged reference library and verifies decoder
success, EOS and full input consumption for Vort's 12-byte empty stream.
Nonempty streams use the official Apple CLI. The reference checkout supplies
its headers and built `liblzfse.a` for that status wrapper.

The dedicated streaming campaign reports 223 cases and uses Apple as its
whole-stream compatibility oracle. It covers stored/LZVN/V1/V2 and mixed blocks, cross-block history,
single-byte and varied input/output splits, zero-output backpressure, large
payloads with bounded reverse tails, resource limits, malformed/truncated input,
sticky error progress and reset/next-stream behavior. Targeted LZVN cursor
regressions cover every defined and reserved opcode byte, extended lengths,
overlap and ring wrap, EOS acceptance and exact payload consumption. See the
[bounded streaming functional baseline](../performance/bounded-streaming-functional-baseline.md)
for retained reproduction evidence. These checks establish functional and
compatibility behavior; they do not measure or claim throughput leadership.

The [functional baseline](../performance/lzfse-fse-functional-baseline.md)
records reproducible compatibility and internal FSE-versus-LZVN encoded-size
evidence. Apple compressor ratio and throughput comparisons remain separate
benchmark work.
