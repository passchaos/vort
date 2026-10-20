# Brotli quality and mode preset status

Date: 2026-10-20.

## Scope

The planned encoder accepts an optional Vort-native Brotli quality and mode:

```zig
const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(
    allocator,
    input,
    .{ .quality = 8, .mode = .text },
);
defer allocator.free(encoded);
```

`quality` is `0...11`; `mode` is `.generic`, `.text`, or `.font`, with
`.generic` as the default. Setting `quality` selects one of 36 deterministic
schedules; `level` must remain at its default `.fast` because the two selectors
are mutually exclusive. On the bounded one-shot path, leaving `quality` null
keeps the established fast/balanced/ratio policy. On chunked/incremental paths,
null selects the shared fast policy, now with bounded cross-block history.
The mode is an encoder hint, not a field in the Brotli stream and not automatic
content detection. Generic and text currently have the same policy; font adds
one optional distance-shape candidate from q4, so modes may legitimately choose
the same winning wire.

These presets emit RFC 7932-compatible streams through Vort's existing planned
encoder. They do **not** implement libbrotli's quality presets internally and
do not claim algorithm, byte-for-byte output, compressed-size, memory, or
throughput parity with libbrotli. A larger quality number generally deepens the
configured search and never retracts an enabled feature; q11 deliberately
trades a shorter deep-optimal input ceiling for more candidates while retaining
the complete q10 winner. Except for the explicit q11-over-q10 size guarantee,
the presets do not yet promise output-size monotonicity or the same speed/ratio
point as the corresponding libbrotli number.

## Implemented schedule

q0/q1 use bounded block-local fast-fragment planning; q2...q11 use bounded lazy
LZ77 planning. q0 uses a compact one-pass entropy writer whose current
fragment updates the next fragment's command/distance trees; q1 expands its
command plan through a dedicated compact two-pass 128-symbol event alphabet
and exact first-pass histograms. q2 uses its static-tree fast path through 128
commands and bounded dynamic trees above it; q3 uses a trivial single-block
dynamic three-tree writer. q4...q11 retain the general command writer. All
qualities keep exact
compressed-versus-stored comparison. The default
advertised window is 16 bits. q0...q5 accept 10...16-bit windows; q6...q11
accept RFC windows 10...24. The quality path's ordinary LZ matcher is capped at
`lz77.max_window_len`, currently 65,535 bytes. q6...q11 with an explicit
17...24-bit window now layer the Brotli sparse long-distance matcher over its
literal runs, so the emitted command plan can use the complete advertised
distance range instead of merely writing a wider header. The stream core's
ordinary dictionary matcher also consumes the complete 16-bit retained
history, rather than truncating cross-meta-block search to the generic 32 KiB
default.

Bounded stream planning uses a quality-specific automatic block size: q0 uses
16 KiB for lower latency; q1, q6, q7, and q11 use 32 KiB; q2...q5 and q8...q10
use 64 KiB to amortize meta-block headers. Legacy fast uses 32 KiB; balanced
and ratio use 64 KiB. `BrotliPlannedStreamChunksOptions.block_len` may
explicitly select any size from 1 through 64 KiB. The incremental encoder's
outer `block_len` takes precedence when non-zero; otherwise the stream option
or automatic policy is used. q6/q7/q11 therefore keep every automatic block
inside their deepest optimal-search ceiling.

Legacy balanced/ratio plus q2...q5 and q8...q10 inspect eight 8 KiB cells in
each automatic 64 KiB lookahead. A deterministic allocation-free Q8
byte-histogram DP selects one through four segments, charging a conservative
2,048-bit allowance per additional meta-block. Ties retain fewer segments and
equal-cost predecessor ties retain the earlier boundary, so reconstruction is
target-independent. The writer always compares the exact single-block and
midpoint wires; when the DP chooses a distinct 8 KiB-grid plan it also encodes
that plan and retains only a strictly smaller bit count. Homogeneous data
therefore keeps the larger block, while profitable non-quarter boundaries
receive independently modeled blocks without losing cross-block LZ77 history
or the recent-distance ring.
`adaptive_blocks = false` disables this policy; `true` forces it for a 64 KiB
configured block. A non-zero explicit `block_len` is fixed by default.
Automatic lookahead is
disabled above the standard 16-bit window to keep branch snapshots bounded;
forcing it there is rejected. Conservative encoded bounds assume every
adaptive 64 KiB block may be partitioned at every 8 KiB grid point, which is
strictly more conservative than the DP's four-segment limit.

| Quality | Family | Current Vort behavior |
| ---: | --- | --- |
| 0 | fast | Dedicated block-local fixed-hash fragment parsing with five-byte anchors, one hash candidate, recent-distance probing, incompressible skip-ahead, sparse match-tail seeding, and a 16 KiB default fragment. It deliberately does not borrow prior-fragment LZ history. Its compact one-pass writer starts with the audited Brotli default tree, estimates the literal tree before LZ emission, and uses each fragment's seeded event histogram for the next fragment. Compound-dictionary commands and explicitly forced adaptive 64 KiB block arbitration retain the general writer. |
| 1 | fast | Dedicated block-local fixed-hash fragment parsing with four-byte anchors through 32 KiB (six bytes for wider explicit fragments), the same bounded recent-distance/skip model, and a 32 KiB default fragment. It remains independent of prior-fragment LZ history. A dedicated compact two-pass writer collects exact literal/64-command/64-distance histograms, expands them into RFC trees, and emits the second pass directly; non-LZ compound-dictionary plans retain the general writer. Explicit RAW shared-prefix matching remains available. |
| 2 | balanced | Lazy chain 4 and nice length 32; ordinary LZ plans use an upstream-shaped fast writer with exact literal tree plus static command/distance trees through 128 commands, then 8-/10-/6-bit bounded dynamic trees. Every mode may try the built-in transformed static dictionary through 256 bytes; dictionary command plans retain the general writer. |
| 3 | balanced | Lazy chain 8, nice length 48, recent-distance selection, and a dedicated trivial single-meta-block writer with exact dynamic literal/command/distance trees but no block split. The same short-input dictionary candidate remains available through the general writer. |
| 4 | balanced | Lazy chain 16 and nice length 64; enables existing literal/command/distance split candidates and distance-parameter search. Font additionally compares its first mode-specific distance-shape candidate. |
| 5 | balanced | Lazy chain 32 and nice length 96; every mode enables the fixed two-tree UTF-8 literal-context candidate. |
| 6 | ratio | Lazy chain 64 and nice length 128; adds a bounded 64-chain/16-candidate optimal search for 4--32 KiB inputs. The advertised window range expands to 10...24 bits. |
| 7 | ratio | Lazy chain 96 and nice length 160; adds clustered contexts, adaptive distance splitting, and extended static-dictionary probing through 4 KiB in every mode. |
| 8 | ratio | Lazy chain 128 and nice length 192; expands the optimal-input ceiling to 64 KiB with a 128-chain/64-candidate budget and enables adaptive literal splitting. |
| 9 | ratio | Lazy chain 256 and nice length 258; uses a 192-chain/128-candidate optimal search through 64 KiB and enables adaptive command splitting in addition to the q8 candidates. |
| 10 | ratio | Lazy chain 384 plus a 256-chain/128-candidate optimal search through 64 KiB and the bounded fixed-record candidate; joint literal block/context clustering is eligible. Its first optimal command plan trains a deterministic Q8 literal/copy-length/distance-prefix model, then a second shortest-path proposal competes by complete wire size. Inputs through 8 KiB add a two-state command beam carrying pending insert length and the four recent distances. |
| 11 | ratio | Lazy chain 512, plus the same entropy-feedback and bounded command-state proposals over a deeper 512-chain/256-candidate search limited to 32 KiB. It recursively retains the complete q10 winner before considering q11 candidates, guaranteeing q11 size is no larger than q10 for identical options. This remains bounded Vort optimal search, not libbrotli-style HQ Zopfli parity. |

The bounded optimal candidate is considered only for inputs from 4 KiB through
32 KiB at q6/q7, through 64 KiB at q8...q10, and through 32 KiB for q11's
deeper search. q11 separately evaluates the complete q10 path, so the q10
64 KiB candidate and all of q10's context, split, dictionary, font, and stored
decisions remain eligible. The q10/q11 fixed-record candidate is limited to
4--64 KiB, advertised windows of at least 16 bits, and the recognized
newline-terminated record shape. These are extra Vort candidates, not the
general libbrotli HQ parser.

The q10/q11 feedback pass learns separable Q8 costs from the first complete LZ
command proposal. Active symbols cost at least one bit; unseen symbols retain a
deterministic penalty, and length/distance extra bits are charged explicitly.
The second pass reuses the same match-search budget and is retained only when
the complete Brotli stream is strictly smaller. A locked 4 KiB ambiguous-match
fixture reduces the optimal candidate from 230 to 221 bytes; both Vort and
Node/libbrotli decode the 221-byte public q10 stream byte-exactly. This proves a
real iterative model-feedback increment while deliberately not claiming the
stateful command-pair/recent-distance model used by libbrotli HQ.

q10/q11 inputs through 8 KiB now add that stateful layer. A two-state beam
tracks the pending insert run and all four RFC recent distances at every byte.
Transitions pay the learned 704-symbol command cost, exact insert/copy extra
bits, the learned 64-symbol distance cost, and regular-distance extra bits.
The match finder walks at most 64 hash predecessors, fully extends the first
eight general candidates, probes all 16 recent-distance forms directly, and
also retains deeper candidates whose learned regular-distance prefix is within
one bit of the cheapest prefix. A second locked 4 KiB ambiguous-match fixture
improves the already-refined candidate from 233 to 231 bytes; Node/libbrotli
independently decodes the public 231-byte q10 stream. The 8 KiB work limit is
evidence-driven: running the first unbounded command beam on a shared 32 KiB
source prefix regressed q10 from about 395.53 ms to about 697.16 ms. With the
limit, independent baseline/current binaries on CPU 8 measured 395.53 ms versus
394.18 ms (`1.0034x`) with identical 6,427-byte output. Wider command-state
search therefore remains future optimization rather than an unbounded default.
Callers that deliberately accept the work can override this policy through
`PlannedEncodeOptions.command_state_max_input_kib` or the matching
`PlannedStreamChunksOptions` field. Omitting it retains 8 KiB, zero disables the
stateful candidate, q10 accepts values through 64 KiB, and q11 through 32 KiB.
The override is rejected for q0...q9 and above the quality-specific ceiling.
Actual boundary tests execute and round-trip q10 at 64 KiB and both inherited
q10 plus deeper q11 beams at 32 KiB; the option is therefore a real full-range
capability rather than a range-only validator. Default throughput policy stays
unchanged until the wider search is optimized.

The public override is stored as a one-byte KiB value so adding the opt-in does
not enlarge the hot stream state. An initial `?u32` prototype caused a fixed-
CPU reusable regression of about 5.8% and was rejected. Against parent
`03bb4d8c`, the final layout preserved 120-byte/4,113-byte wires and 37,404/
333,775 retained-byte metrics; representative CPU-8 samples were 1.985/1.746 ms
for current one-shot/reusable versus 2.048/1.775 ms for the parent, with the
cross-block row within about 1%. Treat this as regression clearance rather than
a new speed claim.

`run-br-quality-command-state-profile` now separates seed planning, command
construction, model training, state index/setup/search/reconstruction, compact
wire, and complete wire. On the locked 32 KiB `src/br.zig` prefix, the initial
profile attributed roughly 5.1 ms to the seed plan, 44.6 ms to state search,
0.46 ms to one compact wire, and 57.7--60.0 ms to the complete wire candidate;
index construction was only about 0.17 ms. A prototype that precomputed match
lengths for both beam states reduced transitions by only 1.6% and made search
slightly slower, so it was removed rather than retained as nominal index reuse.

The retained optimization writes one compact state candidate first and runs the
full context/split matrix only when that wire is within 128 bytes of the current
winner. Five real 32 KiB source/Markdown prefixes all selected their existing
non-state winner; four avoided the roughly 60 ms full-wire work. The locked
strict-win fixture remains eligible (`233` baseline, `235` compact, `231` full).
Against parent `a2c96b1e`, five fixed-CPU-8 opt-in pairs preserved the identical
6,511-byte output and improved median time from about 701.5 ms to 529.8 ms
(`1.324x`, 5/5 wins). Seven default-path pairs were neutral at approximately
401.15/401.68 ms (`0.9987x`). Full opt-in is still materially slower than the
8 KiB default, so this evidence does not justify widening the default ceiling.
A follow-up state-loop change keeps each beam state borrowed instead of copying
the full recent-distance array into every transition call, and classifies the
pending insert length once per state rather than once per match. The 32 KiB
profile keeps identical token/command counts while reducing state search from
roughly 43--45 ms to about 40.5 ms. Against `74d0b758`, five fixed-CPU opt-in
pairs improve median end-to-end time from 528.34 ms to 519.68 ms (`1.0167x`,
3/5 wins); seven default controls are neutral at 401.42/401.68 ms (`0.9993x`).
The residual 40 ms search cost remains too high to change the default.
Profiler shape counters show ordinary hash matches account for 778,251 of
794,600 transitions (`97.9%`), while direct recent-distance probes contribute
only 16,349. A small lazy cache now shares each actually visited ordinary
candidate's match length between the two beam states without eagerly extending
filtered candidates. It preserves all token/command counts and reduces the
32 KiB search stage from about 40.5 ms to about 39.4 ms. Seven fixed-CPU opt-in
pairs improve median end-to-end time from 867.67 ms to 863.08 ms (`1.0053x`,
6/7 wins); seven default controls remain neutral at 669.34/669.09 ms
(`1.0004x`).
Ordinary candidates still dominate transition work, so each beam state now
materializes its ordered/deduplicated 16-entry recent-distance table once and
shares it between ordinary-symbol lookup and direct recent probing. This avoids
recomputing RFC delta arithmetic for every ordinary candidate. The 32 KiB
profile keeps identical shape/wire while reducing search from about 36.0 ms to
34.4 ms. Against `13d09d2d`, seven fixed-CPU opt-in pairs improve median time
from 842.03 ms to 838.73 ms (`1.0039x`, 5/7 wins); seven default controls also
remain positive/neutral at 672.42/669.45 ms (`1.0044x`, 5/7 wins).
Before command/distance lookup, a second exact lower bound compares
`state_cost + minimum_command_cost` against the full target beam. Distance and
extra-bit lower bounds are zero, so rejection is conservative and cannot remove
a winning transition. The 32 KiB profile moves 453,631 of 754,018 rejections
ahead of the expensive transition calculation and reduces search from about
34.4 ms to 32.9 ms. Against `774984d9`, seven fixed-CPU opt-in pairs improve
median time from 841.71 ms to 828.37 ms (`1.0161x`); seven default controls are
neutral at 668.87/668.29 ms (`1.0009x`). A richer early bound that also computed
copy-code extras and distance cost rejected more candidates but regressed search
to about 39.1 ms, so it was removed.
Profiling also shows 770,492 of 794,018 transitions (`97.0%`) target positions
whose two beam slots are already full. Each position now caches only the index
of its more expensive slot in one byte, maintained when the second state is
created, an equal-key state improves, or the worst state is replaced. Cost
bounds therefore load one cached slot instead of both State records and a max;
the 32 KiB search falls from about 32.9 ms to 31.05 ms, while the extra setup is
below 1 microsecond and memory is 32 KiB. Against `81765c38`, seven fixed-CPU
opt-in pairs improve median time from 824.34 ms to 819.19 ms (`1.0063x`, 6/7
wins); seven default controls improve 667.97/666.52 ms (`1.0022x`, 5/7 wins).
A prior full `u64` worst-cost cache used 256 KiB and regressed end-to-end to
`0.9865x`; it remains rejected.
An exact target-beam cost bound now rejects a transition before copying and
rolling its four-entry recent-distance history whenever the target already has
two states and the candidate cost cannot beat the more expensive slot. On the
32 KiB profile this removes history materialization for 754,706 of 794,600
transitions (`95.0%`) and lowers search from about 39.4 ms to 36.0 ms. The
entire opt-in branch is also `noinline` in a dedicated text section so its code
layout cannot perturb the default q10 path. Against `3ca8702a`, seven fixed-CPU
opt-in pairs are 7/7 wins and improve median time from 862.98 ms to 844.57 ms
(`1.0218x`); seven default controls are neutral at 667.88/667.97 ms
(`0.9999x`). Candidate counts, selected commands, and wire remain identical.
The unrelated warmed incremental gate was also made statistically repeatable:
it now reports the median of seven alternating one-shot/reusable pairs over
1,000 iterations. Repeated fixed-CPU calibrations measured
`1.0607x`--`1.0958x`; the gate requires `1.05x`, preserving a material advantage
without the former intermittent failures from a 200-iteration `1.10x` edge or
the still-flaky intermediate `1.08x` floor.

Measure the opt-in path explicitly without changing the default gate:

```sh
taskset -c 8 zig build -Doptimize=ReleaseFast \
  run-br-planned-encode-bench -- \
  --case source32k --iterations 5 --quality 10 \
  --planned-quality 10 --planned-mode generic \
  --command-state-max-input-kib 32
taskset -c 8 zig build run-br-quality-command-state-profile -- \
  3 10 src/br.zig 32768
```

The same two feedback stages now run inside the shared meta-block policy used
by one-shot chunk lists and `BrotliIncrementalPlannedStreamEncoder`; they are no
longer one-shot-only quality behavior. Each block trains from its first optimal
proposal while inheriting the caller-visible four-entry recent-distance ring
from the preceding committed meta-block. A two-block 8 KiB q10 fixture is
byte-identical between chunked and arbitrarily fragmented incremental encoding,
and Node/libbrotli independently decodes its 493-byte stream. The locked 4 KiB
strict-win fixture also observes the stateful candidate winning inside the
non-final meta-block bit-cost arbiter, not only in the standalone stream writer.
The override follows the same ownership path: reusable calls preserve the
requested wire, incremental `nextStream` installs the new stream's value, and
omitting it on the next stream restores the 8 KiB default. A 12,992-byte
opt-in chunked fixture encodes to 65 bytes and independently decodes through
Node/libbrotli.

Wide-window ratio-family streams use the same exact-wire arbitration. The
one-shot q6...q11 path augments its ordinary command plan directly; chunked and
incremental paths augment each block against the retained suffix immediately
preceding it. The matcher ignores history older than `2^WBITS-16`, preserves
static/compound command sources, and handles a source match that crosses the
history/current-block boundary. A locked q8 fixture copies 8 KiB from exactly
65,536 bytes back: one-shot, chunked, and arbitrarily fragmented incremental
surfaces all emit a 17-bit stream with `max_lz77_distance=65536`; chunked and
incremental output are byte-identical, and Node/libbrotli independently decodes
the 65,554-byte wire to 73,728 bytes. A separate 48 KiB fixture proves the
stream dictionary parser now covers the upper half of the standard 16-bit
history as well. The primary hash matcher remains 16-bit; sparse long-distance
augmentation is a bounded additive candidate, not a claim of libbrotli's
large-stream parsing strategy.

Validation also corrected two stale pre-existing benchmark assertions against
the already-shipped history-aware stream core. At baseline `c03ed3d1`, the
multi-block row is 131 bytes versus 127 bytes for three separately finalized
frames and about `0.47x` their aggregate encode throughput; its gate now records
an explicit at-most-eight-byte delta and a conservative `0.40x` regression
floor rather than implying leadership. The cross-block incremental row now
requires one-shot chunked and reusable encoders to agree within two bytes and
requires the 4,113-byte wire to remain less than roughly half of its 8 KiB
input. These changes align the gates with existing public behavior; they do not
claim a new multi-block performance win.

## Mode effects

Generic, text, and font use exactly the same parser budgets, UTF-8 literal
context policy, split schedule, and built-in static-dictionary thresholds and
probe budgets:

- the built-in transformed static dictionary starts at q2;
- the fixed UTF-8 literal-context candidate starts at q5;
- extended static-dictionary probing through 4 KiB and context clustering start
  at q7.

Generic and text therefore currently select from the same candidates. Font
adds exactly one mode-specific choice from q4 onward: a complete wire using
`NPOSTFIX=1, NDIRECT=12` with same-last-distance optimization disabled. The
ordinary shared-policy wire remains a candidate, and the font wire is retained
only when its complete encoded byte length is smaller.

Static-dictionary candidates are considered through 256 bytes. When extended
search is enabled, the bounded indexed search applies through 4 KiB. This is a
vetted subset of the RFC built-in dictionary transforms. The dedicated
`brEncodePlannedStreamStaticDictionaryAlloc` API instead adds a lazy
59,904-entry/370,692-byte supplemental index and covers all 121 standard
transform families. Default q0...q11 encoders never construct that index, so
their memory, hot lookup, and wire remain unchanged. The indexed/reference
benchmark gate requires identical wire metadata and at least a conservative
100x speedup on omit-first, literal-prefix, and dictionary-phrase rows. Neither
path is support for caller-supplied/custom static dictionaries. RAW
shared-prefix matching is the separate option described below.

`BrotliIncrementalStaticDictionaryStreamEncoder` is the bounded-memory,
caller-owned form of the dedicated complete surface. Its default 65,520-byte
block retains enough input to make a single-block finish byte-identical to the
one-shot API, while earlier full blocks carry output position and recent
distances into later meta-blocks. Input/output backpressure does not change the
wire. The encoder retains command and pending-output capacity across streams;
its `block_len` and `max_input_len` options bound block working memory and total
accepted input independently. This API deliberately always evaluates the
complete dictionary plan and therefore remains separate from preset throughput
claims and stored-size arbitration.

The matching chunked convenience APIs preserve every non-empty caller chunk as
a meta-block boundary and share the incremental implementation; they do not
flatten input or rebuild earlier output. Alloc and transactional Append use the
caller allocator. Into first materializes a temporary encoded stream to keep an
undersized caller buffer unchanged, so throughput-sensitive repeated callers
should retain an incremental encoder instead. These wrappers add no candidate
search to default presets and are excluded from q0...q11 performance claims.

`BrotliStaticDictionaryStreamEncoder` packages that retained state behind
atomic Scratch/Alloc/Append/Into methods. It clears lengths but retains
plain/pending/command/output capacities between operations. A fail-first
allocator regression proves zero new allocations for a warmed representative
three-block shape; this is an invariant for that retained shape, not a claim
that unseen larger inputs can never grow capacity. Thirty-two deterministic
random schedules vary block length, WBITS 10/16/24, flush versus metadata,
input fragmentation, and output backpressure, and require fragmentation-
independent wire plus successful decode.

## RAW shared-prefix encode/decode boundary

`BrotliSharedDictionary` is a borrowed descriptor for zero through fifteen
ordered RAW attachments. Non-empty attachments are logically concatenated in
order; an empty attachment contributes no bytes but still consumes one
attachment slot.

`BrotliPlannedEncodeOptions.shared_dictionary` makes RAW matching available to
one-shot and reusable planned encoding at legacy fast/balanced/ratio and
q0...q11, independently of the table's built-in static-dictionary schedule.
The streaming surfaces use
`BrotliPlannedStreamChunksOptions.shared_dictionary` and
`BrotliIncrementalPlannedStreamEncoder.Options.stream.shared_dictionary` for
chunked and incremental encoding respectively. The same stream options now
carry `level`, `quality`, and `mode`; omitting them preserves the established
fast policy while non-null quality applies the selected schedule per bounded
meta-block. Omitting the dictionary preserves compound-free behavior.

With a non-empty RAW descriptor, the one-shot path applies the selected
quality's lazy-search budget, context/split policy, recent-distance policy,
adaptive split overrides, distance-parameter search, and built-in static-
dictionary budget to the compound-aware command plan. It does not yet combine
RAW matches with the separate optimal-parser, fixed-record, or font-distance
alternative candidates used by some higher presets, and non-empty RAW q11 does
not inherit the complete q10 winner. Consequently, the ordinary no-dictionary
q11 <= q10 size guarantee does not currently extend to non-empty RAW
dictionaries. Closing that ratio gap is performance work; it does not change
the accepted quality range or wire interoperability described here.

Compound references use the actual Brotli wire distance and update the recent-
distance ring when explicit; implicit rep0 leaves its order unchanged. Built-in
transformed static-dictionary references never update the ring. The encoder's
fixed 15-bit/four-way matcher index occupies about 1 MiB on 64-bit targets once
a non-empty dictionary is prepared. Reusable and incremental encoders retain
the index, but never copy or own the attachment bytes.

`BrotliDecodeOptions.shared_dictionary` is honored by one-shot
`brDecodeStream*WithOptions` decoding,
chunked decode, decoded-size and summary APIs, caller-history summaries, and
both the caller-history `BrotliIncrementalCopyStreamDecoder` and allocator-owned
`BrotliIncrementalStreamDecoder` progressive paths. Summary results distinguish
shared-dictionary use with `uses_shared_dictionary`,
`shared_dictionary_copy_count`, and `shared_dictionary_bytes`.

The outer attachment slice and every attachment's bytes are borrowed without
copying. They remain alive and unchanged throughout any synchronous call.
Reusable encoders retain the matcher index, not the bytes; index reuse for an
identical descriptor requires the attachment bytes to stay unchanged across
calls. Incremental encoders retain them through finish/drain and reset reuse,
or until `nextStream` installs completed-stream options. Progressive decoders
retain them from initialization through completion and reset reuse; the
allocator-owned decoder can replace them only through `nextFrame` after
completing the current frame.

Latest upstream still marks serialized shared dictionaries as
`BROTLI_EXPERIMENTAL` and `DO NOT USE`. Vort exposes the container explicitly
as a borrowed experimental descriptor and supports production decoding across
its decode surfaces. Planned encoders use indexed contextual matching and
complete-wire arbitration across LSB6, MSB6, UTF8, and Signed on one-shot,
reusable, chunked, and incremental surfaces. No stability promise is made for
upstream's experimental container format.

## Large-input and API boundaries

Inputs larger than Brotli's 16 MiB meta-block limit remain one valid stream and
are split into bounded 16/32/64 KiB planning blocks selected as above. Every block applies the selected
legacy level or q0...q11 quality/mode policy, including its parser budget,
recent-distance choice, context/split candidates, bounded optimal candidate,
distance-parameter/font candidate, static-dictionary policy, and exact
compressed-versus-stored bit comparison. LZ77 history and the actual committed
recent-distance ring continue across block boundaries and are bounded by the
advertised window. A stored fallback rolls back candidate distance state while
advancing the logical output position.

The same policy core backs allocating, caller-buffer, reusable, explicit
chunk-list, and incremental planned encoders, including RAW shared-prefix
matching. Incremental `flush` and metadata boundaries preserve the selected
stream policy and bounded history. Explicit chunked/incremental block-size
overrides use the same core and conservative stored-stream bounds.

## Verification and performance claims

The schedule unit tests cover all 36 quality/mode combinations, validate every
row, require enabled features and search depth to grow, explicitly check q11's
shorter deep-optimal ceiling, and require the base policy to be equal across
modes. The planned Node differential emits one generic, text, and font fixture
at each of q0...q11 and requires Node's Brotli decoder to reproduce the input,
for 36 quality/mode interoperability cases. This is wire-compatibility evidence
only; it is not byte-parity or ratio/performance evidence against libbrotli.

The dedicated RAW shared-dictionary gate passed in Debug and ReleaseFast
against local libbrotli 1.2.0 with this matrix:

| Direction and Vort surface | Attachments | Qualities | Cases |
| --- | --- | --- | ---: |
| libbrotli encode -> Vort decode | 0/1/2/15 | q0/q5/q9/q11 | 16 |
| Vort one-shot encode -> libbrotli decode | 0/1/2/15 | q0/q5/q9/q11 | 16 |
| Vort reusable encode -> libbrotli decode | 0/1/2/15 | q0/q5/q9/q11 | 16 |
| Vort chunked encode -> libbrotli decode | 0/1/2/15 | fast coverage row | 4 |
| Vort incremental encode -> libbrotli decode | 0/1/2/15 | fast coverage row | 4 |
| Stateful window/ring/rollback/static regressions | mixed | fast/ratio | 4 |

The stateful regressions cover WBITS=10 saturation and cross-block recent
reuse, stored rollback followed by compound copy, incremental metadata and
output backpressure, and static addressing after a saturated compound region.
The same run retains four upstream decode fixtures and three descriptor-error
cases. System libbrotli 1.0.9 lacks the optional shared-dictionary symbols, so
the tool explicitly reports the complete runtime matrix as skipped there.
The current Debug `zig build test-br` passes all 960 tests, including q0...q11,
legacy level, retained-index, empty-dictionary wire, static-address shift,
incremental rollback, cross-API quality wire equality, and 16 MiB+ q0/q2
coverage. The upstream differential passes in both build modes with 7,056
one-shot and 7,056 progressive generated cases, 1,401 fragmentation runs, 64
high-tree truncations, seven Large Window cases, and one Vort-generated 16 MiB+
q2/font stream decoded independently by libbrotli 1.0.9
(`planned_large_quality_cases=1`). Five additional Vort-generated streams pin
q0/q2/q6/q11 automatic sizing plus an explicit 24 KiB override through
libbrotli (`planned_quality_block_size_cases=5`).
Two more streams require automatic q2 midpoint splitting and its explicit
disable path to decode through libbrotli
(`planned_stream_segmentation_cases=2`).
The required Node/libbrotli matrix separately locks an alternating-quarter q2
stream at four data meta-blocks and `39,169 -> 65,536` bytes; one-shot,
chunked, caller-buffer, and arbitrarily fragmented incremental tests require
the same wire and a conservative bound. A second q2 fixture locks the DP's
24 KiB non-quarter boundary at `38,753 -> 65,536` bytes with the same public
surface and independent-decode coverage.

The planned encode benchmark accepts independent Vort selectors:

```sh
zig build -Doptimize=ReleaseFast run-br-planned-encode-bench -- \
  --planned-quality 8 --planned-mode text --iterations 100
```

Its existing `--quality` option continues to select the libbrotli reference
quality. Recording both values prevents a Vort schedule from being mistaken for
a libbrotli implementation. No general q0...q11 by mode ratio, throughput, or
memory parity claim is made until a pinned multi-corpus benchmark publishes
those dimensions.

### Local q8 smoke evidence

One pinned single-thread ReleaseFast smoke on 2026-10-14 used Zig 0.16.0,
reported libbrotli version `1000009`, and an Intel Core i7-10700K
(`skylake+pku+sgx`, affinity `0-15`). The benchmark takes the best of five
interleaved rounds; the JSON row used 20 iterations and `source32k` used five:

| Case | Input | Vort q8 | libbrotli q8 | Size / reference | Vort MiB/s | Reference MiB/s | Speed / reference |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `json` | 2,640 | 57 | 59 | 0.9661 | 13.09 | 266.88 | 0.0491 |
| `source32k` | 32,768 | 6,686 | 6,658 | 1.0042 | 1.71 | 49.31 | 0.0347 |

Commands:

```sh
zig build -Doptimize=ReleaseFast run-br-planned-encode-bench -- \
  --case json --iterations 20 --quality 8 \
  --planned-quality 8 --planned-mode generic
zig build -Doptimize=ReleaseFast run-br-planned-encode-bench -- \
  --case source32k --iterations 5 --quality 8 \
  --planned-quality 8 --planned-mode generic
```

The input SHA-256 values were
`0d6239d44e1f465d045e5179cc2a5bf0997a95bdd8ad70a11eb2f3d3f4796941`
and `d890ef81cce951440e62e0c288ca5b43b1f8134cf4a2463f477fed21cea6f38b`,
respectively. This deliberately narrow smoke shows the immediate performance
gap: q8 size is already close on these two fixtures, but repeatedly materializing
and comparing the current split/context/distance candidates is roughly 20x to
30x slower. It is evidence for profiling and candidate-pruning work, not a
multi-corpus performance claim.

## Missing libbrotli-class work

The following are explicit gaps, not implied by the presence of the preset
names:

- full libbrotli-class q10/q11 Zopfli/HQ refinement. Vort now performs one
  deterministic command-derived entropy-feedback pass and a bounded 8 KiB
  command/recent-distance beam by default, with an explicit full-range opt-in.
  Making the 32/64 KiB ceilings fast enough to become defaults, reusing match
  sets across iterations, wider beam arbitration, and libbrotli's complete HQ
  cost model remain open;
- FastCover-style acceleration and broad serialized-dictionary corpus
  calibration. Deterministic heavy-hitter/COVER fixed-word selection plus an
  actual-wire `(d, hash_log)` grid, bounded multi-cutoff two-group and arbitrary
  non-contiguous context clustering, case/omit families, observed prefix/suffix
  stringlet/SHIFT learning, and per-dictionary transform-profile clustering use
  held-out complete-wire arbitration.
  The repository source/Markdown/JSON/binary trainer report currently records
  zero charged winners and zero regressions; real-corpus profitability remains
  a measured gap rather than an implied capability. Its out-of-band shadow finds
  a 22-byte structured-JSON frame saving behind a 1,992-byte dictionary (about
  2,898 frames to break even) after two greedy cap reductions, plus a 38-byte
  source saving behind 2,128 bytes. Documentation and binary return null out of
  band. Broader calibration and charged profitability remain higher priority
  than FastCover throughput work.
  Strict parsing, canonical construction, mixed replay, production decode
  attachment, bounded indexing, all four RFC modes, and joint multi-tree
  selection are available; oversized descriptors retain exhaustive matching;
- sub-8-KiB boundary search and global exact compressed-cost segmentation DP
  beyond the current bounded four-segment entropy proxy;
- calibration and regression gates for compression ratio, throughput, peak
  memory, and output-size monotonicity across representative corpora and
  platforms.

q0...q3 now have dedicated entropy writers, but none claims libbrotli byte
identity or general speed/ratio parity.

Until those items land, describe this surface as “Vort-native q0...q11
generic/text/font presets” rather than “libbrotli-compatible quality presets.”
